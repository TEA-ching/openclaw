// Narrow barrel for ElevenLabs config compatibility helpers consumed outside the plugin.
// Keep this separate from runtime exports so doctor/config code stays lightweight.

export { resolveElevenLabsApiKeyWithProfileFallback } from "./api-key-fallback.js";
export { ELEVENLABS_TALK_PROVIDER_ID, migrateElevenLabsLegacyTalkConfig } from "./config-compat.js";
