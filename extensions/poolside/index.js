import { createStreamApiKeyRotationWrapper } from "openclaw/plugin-sdk/provider-auth-runtime";
import { buildManifestModelProviderConfig } from "openclaw/plugin-sdk/provider-catalog-shared";
// Vendored from the MIT-licensed @poolside/openclaw-provider package
// (ClawHub only distributes a built dist/index.js for this package; its
// source repo is private). This file is that build output, treated as
// pseudo-source and patched directly:
//   - createStreamApiKeyRotationWrapper composed into wrapStreamFn so a
//     configured POOLSIDE_API_KEYS pool actually rotates on rate limits.
//   - setup.providers[].envVars in openclaw.plugin.json (sibling file) also
//     recognizes POOLSIDE_API_KEYS for activation, not just POOLSIDE_API_KEY.
import { defineSingleProviderPluginEntry } from "openclaw/plugin-sdk/provider-entry";
import { buildProviderReplayFamilyHooks } from "openclaw/plugin-sdk/provider-model-shared";
import { createModelCatalogPresetAppliers } from "openclaw/plugin-sdk/provider-onboard";
import { createPayloadPatchStreamWrapper } from "openclaw/plugin-sdk/provider-stream-shared";
//#endregion
//#region models.ts
const POOLSIDE_MANIFEST_CATALOG = {
  providers: {
    poolside: {
      baseUrl: "https://inference.poolside.ai/v1",
      api: "openai-completions",
      models: [
        {
          id: "laguna-s-2.1",
          name: "Laguna S 2.1",
          reasoning: true,
          input: ["text"],
          contextWindow: 262144,
          maxTokens: 32768,
          cost: {
            input: 0,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
          },
        },
        {
          id: "laguna-s-2.1:fast",
          name: "Laguna S 2.1 Fast",
          reasoning: true,
          input: ["text"],
          contextWindow: 1048576,
          maxTokens: 32768,
          cost: {
            input: 0,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
          },
        },
        {
          id: "laguna-xs-2.1",
          name: "Laguna XS 2.1",
          reasoning: true,
          input: ["text"],
          contextWindow: 262144,
          maxTokens: 32768,
          cost: {
            input: 0,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
          },
        },
        {
          id: "laguna-xs-2.1:fast",
          name: "Laguna XS 2.1 Fast",
          reasoning: true,
          input: ["text"],
          contextWindow: 262144,
          maxTokens: 32768,
          cost: {
            input: 0.1,
            output: 0.2,
            cacheRead: 0.05,
            cacheWrite: 0,
          },
        },
        {
          id: "laguna-m.1",
          name: "Laguna M.1",
          reasoning: true,
          input: ["text"],
          contextWindow: 262144,
          maxTokens: 32768,
          cost: {
            input: 0,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
          },
        },
        {
          id: "laguna-m.1:fast",
          name: "Laguna M.1 Fast",
          reasoning: true,
          input: ["text"],
          contextWindow: 262144,
          maxTokens: 32768,
          cost: {
            input: 0.2,
            output: 0.4,
            cacheRead: 0.1,
            cacheWrite: 0,
          },
        },
      ],
    },
  },
  discovery: { poolside: "static" },
}.providers.poolside;
const DEFAULT_CONTEXT_WINDOW = 262144;
const DEFAULT_MAX_TOKENS = 32768;
/**
 * Shared transport policy for every Laguna model.
 *
 * Laguna advertises `tools` and `reasoning` only: no `reasoning_effort`,
 * `json_mode`, or `structured_outputs`. `supportsReasoningEffort` stays false
 * so OpenClaw never sends a `reasoning_effort` field the endpoint rejects,
 * while `reasoning: true` still streams `reasoning_content` deltas.
 */
