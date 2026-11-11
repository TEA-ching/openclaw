import { registerSingleProviderPlugin } from "openclaw/plugin-sdk/plugin-test-runtime";
import { collectProviderApiKeysForExecution } from "openclaw/plugin-sdk/provider-auth-runtime";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  applyVibeModelCompat,
  buildVibeModelDefinition,
  buildVibeProvider,
  VIBE_BASE_URL,
  VIBE_DEFAULT_MODEL_REF,
} from "./api.js";
import vibePlugin from "./index.js";
import manifest from "./openclaw.plugin.json" with { type: "json" };
import { VIBE_CLI_FAST_ID, VIBE_CLI_LATEST_ID } from "./provider-policy-api.js";

const transportCompat = {
  supportsStore: false,
  supportsPromptCacheKey: true,
  supportsLongCacheRetention: false,
  maxTokensField: "max_tokens",
} as const;

afterEach(() => {
  vi.unstubAllEnvs();
});

describe("vibe manifest", () => {
  it("declares its own provider id and the pooled key env vars", () => {
    expect(manifest.providers).toEqual(["vibe"]);
    expect(manifest.setup.providers).toEqual([
      { id: "vibe", envVars: ["VIBE_API_KEY", "VIBE_API_KEYS"] },
    ]);
  });

  it("targets the Mistral API with the Mistral request family", () => {
    expect(VIBE_BASE_URL).toBe("https://api.mistral.ai/v1");
    expect(manifest.providerRequest.providers.vibe.family).toBe("mistral");
    expect(manifest.providerEndpoints[0]?.hosts).toEqual(["api.mistral.ai"]);
  });
});

describe("vibe catalog", () => {
  it("defaults to the Vibe alias of Medium 3.5 and exposes both Vibe ids", () => {
    expect(VIBE_DEFAULT_MODEL_REF).toBe(`vibe/${VIBE_CLI_LATEST_ID}`);
    expect(buildVibeModelDefinition().id).toBe(VIBE_CLI_LATEST_ID);
    expect(buildVibeProvider().models.map((m) => m.id)).toEqual([
      VIBE_CLI_LATEST_ID,
      VIBE_CLI_FAST_ID,
    ]);
  });

  it("is free (zero cost) with the real 262k context and image input", () => {
    for (const model of buildVibeProvider().models) {
      expect(model.cost).toEqual({ input: 0, output: 0, cacheRead: 0, cacheWrite: 0 });
      expect(model.contextWindow).toBe(262144);
      expect(model.input).toEqual(["text", "image"]);
      expect(model.reasoning).toBe(true);
    }
  });
});

describe("applyVibeModelCompat", () => {
  it.each([VIBE_CLI_LATEST_ID, VIBE_CLI_FAST_ID])(
    "applies the Mistral request shape and reasoning compat to %s",
    (id) => {
      const normalized = applyVibeModelCompat({
        id,
        compat: { supportsStore: true, maxTokensField: "max_completion_tokens" as const },
      });
      expect(normalized.compat).toEqual({
        ...transportCompat,
        supportsReasoningEffort: true,
        reasoningEffortMap: {
          off: "none",
          minimal: "none",
          low: "high",
          medium: "high",
          high: "high",
          xhigh: "high",
          adaptive: "high",
          max: "high",
        },
      });
    },
  );

  it("does not grant reasoning to an unknown id, and returns the same object when already patched", () => {
    expect(applyVibeModelCompat({ id: "other" }).compat).toEqual({
      ...transportCompat,
      supportsReasoningEffort: false,
    });
    const model = { compat: { ...transportCompat, supportsReasoningEffort: false } };
    expect(applyVibeModelCompat(model)).toBe(model);
  });
});

describe("registered vibe provider", () => {
  it("keeps Mistral's strict 9-character tool call ids and exposes thinking levels", async () => {
    const provider = await registerSingleProviderPlugin(vibePlugin);
    expect(provider.buildReplayPolicy?.({} as never)).toEqual({
      sanitizeToolCallIds: true,
      toolCallIdMode: "strict9",
    });
    const profile = provider.resolveThinkingProfile?.({
      provider: "vibe",
      modelId: VIBE_CLI_LATEST_ID,
    });
    expect(profile?.levels.map(({ id }) => id)).toContain("adaptive");
    expect(profile?.defaultLevel).toBe("off");
    expect(
      provider.resolveThinkingProfile?.({ provider: "vibe", modelId: "other" }),
    ).toBeUndefined();
  });

  it("wraps streams with per-key rotation", async () => {
    const provider = await registerSingleProviderPlugin(vibePlugin);
    const streamFn = vi.fn();
    expect(provider.wrapStreamFn?.({ streamFn } as never)).toBeTypeOf("function");
    expect(provider.wrapSimpleCompletionStreamFn?.({ streamFn } as never)).toBeTypeOf("function");
  });

  it("recognises a Vibe context overflow message", async () => {
    const provider = await registerSingleProviderPlugin(vibePlugin);
    expect(
      provider.matchesContextOverflowError?.({ errorMessage: "Vibe: input is too long" } as never),
    ).toBe(true);
    expect(
      provider.matchesContextOverflowError?.({ errorMessage: "some other error" } as never),
    ).toBe(false);
  });
});

describe("VIBE_API_KEYS rotation pool", () => {
  it("collects the whole pool for the vibe provider, independent of the Mistral pool", () => {
    vi.stubEnv("VIBE_API_KEYS", "v1,v2 v3");
    vi.stubEnv("MISTRAL_API_KEYS", "m1,m2");
    expect(collectProviderApiKeysForExecution({ provider: "vibe" })).toEqual(["v1", "v2", "v3"]);
    expect(collectProviderApiKeysForExecution({ provider: "mistral" })).toEqual(["m1", "m2"]);
  });

  it("puts the primary key first and de-duplicates", () => {
    vi.stubEnv("VIBE_API_KEYS", "v1,v2");
    expect(collectProviderApiKeysForExecution({ provider: "vibe", primaryApiKey: "v2" })).toEqual([
      "v2",
      "v1",
    ]);
  });
});
