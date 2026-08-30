import type { ProviderWrapStreamFnContext } from "openclaw/plugin-sdk/plugin-entry";
import { createPayloadPatchStreamWrapper } from "openclaw/plugin-sdk/provider-stream-shared";

type StreamFn = ProviderWrapStreamFnContext["streamFn"];

// Exposed separately from wrapCohereProviderStream so callers that must wrap a
// transport other than ctx.streamFn (e.g. one already wrapped for API key
// rotation) can still apply Cohere's payload patch on top.
export function wrapCohereCompletionsStream(streamFn: StreamFn) {
  return createPayloadPatchStreamWrapper(streamFn, ({ payload }) => {
    // Cohere's Compatibility API uses developer, not system, for instructions.
    if (Array.isArray(payload.messages)) {
      payload.messages = payload.messages.map((message) =>
        message &&
        typeof message === "object" &&
        (message as Record<string, unknown>).role === "system"
          ? { ...(message as Record<string, unknown>), role: "developer" }
          : message,
      );
    }

    // Cohere lets tool-capable models choose a tool when tool_choice is omitted.
    delete payload.tool_choice;
  });
}

export function wrapCohereProviderStream(ctx: ProviderWrapStreamFnContext) {
  return wrapCohereCompletionsStream(ctx.streamFn);
}
