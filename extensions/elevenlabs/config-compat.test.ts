// Elevenlabs tests cover config compat plugin behavior.
import type fs from "node:fs";
import type os from "node:os";
import type path from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  migrateElevenLabsLegacyTalkConfig,
  resolveElevenLabsApiKeyWithProfileFallback,
} from "./config-compat.js";

const { collectProviderApiKeysForExecution } = vi.hoisted(() => ({
  collectProviderApiKeysForExecution: vi.fn(),
}));

vi.mock("openclaw/plugin-sdk/provider-auth-runtime", () => ({
  collectProviderApiKeysForExecution,
}));

describe("elevenlabs config compat", () => {
  it("moves legacy talk fields into talk.providers.elevenlabs", () => {
    const result = migrateElevenLabsLegacyTalkConfig({
      talk: {
        voiceId: "voice-123",
        modelId: "eleven_v3",
        outputFormat: "pcm_44100",
        apiKey: "secret-key", // pragma: allowlist secret
      },
    });

    expect(result.changes).toEqual([
      "Moved talk legacy fields (voiceId, modelId, outputFormat, apiKey) → talk.providers.elevenlabs (filled missing provider fields only).",
    ]);
    expect(result.config).toEqual({
      talk: {
        providers: {
          elevenlabs: {
            voiceId: "voice-123",
            modelId: "eleven_v3",
            outputFormat: "pcm_44100",
            apiKey: "secret-key", // pragma: allowlist secret
          },
        },
      },
    });
  });

  it("reads ELEVENLABS_API_KEY from profile when env is missing", () => {
    const existsSync = vi.fn((candidate: string) => candidate.endsWith(".profile"));
    const readFileSync = vi.fn(() => "export ELEVENLABS_API_KEY=profile-key\n");
    const homedir = vi.fn(() => "/tmp/home");

    const value = resolveElevenLabsApiKeyWithProfileFallback(
      {},
      {
        fs: { existsSync, readFileSync } as unknown as typeof fs,
        os: { homedir } as unknown as typeof os,
        path: { join: (...parts: string[]) => parts.join("/") } as unknown as typeof path,
      },
    );

    expect(value).toBe("profile-key");
    expect(readFileSync).toHaveBeenCalledOnce();
  });

  it("prefers ELEVENLABS_API_KEY env over profile", () => {
    const existsSync = vi.fn(() => {
      throw new Error("profile should not be read when env key exists");
    });
    const readFileSync = vi.fn(() => "");

    const value = resolveElevenLabsApiKeyWithProfileFallback(
      { ELEVENLABS_API_KEY: "env-key" },
      {
        fs: { existsSync, readFileSync } as unknown as typeof fs,
        os: { homedir: () => "/tmp/home" } as unknown as typeof os,
        path: { join: (...parts: string[]) => parts.join("/") } as unknown as typeof path,
      },
    );

    expect(value).toBe("env-key");
    expect(existsSync).not.toHaveBeenCalled();
    expect(readFileSync).not.toHaveBeenCalled();
  });

  afterEach(() => {
    collectProviderApiKeysForExecution.mockReset();
  });

  it("falls back to ELEVENLABS_API_KEYS pool when env and profile are empty", () => {
    collectProviderApiKeysForExecution.mockReturnValue(["pool-key-1", "pool-key-2"]);

    const value = resolveElevenLabsApiKeyWithProfileFallback(
      {},
      {
        fs: { existsSync: vi.fn(() => false) } as unknown as typeof fs,
        os: { homedir: () => "/tmp/home" } as unknown as typeof os,
        path: { join: (...parts: string[]) => parts.join("/") } as unknown as typeof path,
      },
    );

    expect(value).toBe("pool-key-1");
  });

  it("returns null when no key is available in env, profile, or pool", () => {
    collectProviderApiKeysForExecution.mockReturnValue([]);

    const value = resolveElevenLabsApiKeyWithProfileFallback(
      {},
      {
        fs: { existsSync: vi.fn(() => false) } as unknown as typeof fs,
        os: { homedir: () => "/tmp/home" } as unknown as typeof os,
        path: { join: (...parts: string[]) => parts.join("/") } as unknown as typeof path,
      },
    );

    expect(value).toBeNull();
  });
});
