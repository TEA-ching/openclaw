/**
 * Debug summarization for the `openai-completions` transport family (Cohere,
 * DeepSeek, and other openai-completions-compatible providers). Mirrors
 * `openai-responses-debug.ts`'s `summarizeResponsesPayload` so both OpenAI-
 * family transports honor the same `OPENCLAW_DEBUG_MODEL_PAYLOAD` contract —
 * previously only the responses transport could dump its outgoing `tools`
 * payload, leaving the completions family (this provider's own transport)
 * with no way to inspect what was actually sent on a rejected request.
 */
import { resolveModelPayloadDebugMode } from "./model-transport-debug.js";
import { safeDebugValue, stringifyRedactedPayload } from "./openai-responses-debug.js";
import { summarizeOpenAIToolsForDebug } from "./openai-tool-debug-summary.js";

export function summarizeCompletionsPayload(params: unknown): string {
  if (!params || typeof params !== "object") {
    return `type=${typeof params}`;
  }
  const record = params as Record<string, unknown>;
  const messages = record.messages;
  const parts = [
    `fields=${Object.keys(record).toSorted().join(",")}`,
    `model=${safeDebugValue(record.model)}`,
    `stream=${safeDebugValue(record.stream)}`,
    `messages=${Array.isArray(messages) ? messages.length : typeof messages}`,
    `tools=${summarizeOpenAIToolsForDebug(record.tools)}`,
    `toolChoice=${safeDebugValue(record.tool_choice)}`,
  ];
  if (resolveModelPayloadDebugMode() === "full-redacted") {
    parts.push(`payload=${stringifyRedactedPayload(record)}`);
  }
  return parts.join(" ");
}
