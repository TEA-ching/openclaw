/**
 * Provider API-key rotation wrapper.
 * Runs provider calls across configured keys on rate-limit failures and keeps
 * same-key transient retries separate from key rotation. When
 * AGGRESSIVE_ROTATION=1, also advances the pool's starting key on every call.
 */
import { toErrorObject as toLintErrorObject } from "@openclaw/normalization-core/error-coercion";
import { normalizeUniqueStringEntries } from "@openclaw/normalization-core/string-normalization";
import { sleepWithAbort } from "../infra/backoff.js";
import { formatErrorMessage } from "../infra/errors.js";
import type { AssistantMessageEventStreamLike, Context, Model, StreamFn } from "../llm/types.js";
import { createAssistantMessageEventStream } from "../llm/utils/event-stream.js";
import {
  resolveTransientProviderAttempts,
  resolveTransientProviderDelayMs,
  resolveTransientProviderRetryOptions,
  shouldRetrySameKeyProviderOperation,
  type TransientProviderRetryConfig,
} from "../provider-runtime/operation-retry.js";
import { collectProviderApiKeys, isApiKeyRateLimitError } from "./live-auth-keys.js";

type ApiKeyRetryParams = {
  apiKey: string;
  error: unknown;
  attempt: number;
};

const AGGRESSIVE_ROTATION_ENV_VAR = "AGGRESSIVE_ROTATION";
// Per-provider cursor so consecutive calls advance through the pool. Only
// consulted when AGGRESSIVE_ROTATION_ENV_VAR is enabled; existing rate-limit
// rotation below is untouched and still walks forward from whatever key this
// picks as the start.
const aggressiveRotationCursors = new Map<string, number>();

/**
 * Reorders a provider's key pool so each call starts at the next key,
 * independent of the rate-limit-triggered rotation in the loops below. A
 * no-op unless AGGRESSIVE_ROTATION=1 and the pool has more than one key.
 */
function rotateKeysForAggressiveMode(provider: string, keys: string[]): string[] {
  if (keys.length <= 1 || process.env[AGGRESSIVE_ROTATION_ENV_VAR] !== "1") {
    return keys;
  }
  const cursor = aggressiveRotationCursors.get(provider) ?? 0;
  const offset = cursor % keys.length;
  aggressiveRotationCursors.set(provider, cursor + 1);
  return [...keys.slice(offset), ...keys.slice(0, offset)];
}

type ExecuteWithApiKeyRotationOptions<T> = {
  provider: string;
  apiKeys: string[];
  execute: (apiKey: string) => Promise<T>;
  shouldRetry?: (params: ApiKeyRetryParams & { message: string }) => boolean;
  onRetry?: (params: ApiKeyRetryParams & { message: string }) => void;
  transientRetry?: TransientProviderRetryConfig;
};

/** Collect primary and live-discovered provider keys in stable de-duped order. */
export function collectProviderApiKeysForExecution(params: {
  provider: string;
  primaryApiKey?: string;
}): string[] {
  const { primaryApiKey, provider } = params;
  return normalizeUniqueStringEntries([
    primaryApiKey?.trim() ?? "",
    ...collectProviderApiKeys(provider),
  ]);
}

/**
 * Execute a provider operation with key rotation and optional same-key transient
 * retries.
 */
