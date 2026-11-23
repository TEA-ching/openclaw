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

// Each Vibe key has its own budget. A used-up key answers 402 ("Vibe budget exhausted."), which the generic failover
// classifier does not recognise, so without this the pool never moved to the next key and the whole call failed while
// the other keys were healthy. Billing wording is accepted too: on Vibe it always describes one key, not the account.
const VIBE_KEY_EXHAUSTED = /\b402\b|budget[\s_-]*exhausted|billing/i;

/** True when a Vibe error means this key cannot serve requests, so the next key of the pool should be tried. */
export function isVibeKeyExhaustedError(message: string): boolean {
  return VIBE_KEY_EXHAUSTED.test(message);
}

/** How long an exhausted key is tried last. Budgets reset on a schedule of days, so minutes only avoid repeat failures. */
export const VIBE_KEY_COOLDOWN_MS = 10 * 60_000;

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
