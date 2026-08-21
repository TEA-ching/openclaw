// Elevenlabs tests cover config compat plugin behavior.
import { describe, expect, it } from "vitest";
import { migrateElevenLabsLegacyTalkConfig } from "./config-compat.js";

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
});
