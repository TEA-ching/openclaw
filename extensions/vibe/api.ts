import { asOptionalObjectRecord } from "openclaw/plugin-sdk/string-coerce-runtime";
import { resolveVibeReasoningEffortMap } from "./provider-policy-api.js";

export { buildVibeProvider } from "./provider-catalog.js";
export {
  buildVibeModelDefinition,
  VIBE_BASE_URL,
  VIBE_DEFAULT_MODEL_ID,
  VIBE_DEFAULT_MODEL_REF,
} from "./model-definitions.js";
export { applyVibeConfig, applyVibeProviderConfig } from "./onboard.js";

// Identical to the Mistral provider: Vibe talks to the same api.mistral.ai chat completions endpoint.
export const VIBE_MODEL_TRANSPORT_PATCH = {
  supportsStore: false,
  supportsPromptCacheKey: true,
  supportsLongCacheRetention: false,
  maxTokensField: "max_tokens",
} as const;

export function resolveVibeCompatPatch(model: { id?: string }) {
  const reasoningEffortMap = resolveVibeReasoningEffortMap(model.id);
  return {
    ...VIBE_MODEL_TRANSPORT_PATCH,
    supportsReasoningEffort: reasoningEffortMap !== undefined,
    reasoningEffortMap,
  };
}

export function applyVibeModelCompat<T extends { compat?: unknown; id?: string }>(model: T): T {
  const compat = asOptionalObjectRecord(model.compat);
  const patch = resolveVibeCompatPatch(model);
  if (Object.entries(patch).every(([key, value]) => compat?.[key] === value)) {
    return model;
  }
  return {
    ...model,
    compat: { ...compat, ...patch },
  };
}
