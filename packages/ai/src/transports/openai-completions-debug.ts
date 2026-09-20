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

const SYSTEM_PROMPT_ROLES = new Set(["system", "developer"]);

/**
 * Replaces large static system/developer prompt bodies with a short marker so
 * a `messagesPayload` dump spends its budget on the turns that actually vary
 * per request (user/assistant/tool messages), not the repeated boilerplate.
 */
function elideSystemPromptContent(messages: unknown): unknown {
  if (!Array.isArray(messages)) {
    return messages;
  }
  return messages.map((message) => {
    if (!message || typeof message !== "object") {
      return message;
    }
    const record = message as Record<string, unknown>;
    if (!SYSTEM_PROMPT_ROLES.has(String(record.role)) || typeof record.content !== "string") {
      return message;
    }
    return { ...record, content: `<${record.content.length} chars elided>` };
  });
}

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
    // Dump `tools` and `messages` on their own generous, independent budgets:
    // the shared whole-payload cap gets starved out by the repeated system
    // prompt boilerplate before reaching either field this mode exists to
    // inspect -- the actual tool schemas and the turn structure sent on the wire.
    parts.push(`toolsPayload=${stringifyRedactedPayload(record.tools, 200000)}`);
    parts.push(
      `messagesPayload=${stringifyRedactedPayload(elideSystemPromptContent(messages), 40000)}`,
    );
  }
  return parts.join(" ");
}