export async function executeWithApiKeyRotation<T>(
  params: ExecuteWithApiKeyRotationOptions<T>,
): Promise<T> {
  const keys = rotateKeysForAggressiveMode(
    params.provider,
    normalizeUniqueStringEntries(params.apiKeys),
  );
  if (keys.length === 0) {
    throw new Error(`No API keys configured for provider "${params.provider}".`);
  }

  let lastError: unknown;
  const transientRetry = resolveTransientProviderRetryOptions(params.transientRetry);
  keyLoop: for (const [apiKeyIndex, apiKey] of keys.entries()) {
    const maxOperationAttempts = resolveTransientProviderAttempts(transientRetry);
    for (let attemptNumber = 1; attemptNumber <= maxOperationAttempts; attemptNumber += 1) {
      try {
        return await params.execute(apiKey);
      } catch (error) {
        lastError = error;
        const message = formatErrorMessage(error);
        const rotateKey = params.shouldRetry
          ? params.shouldRetry({ apiKey, error, attempt: apiKeyIndex, message })
          : isApiKeyRateLimitError(message);

        if (rotateKey) {
          // A rotation signal consumes the current key and moves to the next key
          // without running same-key transient retry logic.
          if (apiKeyIndex + 1 >= keys.length) {
            break;
          }
          params.onRetry?.({ apiKey, error, attempt: apiKeyIndex, message });
          break;
        }

        if (
          !transientRetry ||
          !shouldRetrySameKeyProviderOperation({
            options: transientRetry,
            error,
            message,
            provider: params.provider,
            apiKeyIndex,
            attemptNumber,
            maxAttempts: maxOperationAttempts,
          })
        ) {
          break keyLoop;
        }

        const delayMs = resolveTransientProviderDelayMs(transientRetry, attemptNumber);
        // Same-key transient retries are bounded by provider policy and keep the
        // current key stable so auth rotation only handles key-specific failures.
        const sleep = transientRetry.sleep ?? sleepWithAbort;
        await sleep(delayMs, transientRetry.signal);
      }
    }
  }

  if (lastError === undefined) {
    throw new Error(`Failed to run API request for ${params.provider}.`);
  }
  throw toLintErrorObject(lastError, "Non-Error thrown");
}

/**
 * Wraps a streaming provider's `StreamFn` so it rotates through a configured
 * API-key pool when the very first stream event is a rate-limit error, i.e.
 * the request never opened. Once any other event has been observed the
 * stream is committed to its current key; rotation never discards or repeats
 * in-flight output. Providers whose transport already resolves apiKey pools
 * itself (rather than accepting `options.apiKey`) are not covered by this
 * wrapper.
 */
export function createStreamApiKeyRotationWrapper(
  provider: string,
): (streamFn: StreamFn | undefined) => StreamFn | undefined {
  return (streamFn) => {
    if (!streamFn) {
      return undefined;
    }
    return (model, context, options) =>
      runStreamWithApiKeyRotation({ provider, streamFn, model, context, options });
  };
}

async function runStreamWithApiKeyRotation(params: {
  provider: string;
  streamFn: StreamFn;
  model: Model;
  context: Context;
  options?: Parameters<StreamFn>[2];
}): Promise<AssistantMessageEventStreamLike> {
  const primaryApiKey = params.options?.apiKey;
  const apiKeys = rotateKeysForAggressiveMode(
    params.provider,
    collectProviderApiKeysForExecution({
      provider: params.provider,
      primaryApiKey,
    }),
  );
  if (apiKeys.length <= 1) {
    return params.streamFn(params.model, params.context, params.options);
  }

  const output = createAssistantMessageEventStream();
  for (const [index, apiKey] of apiKeys.entries()) {
    const attemptStream = await params.streamFn(params.model, params.context, {
      ...params.options,
      apiKey,
    });
    const iterator = attemptStream[Symbol.asyncIterator]();
    const first = await iterator.next();
    if (first.done) {
      // No events at all; nothing to rotate on. Commit this (empty) attempt.
      output.end(await attemptStream.result());
      return output;
    }
    const firstEvent = first.value;
    const isRotatableFailure =
      firstEvent.type === "error" &&
      firstEvent.reason === "error" &&
      isApiKeyRateLimitError(firstEvent.error.errorMessage ?? "");
    const hasRemainingKeys = index + 1 < apiKeys.length;
    if (isRotatableFailure && hasRemainingKeys) {
      continue;
    }
    output.push(firstEvent);
    for (let next = await iterator.next(); !next.done; next = await iterator.next()) {
      output.push(next.value);
    }
    return output;
  }
  // Unreachable: the loop above always returns on its last iteration.
  throw new Error(`Exhausted API-key rotation for provider "${params.provider}" without a result.`);
}
