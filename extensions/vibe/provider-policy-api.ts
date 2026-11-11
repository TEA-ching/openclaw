import type { ProviderDefaultThinkingPolicyContext } from "openclaw/plugin-sdk/plugin-entry";

// Vibe keys are Mistral keys on the free Vibe plan; these ids are API aliases of
// mistral-medium-3.5 and mistral-small, which both support reasoning effort.
export const VIBE_CLI_LATEST_ID = "mistral-vibe-cli-latest";
export const VIBE_CLI_FAST_ID = "mistral-vibe-cli-fast";

const VIBE_REASONING_MODEL_IDS = new Set([VIBE_CLI_LATEST_ID, VIBE_CLI_FAST_ID]);

// Same mapping as the Mistral provider.
const VIBE_THINKING_LEVELS = [
  ["off", "none"],
  ["minimal", "none"],
  ["low", "high"],
  ["medium", "high"],
  ["high", "high"],
  ["xhigh", "high"],
  ["adaptive", "high"],
  ["max", "high"],
] as const;
const VIBE_REASONING_EFFORT_MAP = Object.fromEntries(VIBE_THINKING_LEVELS);

export function resolveVibeReasoningEffortMap(
  modelId: string | undefined,
): Record<string, string> | undefined {
  return modelId !== undefined && VIBE_REASONING_MODEL_IDS.has(modelId)
    ? VIBE_REASONING_EFFORT_MAP
    : undefined;
}

export function resolveThinkingProfile({ modelId }: ProviderDefaultThinkingPolicyContext) {
  return resolveVibeReasoningEffortMap(modelId)
    ? {
        levels: VIBE_THINKING_LEVELS.map(([id]) => ({ id })),
        defaultLevel: "off" as const,
      }
    : undefined;
}
