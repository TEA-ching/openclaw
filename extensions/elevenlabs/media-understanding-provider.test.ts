// Elevenlabs tests cover media understanding provider plugin behavior.
import { mockPinnedHostnameResolution } from "openclaw/plugin-sdk/test-env";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { elevenLabsMediaUnderstandingProvider } from "./media-understanding-provider.js";

const { collectProviderApiKeysForExecution, executeWithApiKeyRotation } = vi.hoisted(() => ({
  collectProviderApiKeysForExecution: vi.fn(),
  executeWithApiKeyRotation: vi.fn(),
}));

vi.mock("openclaw/plugin-sdk/provider-auth-runtime", () => ({
  collectProviderApiKeysForExecution,
  executeWithApiKeyRotation,
}));

function requireFirstFetchCall(fetchMock: ReturnType<typeof vi.fn>): [string, RequestInit] {
  const [call] = fetchMock.mock.calls;
  if (!call) {
    throw new Error("expected ElevenLabs media fetch call");
  }
  return call as [string, RequestInit];
}

describe("elevenLabsMediaUnderstandingProvider", () => {
  let ssrfMock: { mockRestore: () => void } | undefined;

  beforeEach(() => {
    ssrfMock = mockPinnedHostnameResolution();
    collectProviderApiKeysForExecution.mockReturnValue([]);
  });

  afterEach(() => {
    ssrfMock?.mockRestore();
    ssrfMock = undefined;
    collectProviderApiKeysForExecution.mockReset();
    executeWithApiKeyRotation.mockReset();
  });

  it("has expected provider metadata", () => {
    expect(elevenLabsMediaUnderstandingProvider.id).toBe("elevenlabs");
    expect(elevenLabsMediaUnderstandingProvider.capabilities).toEqual(["audio"]);
    expect(elevenLabsMediaUnderstandingProvider.defaultModels?.audio).toBe("scribe_v2");
    expect(elevenLabsMediaUnderstandingProvider.transcribeAudio).toBeTypeOf("function");
  });

  it("posts multipart audio to ElevenLabs speech-to-text", async () => {
    const fetchMock = vi
      .fn<typeof fetch>()
      .mockResolvedValue(new Response(JSON.stringify({ text: "hello" })));

    const result = await elevenLabsMediaUnderstandingProvider.transcribeAudio!({
      buffer: Buffer.from("audio"),
      fileName: "voice.mp3",
      mime: "audio/mpeg",
      apiKey: "eleven-key",
      model: "scribe_v2",
      language: "en",
      timeoutMs: 1000,
      fetchFn: fetchMock,
    });

    expect(result).toEqual({ text: "hello", model: "scribe_v2" });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = requireFirstFetchCall(fetchMock);
    expect(url).toBe("https://api.elevenlabs.io/v1/speech-to-text");
    expect(init.method).toBe("POST");
    const headers = new Headers(init.headers);
    expect(headers.get("xi-api-key")).toBe("eleven-key");
    const form = init.body as FormData;
    expect(form.get("model_id")).toBe("scribe_v2");
    expect(form.get("language_code")).toBe("en");
    expect(form.get("file")).toBeInstanceOf(Blob);
  });

  it("wraps malformed successful speech-to-text JSON with a stable provider error", async () => {
    const fetchMock = vi.fn<typeof fetch>().mockResolvedValue(new Response("{ nope"));

    await expect(
      elevenLabsMediaUnderstandingProvider.transcribeAudio!({
        buffer: Buffer.from("audio"),
        fileName: "voice.mp3",
        mime: "audio/mpeg",
        apiKey: "eleven-key",
        model: "scribe_v2",
        timeoutMs: 1000,
        fetchFn: fetchMock,
      }),
    ).rejects.toThrow("ElevenLabs audio transcription failed: malformed JSON response");
  });

  it("rejects non-object successful speech-to-text JSON with a stable provider error", async () => {
    const fetchMock = vi.fn<typeof fetch>().mockResolvedValue(new Response(JSON.stringify([])));

    await expect(
      elevenLabsMediaUnderstandingProvider.transcribeAudio!({
        buffer: Buffer.from("audio"),
        fileName: "voice.mp3",
        mime: "audio/mpeg",
        apiKey: "eleven-key",
        model: "scribe_v2",
        timeoutMs: 1000,
        fetchFn: fetchMock,
      }),
    ).rejects.toThrow("ElevenLabs audio transcription failed: malformed JSON response");
  });

  it("uses the key from the ELEVENLABS_API_KEYS pool when no apiKey is provided", async () => {
    vi.stubEnv("ELEVENLABS_API_KEY", "  ");
    vi.stubEnv("XI_API_KEY", "  ");
    collectProviderApiKeysForExecution.mockReturnValue(["pool-key-1"]);
    const fetchMock = vi
      .fn<typeof fetch>()
      .mockResolvedValue(new Response(JSON.stringify({ text: "pooled" })));

    const result = await elevenLabsMediaUnderstandingProvider.transcribeAudio!({
      buffer: Buffer.from("audio"),
      fileName: "voice.mp3",
      mime: "audio/mpeg",
      apiKey: "",
      model: "scribe_v2",
      timeoutMs: 1000,
      fetchFn: fetchMock,
    });

    expect(result).toEqual({ text: "pooled", model: "scribe_v2" });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(new Headers(init.headers as HeadersInit).get("xi-api-key")).toBe("pool-key-1");
  });
});

describe("elevenlabs media understanding api-key rotation", () => {
  beforeEach(() => {
    vi.stubEnv("ELEVENLABS_API_KEY", "primary-key");
    vi.stubEnv("ELEVENLABS_API_KEYS", "primary-key, secondary-key");
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    collectProviderApiKeysForExecution.mockReset();
    executeWithApiKeyRotation.mockReset();
  });

  it("delegates directly when the pool resolves to a single key", async () => {
    collectProviderApiKeysForExecution.mockReturnValue(["primary-key"]);
    const fetchMock = vi
      .fn<typeof fetch>()
      .mockResolvedValue(new Response(JSON.stringify({ text: "hello" })));

    const result = await elevenLabsMediaUnderstandingProvider.transcribeAudio!({
      buffer: Buffer.from("audio"),
      fileName: "voice.mp3",
      mime: "audio/mpeg",
      apiKey: "primary-key",
      model: "scribe_v2",
      timeoutMs: 1000,
      fetchFn: fetchMock,
    });

    expect(result).toEqual({ text: "hello", model: "scribe_v2" });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("rotates through the pool when multiple keys are available", async () => {
    executeWithApiKeyRotation.mockResolvedValue({ text: "rotated", model: "scribe_v2" });
    collectProviderApiKeysForExecution.mockReturnValue(["primary-key", "secondary-key"]);
    const fetchMock = vi
      .fn<typeof fetch>()
      .mockResolvedValue(new Response(JSON.stringify({ text: "hello" })));

    const result = await elevenLabsMediaUnderstandingProvider.transcribeAudio!({
      buffer: Buffer.from("audio"),
      fileName: "voice.mp3",
      mime: "audio/mpeg",
      apiKey: "primary-key",
      model: "scribe_v2",
      timeoutMs: 1000,
      fetchFn: fetchMock,
    });

    expect(result).toEqual({ text: "rotated", model: "scribe_v2" });
    expect(executeWithApiKeyRotation).toHaveBeenCalledWith({
      provider: "elevenlabs",
      apiKeys: ["primary-key", "secondary-key"],
      execute: expect.any(Function),
    });
    // Fetch is only called inside the execute callback, which the mock skips.
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
