import { createStreamApiKeyRotationWrapper } from "openclaw/plugin-sdk/provider-auth-runtime";
import { defineSingleProviderPluginEntry } from "openclaw/plugin-sdk/provider-entry";
import { applyVibeModelCompat, isVibeKeyExhaustedError, VIBE_KEY_COOLDOWN_MS } from "./api.js";
import { applyVibeConnectionConfig } from "./onboard.js";
import manifest from "./openclaw.plugin.json" with { type: "json" };
import { resolveThinkingProfile } from "./provider-policy-api.js";

// Mistral Vibe keys are Mistral API keys on the free Vibe plan: they work against
// https://api.mistral.ai/v1 with the ids `mistral-vibe-cli-latest` (alias of mistral-medium-3.5)
// and `mistral-vibe-cli-fast` (alias of mistral-small). This provider reuses the Mistral wire
// behaviour but keeps its own id, so VIBE_API_KEYS is rotated independently of MISTRAL_API_KEYS.
// It replaces routing Vibe through the ACP harness (acp-vibe) for scheduled jobs.
const PROVIDER_ID = "vibe";
const VIBE_KEY_ROTATION = {
  isKeyFailure: isVibeKeyExhaustedError,
  cooldownMs: VIBE_KEY_COOLDOWN_MS,
};
export default defineSingleProviderPluginEntry({
  id: PROVIDER_ID,
  name: "Mistral Vibe Provider",
  description: "Mistral Vibe API keys against api.mistral.ai, with per-key rotation",
  manifest,
  provider: {
    label: "Mistral Vibe",
    docsPath: "/providers/models",
    manifestAuth: { applyConfig: applyVibeConnectionConfig },
    catalog: {
      discoveryMode: "strict",
      allowExplicitBaseUrl: true,
      // No liveModelDiscovery: keep the catalog to the two Vibe ids (a Vibe key can list every Mistral model).
    },
    matchesContextOverflowError: ({ errorMessage }) =>
      /\b(?:mistral|vibe)\b.*(?:input.*too long|token limit.*exceeded)/i.test(errorMessage),
    normalizeResolvedModel: ({ model }) => applyVibeModelCompat(model),
    resolveThinkingProfile,
    buildReplayPolicy: () => ({
      sanitizeToolCallIds: true,
      toolCallIdMode: "strict9",
    }),
    wrapStreamFn: (ctx) =>
      createStreamApiKeyRotationWrapper(PROVIDER_ID, VIBE_KEY_ROTATION)(ctx.streamFn),
    wrapSimpleCompletionStreamFn: (ctx) =>
      createStreamApiKeyRotationWrapper(PROVIDER_ID, VIBE_KEY_ROTATION)(ctx.streamFn),
  },
});
