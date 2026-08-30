import { createStreamApiKeyRotationWrapper } from "openclaw/plugin-sdk/provider-auth-runtime";
import { defineSingleProviderPluginEntry } from "openclaw/plugin-sdk/provider-entry";
import { isModernCohereModelId } from "./models.js";
import { applyCohereConfig } from "./onboard.js";
import manifest from "./openclaw.plugin.json" with { type: "json" };
import { COHERE_LIVE_MODEL_DISCOVERY } from "./provider-catalog.js";
import { wrapCohereCompletionsStream } from "./stream.js";

const PROVIDER_ID = "cohere";

export default defineSingleProviderPluginEntry({
  id: PROVIDER_ID,
  name: "Cohere Provider",
  description: "Cohere provider plugin",
  manifest,
  provider: {
    label: "Cohere",
    docsPath: "/providers/cohere",
    manifestAuth: { applyConfig: applyCohereConfig },
    catalog: {
      liveModelDiscovery: COHERE_LIVE_MODEL_DISCOVERY,
    },
    // Rotation wraps the raw transport first so it sees each attempt's own
    // opening error; Cohere's payload-patch wrapper composes on top of
    // whichever attempt rotation ultimately commits to.
    wrapStreamFn: (ctx) =>
      wrapCohereCompletionsStream(createStreamApiKeyRotationWrapper(PROVIDER_ID)(ctx.streamFn)),
    wrapSimpleCompletionStreamFn: (ctx) =>
      wrapCohereCompletionsStream(createStreamApiKeyRotationWrapper(PROVIDER_ID)(ctx.streamFn)),
    isModernModelRef: ({ modelId }) => isModernCohereModelId(modelId),
  },
});
