import {
  createDefaultModelsPresetAppliers,
  createDefaultModelsConnectionPresetAppliers,
} from "openclaw/plugin-sdk/provider-onboard";
import {
  buildVibeModelDefinition,
  VIBE_BASE_URL,
  VIBE_DEFAULT_MODEL_ID,
  VIBE_DEFAULT_MODEL_REF,
} from "./model-definitions.js";

const vibePreset = {
  primaryModelRef: VIBE_DEFAULT_MODEL_REF,
  resolveParams: () => ({
    providerId: "vibe",
    api: "openai-completions",
    baseUrl: VIBE_BASE_URL,
    defaultModels: () => [buildVibeModelDefinition()],
    defaultModelId: VIBE_DEFAULT_MODEL_ID,
    aliases: [{ modelRef: VIBE_DEFAULT_MODEL_REF, alias: "Vibe" }],
  }),
} satisfies Parameters<typeof createDefaultModelsConnectionPresetAppliers<[]>>[0];

export const { applyConfig: applyVibeConfig, applyProviderConfig: applyVibeProviderConfig } =
  createDefaultModelsPresetAppliers(vibePreset);
export const { applyConfig: applyVibeConnectionConfig } =
  createDefaultModelsConnectionPresetAppliers(vibePreset);
