import { readManifestProviderDefaultModelRef } from "openclaw/plugin-sdk/provider-catalog-shared";
import type { ModelDefinitionConfig } from "openclaw/plugin-sdk/provider-model-shared";
import manifest from "./openclaw.plugin.json" with { type: "json" };
import { buildVibeProvider } from "./provider-catalog.js";

export const VIBE_BASE_URL = manifest.modelCatalog.providers.vibe.baseUrl;
export const VIBE_DEFAULT_MODEL_REF = readManifestProviderDefaultModelRef(manifest, "vibe")!;
export const VIBE_DEFAULT_MODEL_ID = VIBE_DEFAULT_MODEL_REF.slice("vibe/".length);

export function buildVibeModelDefinition(): ModelDefinitionConfig {
  const model = buildVibeProvider().models.find((entry) => entry.id === VIBE_DEFAULT_MODEL_ID);
  if (!model) {
    throw new Error(`Missing Vibe provider model ${VIBE_DEFAULT_MODEL_ID}`);
  }
  return model;
}