const POOLSIDE_COMPAT = {
  supportsStore: false,
  supportsDeveloperRole: false,
  supportsUsageInStreaming: true,
  supportsStrictMode: false,
  supportsTools: true,
  supportsReasoningEffort: false,
  maxTokensField: "max_tokens",
};
/** Base URL for Poolside's OpenAI-compatible inference API. */
const POOLSIDE_BASE_URL = POOLSIDE_MANIFEST_CATALOG.baseUrl;
/** Default Poolside model ref used for onboarding. */
const POOLSIDE_DEFAULT_MODEL_REF = `poolside/laguna-s-2.1`;
/** Bundled Laguna catalog rows shipped with this release. */
const POOLSIDE_MODEL_CATALOG = POOLSIDE_MANIFEST_CATALOG.models;
/** Builds one normalized Poolside model definition from a manifest entry. */
function buildPoolsideModelDefinition(model) {
  const normalized = buildManifestModelProviderConfig({
    providerId: "poolside",
    catalog: {
      ...POOLSIDE_MANIFEST_CATALOG,
      models: [model],
    },
  }).models[0];
  if (!normalized) throw new Error(`Missing normalized Poolside model ${model.id}`);
  return {
    ...normalized,
    compat: {
      ...POOLSIDE_COMPAT,
      ...normalized.compat,
    },
  };
}
/** Builds the full static Laguna catalog with shared compat applied. */
function buildStaticPoolsideModels() {
  return POOLSIDE_MODEL_CATALOG.map(buildPoolsideModelDefinition);
}
/** Whether a model id is one of the bundled Laguna catalog rows. */
function isPoolsideCatalogModelId(modelId) {
  const id = modelId.trim();
  return POOLSIDE_MODEL_CATALOG.some((model) => model.id === id);
}
/** Resolves a forward-compatible Laguna model id not yet in the bundled catalog. */
function resolvePoolsideDynamicModel(modelId) {
  const id = modelId.trim();
  if (!id || isPoolsideCatalogModelId(id)) return;
  return {
    id,
    name: id,
    provider: "poolside",
    api: "openai-completions",
    baseUrl: POOLSIDE_BASE_URL,
    reasoning: true,
    input: ["text"],
    cost: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
    },
    contextWindow: DEFAULT_CONTEXT_WINDOW,
    maxTokens: DEFAULT_MAX_TOKENS,
    compat: { ...POOLSIDE_COMPAT },
  };
}
//#endregion
//#region onboard.ts
/** Poolside onboarding config helpers. */
const poolsidePresetAppliers = createModelCatalogPresetAppliers({
  primaryModelRef: POOLSIDE_DEFAULT_MODEL_REF,
  resolveParams: (_cfg) => ({
    providerId: "poolside",
    api: "openai-completions",
    baseUrl: POOLSIDE_BASE_URL,
    catalogModels: buildStaticPoolsideModels(),
    aliases: [
      {
        modelRef: POOLSIDE_DEFAULT_MODEL_REF,
        alias: "Laguna S 2.1",
      },
    ],
  }),
});
/** Applies Poolside's provider catalog, alias, and default model. */
function applyPoolsideConfig(cfg) {
  return poolsidePresetAppliers.applyConfig(cfg);
}
//#endregion
//#region provider-catalog.ts
/** Builds Poolside's static Laguna provider catalog. */
function buildPoolsideProvider() {
  return {
    baseUrl: POOLSIDE_BASE_URL,
    api: "openai-completions",
    models: buildStaticPoolsideModels(),
  };
}
//#endregion
//#region stream.ts
const POOLSIDE_PROVIDER_ID = "poolside";
const POOLSIDE_MODEL_ID_PREFIX = "poolside/";
/** Safe default temperature for Laguna models when the caller sets none. */
const POOLSIDE_DEFAULT_TEMPERATURE = 0.7;
/** Sampling fields Poolside ignores; stripped so they never reach the wire. */
const POOLSIDE_UNSUPPORTED_SAMPLING_FIELDS = [
  "top_p",
  "top_k",
  "min_p",
  "presence_penalty",
  "frequency_penalty",
  "n",
];
/** Applies Poolside's temperature-only sampling contract to a request payload. */
function sanitizePoolsideSampling(payload) {
  for (const field of POOLSIDE_UNSUPPORTED_SAMPLING_FIELDS) delete payload[field];
  if (typeof payload.temperature !== "number") payload.temperature = POOLSIDE_DEFAULT_TEMPERATURE;
}
/** Restores the `poolside/` prefix the endpoint expects on the wire model id. */
function applyPoolsideModelId(payload) {
  if (
    typeof payload.model === "string" &&
    payload.model.length > 0 &&
    !payload.model.startsWith(POOLSIDE_MODEL_ID_PREFIX)
  )
    payload.model = `${POOLSIDE_MODEL_ID_PREFIX}${payload.model}`;
}
/** Wraps the stream fn to enforce Poolside's sampling and model-id contract. */
function createPoolsideSamplingWrapper(ctx) {
  return createPayloadPatchStreamWrapper(ctx.streamFn, ({ payload, model }) => {
    if (model.provider !== POOLSIDE_PROVIDER_ID || model.api !== "openai-completions") return;
    sanitizePoolsideSampling(payload);
    applyPoolsideModelId(payload);
  });
}
/**
 * Rotation wraps the raw transport first so it sees each attempt's own
 * opening error; Poolside's sampling/model-id wrapper composes on top of
 * whichever attempt rotation ultimately commits to (same pattern used for
 * the bundled Mistral and Cohere providers).
 */
function createPoolsideStreamWrapper(ctx) {
  return createPoolsideSamplingWrapper({
    ...ctx,
    streamFn: createStreamApiKeyRotationWrapper(POOLSIDE_PROVIDER_ID)(ctx.streamFn),
  });
}
var openclaw_provider_default = defineSingleProviderPluginEntry({
  id: "poolside",
  name: "Poolside Provider",
  description: "Official Poolside Laguna model provider plugin",
  provider: {
    label: "Poolside",
    docsPath: "https://github.com/poolsideai/openclaw-provider#readme",
    auth: [
      {
        methodId: "api-key",
        label: "Poolside API key",
        hint: "Laguna model family",
        optionKey: "poolsideApiKey",
        flagName: "--poolside-api-key",
        envVar: "POOLSIDE_API_KEY",
        promptMessage: "Enter Poolside API key",
        defaultModel: POOLSIDE_DEFAULT_MODEL_REF,
        applyConfig: (cfg) => applyPoolsideConfig(cfg),
        noteTitle: "Poolside",
        noteMessage: [
          "Poolside serves the Laguna model family behind one OpenAI-compatible API.",
          "Learn more at: https://poolside.ai",
        ].join("\n"),
        wizard: {
          groupLabel: "Poolside",
          groupHint: "Laguna model family",
        },
      },
    ],
    catalog: {
      buildProvider: buildPoolsideProvider,
      buildStaticProvider: buildPoolsideProvider,
      allowExplicitBaseUrl: true,
    },
    resolveDynamicModel: ({ modelId }) => resolvePoolsideDynamicModel(modelId),
    ...buildProviderReplayFamilyHooks({
      family: "openai-compatible",
      dropReasoningFromHistory: false,
    }),
    wrapStreamFn: (ctx) => createPoolsideStreamWrapper(ctx),
    isModernModelRef: () => true,
  },
});
//#endregion
export { openclaw_provider_default as default };
