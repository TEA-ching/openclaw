// Elevenlabs tests cover config compat plugin behavior.
import { describe, expect, it } from "vitest";
import { migrateElevenLabsLegacyTalkConfig } from "./config-compat.js";

describe("elevenlabs config compat", () => {
  it("moves legacy talk fields into talk.providers.elevenlabs", () => {
    const result = migrateElevenLabsLegacyTalkConfig({
      talk: {
        providers: { elevenlabs: { voiceId: "existing-voice" } },
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
            voiceId: "existing-voice",
            modelId: "eleven_v3",
            outputFormat: "pcm_44100",
            apiKey: "secret-key", // pragma: allowlist secret
          },
        },
      },
    });
    expect(migrateElevenLabsLegacyTalkConfig(result.config)).toEqual({
      config: result.config,
      changes: [],
    });
  });

  it("preserves ambiguous legacy Talk fields for actionable doctor guidance", () => {
    const config = {
      talk: {
        providers: { acme: { modelId: "acme-model" }, other: { modelId: "other-model" } },
        voiceId: "legacy-voice",
      },
    };
    expect(migrateElevenLabsLegacyTalkConfig(config)).toEqual({
      config,
      changes: [expect.stringContaining("multiple providers")],
    });
  });
});
