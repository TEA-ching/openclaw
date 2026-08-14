// Exa provider module implements model/runtime integration.
import { createWebSearchProviderContractFields } from "openclaw/plugin-sdk/provider-web-search-contract";

const EXA_CREDENTIAL_PATH = "plugins.entries.exa.config.webSearch.apiKey";
const EXA_ONBOARDING_SCOPES: Array<"text-inference"> = ["text-inference"];

export function createExaWebSearchProviderBase() {
  return {
    id: "exa",
    label: "Exa Search",
    hint: "Neural + keyword search with date filters and content extraction",
    onboardingScopes: [...EXA_ONBOARDING_SCOPES],
    credentialLabel: "Exa API key",
    // Detection also accepts the EXA_API_KEYS pool var (comma/semicolon/
    // whitespace-separated). collectProviderApiKeys() already rotates through
    // that pool at request time regardless of this list; without it here,
    // a pool-only deployment never registers Exa as a candidate provider.
    envVars: ["EXA_API_KEY", "EXA_API_KEYS"],
    placeholder: "exa-...",
    signupUrl: "https://exa.ai/",
    docsUrl: "https://docs.openclaw.ai/tools/web",
    autoDetectOrder: 65,
    credentialPath: EXA_CREDENTIAL_PATH,
    ...createWebSearchProviderContractFields({
      credentialPath: EXA_CREDENTIAL_PATH,
      searchCredential: { type: "scoped", scopeId: "exa" },
      configuredCredential: { pluginId: "exa" },
      selectionPluginId: "exa",
    }),
  };
}
