// Elevenlabs helper module resolves ELEVENLABS_API_KEY(S) outside the doctor-contract closure.
// Doctor enumeration cold-loads config-compat.ts; provider-auth-runtime statically
// reaches execa, so key rotation lookups stay in this sibling module instead.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { collectProviderApiKeysForExecution } from "openclaw/plugin-sdk/provider-auth-runtime";

const ELEVENLABS_API_KEY_ENV = "ELEVENLABS_API_KEY";
const PROFILE_CANDIDATES = [".profile", ".zprofile", ".zshrc", ".bashrc"] as const;

type ElevenLabsApiKeyDeps = {
  fs?: typeof fs;
  os?: typeof os;
  path?: typeof path;
};

function readApiKeyFromProfile(deps: ElevenLabsApiKeyDeps = {}): string | null {
  const fsImpl = deps.fs ?? fs;
  const osImpl = deps.os ?? os;
  const pathImpl = deps.path ?? path;

  const home = osImpl.homedir();
  for (const candidate of PROFILE_CANDIDATES) {
    const fullPath = pathImpl.join(home, candidate);
    if (!fsImpl.existsSync(fullPath)) {
      continue;
    }
    try {
      const text = fsImpl.readFileSync(fullPath, "utf-8");
      const match = text.match(
        /(?:^|\n)\s*(?:export\s+)?ELEVENLABS_API_KEY\s*=\s*["']?([^\n"']+)["']?/,
      );
      const value = match?.[1]?.trim();
      if (value) {
        return value;
      }
    } catch {
      // Ignore profile read errors.
    }
  }
  return null;
}

export function resolveElevenLabsApiKeyWithProfileFallback(
  env: NodeJS.ProcessEnv = process.env,
  deps: ElevenLabsApiKeyDeps = {},
): string | null {
  const envValue = (env[ELEVENLABS_API_KEY_ENV] ?? "").trim();
  if (envValue) {
    return envValue;
  }
  const profileValue = readApiKeyFromProfile(deps);
  if (profileValue) {
    return profileValue;
  }
  // Pool-only deployments (ELEVENLABS_API_KEYS, no singular ELEVENLABS_API_KEY)
  // still need one key here: callers that gate on a missing key before reaching
  // collectProviderApiKeysForExecution's rotation would otherwise dispatch with
  // no key at all.
  return collectProviderApiKeysForExecution({ provider: "elevenlabs" })[0] ?? null;
}
