/**
 * Shared tool-list debug summarization for OpenAI-family transports. Both the
 * `openai-responses` and `openai-completions` transports send the same
 * `{type:"function", function:{name,...}}` (or flat `{type,name}`) tool shape,
 * so they share one summarizer instead of drifting under `OPENCLAW_DEBUG_MODEL_PAYLOAD`.
 */
import { resolveModelPayloadDebugMode } from "./model-transport-debug.js";

function readToolPayloadField(record: Record<string, unknown>, field: string): unknown {
  try {
    return record[field];
  } catch {
    return undefined;
  }
}

export function readOpenAIToolDebugName(tool: unknown): string {
  if (!tool || typeof tool !== "object") {
    return "";
  }
  const record = tool as Record<string, unknown>;
  const name = readToolPayloadField(record, "name");
  if (typeof name === "string") {
    return name;
  }
  const fn = readToolPayloadField(record, "function");
  if (fn && typeof fn === "object") {
    const fnName = readToolPayloadField(fn as Record<string, unknown>, "name");
    if (typeof fnName === "string") {
      return fnName;
    }
  }
  const type = readToolPayloadField(record, "type");
  return typeof type === "string" && type !== "function" ? type : "";
}

export function summarizeOpenAIToolsForDebug(tools: unknown): string {
  if (!Array.isArray(tools)) {
    return "count=0";
  }
  const names = tools.map(readOpenAIToolDebugName).filter(Boolean);
  const mode = resolveModelPayloadDebugMode();
  const maxNames = mode === "tools" || mode === "full-redacted" ? names.length : 12;
  const label = maxNames >= names.length ? "names" : "sample";
  const shown = names.slice(0, maxNames).join(",");
  return `count=${tools.length}${shown ? ` ${label}=${shown}` : ""}`;
}
