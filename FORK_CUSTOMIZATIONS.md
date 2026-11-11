# Fork customizations (TEA-ching/openclaw, branch `sctg-claw`)

What this fork changes on top of upstream `openclaw/openclaw`, plus the
procedure to sync with upstream without losing it. Last sync: upstream
`v2026.11.3`, branch `sync/2026.11.3` (previous: `050881cd69f`, 2026.10.2).

Source of truth for "what do we carry": `git diff upstream/main HEAD --stat`
(ignore `ui/src/i18n/.i18n/*`, generated). If the real diff and this file
disagree, fix this file.

## Sync procedure

Remotes: `origin` = `git@github.com:TEA-ching/openclaw.git` (branch
`sctg-claw`), `upstream` = `https://github.com/openclaw/openclaw.git`.
The fetch is slow (several minutes); run it in the background.

```sh
git fetch origin && git fetch upstream main
git checkout -B sctg-claw origin/sctg-claw
git merge upstream/main --no-edit      # merge, not rebase: sctg-claw is published
```

### The merge base is wrong: use the release tag as base

Earlier syncs were `git merge tag v2026.x.y`, and release tags live on release
branches, not in `main`'s history. `git merge-base` therefore picks a far older
commit and hundreds of files conflict (313 on the 2026.9.6 → 2026.10.2 sync)
although the fork never touched most of them.

Find the last synced tag commit and resolve each conflicted file with it as
the base:

```sh
TAG=$(git rev-parse <last "Merge tag 'vX' into sctg-claw" commit>^2)   # was eb377ac59e6 (v2026.9.6)
for f in $(git diff --name-only --diff-filter=U); do
  git show origin/sctg-claw:"$f" > ours
  git show $TAG:"$f"             > base      # empty file if absent
  git show upstream/main:"$f"    > theirs
  if cmp -s ours base; then cp theirs "$f"           # fork never touched it: take upstream
  else cp ours "$f"; git merge-file "$f" base theirs  # real 3-way; leftovers need hand work
  fi
done
```

Then, without hand work:

- `ui/src/i18n/.i18n/*`, `*/package.json` version bumps, `CHANGELOG*`: take upstream.
- `pnpm-lock.yaml`: take upstream, then `pnpm install --lockfile-only --ignore-scripts`
  (re-adds our `extensions/vibe` importer).
- A file deleted upstream that the fork only version-bumped (`apps/mobile/version.json`): delete it.

Hand work is the customization list below. When upstream refactored a file we
touch, re-apply our change to upstream's new structure rather than keeping the
old file (e.g. exa's `shared.ts` was merged into `exa-web-search-provider.ts`).

### After the merge

```sh
pnpm install --ignore-scripts --frozen-lockfile
pnpm tsgo:core && pnpm tsgo:extensions && pnpm tsgo:ui
pnpm exec vitest run extensions/{exa,elevenlabs,firecrawl,mistral,cohere,vibe,acpx,openrouter} \
  src/gateway/server-methods-list.test.ts src/gateway/server-http.probe.test.ts \
  src/agents/model-auth-env packages/ai/src/transports
```

- SQLite-backed tests (acpx process/lease/service tests, a packages/ai
  continuation test) need Node >= 24.16 (or 26.1+); on older Node they fail with
  "SQLite support is unavailable or unsafe". That is the environment, not the merge.
- Typecheck errors after a sync are usually a symbol upstream moved or a test
  list that must now include our additions (see "Things that broke last time").
- Then sync the root `../Dockerfile` (below) and bump the submodule pointer in the
  parent repo.

### Root `Dockerfile` (parent repo, not in this submodule)

`../Dockerfile` is `openclaw/Dockerfile` verbatim plus our additions (below the
"sctg-claw additions" marker, plus the `gogcli_builder`/`ciron_builder`/`gc-build`/
`vibe-build` stages and the `OPENCLAW_EXTENSIONS` default). After each sync, carry
upstream's Dockerfile changes over with a 3-way merge:

```sh
git show <old submodule commit>:Dockerfile > old
git merge-file ../Dockerfile old Dockerfile      # run from the parent repo; Dockerfile = new upstream
docker buildx build --check -f Dockerfile --build-context garmin-cli=./garmin-cli \
  --build-context openclaw-coach=./openclaw-coach --build-context k8s-infra=./k8s-infra \
  --build-context mistral-vibe=./mistral-vibe --build-context sctg-scripts=./scripts ./openclaw
```

Fork-specific decision: upstream's `ENTRYPOINT` (`node /app/docker-entrypoint.mjs`)
runs `doctor --fix --non-interactive` to repair retained-volume state, but only
when the command is a foreground `openclaw gateway`. Our `CMD` runs the gateway
under cirond, so that step is run explicitly in the `CMD`, before cirond.

## What we carry

### API-key pool rotation (`*_API_KEYS`)

Several keys per provider, rotated on rate limit / quota. Env vars `XXX_API_KEYS`
(comma/semicolon/whitespace separated); helpers `collectProviderApiKeysForExecution`
and `executeWithApiKeyRotation` from `openclaw/plugin-sdk/provider-auth-runtime`.
Keys are populated at container start by `scripts/resolve-keypool-vault.mjs` (parent repo).

| Area             | Files                                                                                                                                                                                                                                                                                                        |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Core             | `src/agents/api-key-rotation.ts` (aggressive mode), `src/agents/model-auth-env.ts` (a `*_API_KEYS` pool resolves to its first key; never hand back a raw pool), `src/plugin-sdk/provider-auth-runtime.ts`                                                                                                    |
| Mistral          | `extensions/mistral/index.ts` (`wrapStreamFn` + `wrapSimpleCompletionStreamFn` rotation), `realtime-transcription-provider-factory.ts`                                                                                                                                                                       |
| Cohere           | `extensions/cohere/*` (rotation, `COHERE_API_KEYS`, tool-schema compat for union-shaped params, `north-mini-code-1-0` model)                                                                                                                                                                                 |
| Exa              | `extensions/exa/src/exa-web-search-provider.runtime.ts` (`runExaSearch` + rotation), `exa-web-search-provider.ts` (`EXA_API_KEYS` in `envVars`), `openclaw.plugin.json`                                                                                                                                      |
| Firecrawl        | `extensions/firecrawl/src/*` (`FIRECRAWL_API_KEYS`)                                                                                                                                                                                                                                                          |
| ElevenLabs       | `extensions/elevenlabs/api-key-fallback.ts`, `tts.ts` (`*WithRotation`), `media-understanding-provider.ts`, `speech-provider-factory.ts`. The profile-file key fallback is deliberately out of `config-compat.ts` (keeps the doctor-contract closure free of `provider-auth-runtime`, which pulls in execa). |
| OpenRouter       | `extensions/openrouter/stream.ts` (rotation wrapper), manifest                                                                                                                                                                                                                                               |
| Shared transport | `packages/ai/src/transports/openai-completions-transport.ts` (rotation on the openai-completions transport)                                                                                                                                                                                                  |

Tests that pin this: `extensions/*/` rotation tests, `src/agents/api-key-rotation.test.ts`,
`src/agents/model-auth-env.provider-aliases.test.ts`.

### Mistral Vibe provider (`vibe`)

`extensions/vibe/*`: a provider for Mistral Vibe API keys against `https://api.mistral.ai/v1`, reusing
the Mistral wire behaviour (strict 9-char tool call ids, `max_tokens`, reasoning effort) under its own id so
`VIBE_API_KEYS` rotates independently of `MISTRAL_API_KEYS`. Models: `vibe/mistral-vibe-cli-latest` (API
alias of mistral-medium-3.5) and `vibe/mistral-vibe-cli-fast` (alias of mistral-small), 262k context, free
plan (zero cost). It exists because scheduled jobs routed through the ACP harness (`acp-vibe/...`) fail
model resolution in 2026.11. Keep `extensions/vibe/openclaw.plugin.json` in step with
`extensions/mistral/openclaw.plugin.json` (`providerRequest`, `providerEndpoints`) and add `vibe` to the
`OPENCLAW_EXTENSIONS` default in the parent `Dockerfile`. Tests: `extensions/vibe/vibe.test.ts`.

### Pool env vars are split, not passed whole

`src/agents/live-auth-keys.ts` (`collectProviderApiKeys`): a manifest-declared `*_API_KEYS` variable is split
like the pool variable instead of being appended as one raw "key" (which sent an invalid bearer token whenever
rotation reached that entry, for every pooled provider: mistral, cohere, vibe, ...).

### Debug payload summaries (openai-completions / responses)

`packages/ai/src/transports/openai-completions-debug.ts`, `openai-tool-debug-summary.ts`,
`openai-responses-debug.ts` (`stringifyRedactedPayload`, system-prompt elision, wider
inspection budgets). Hooked into `openai-completions-transport.ts` just before the
context-output-budget resolution.

### Mistral Vibe harness (`acp-vibe`)

`extensions/acpx/*` (native agent, harness attempt, config schema, manifest),
`src/agents/harness/host-capability*`, `ui/src/components/provider-icon-data.ts`
(`"acp-vibe": "Mistral Vibe"`). Tests with hard-coded harness lists (e.g.
`extensions/acpx/harness-reset.test.ts`) must include `acp-vibe`.

### Other

- `skills/garmin/SKILL.md`: Garmin CLI skill (CLI built in the parent repo's Docker image).
- `extensions/signal/api.ts`: redundant static monitor/probe exports removed.

## Dropped

- **Poolside provider** (`extensions/poolside`, vendored): removed. poolside.ai ended its LLM activity on
  2026-11-01. Its two bundled-plugin guardrail failures (naming, categories) went with it.

- **Custom VNC page / `desktop.observeLocal` bridge** (dropped at the 2026.11.3 sync):
  upstream's Desktop lab (`desktop.host.enabled=true`, `src/gateway/desktop/host-source.ts`)
  connects to the same loopback `x11vnc` on port 5900 that `scripts/ciron.toml` starts.
  Enable it in the chart config instead of carrying a page.
- **Probe bypass for unattributable proxies** (dropped at the 2026.11.3 sync): upstream now
  answers probes for configured trusted proxies and 403s untrusted ones, pinned by its own test.
  Kubelet probes arrive direct, and the chart already injects `10.0.0.0/8` into `trustedProxies`.
- **Mobile Broker sign-in in the iOS/macOS apps** (`apps/ios`, `apps/macos`,
  `MobileBroker*.swift`): removed. Mobile access goes through upstream's tailnet
  support with the parent repo's `mobile-auth-broker`. `apps/ios` and `apps/macos` are
  plain upstream; keep them that way.

## Divergences that are probably stale (verify, then reset to upstream)

Left over from merging release branches, not deliberate customizations:
`.build/swift-tools/*`, `apps/android/*` version files, `qa/scenarios/plugins/kitchen-sink-live-openai.yaml`,
`extensions/qa-lab/src/scenario-catalog-kitchen-sink-proof.test.ts`,
`packages/ai/src/anthropic-opus-55-transport-parity.test.ts`,
`packages/session-url-contract/src/share.ts`,
`scripts/e2e/lib/doctor-install-switch/shims/systemctl` and its test,
`scripts/ios-run.sh` (probably tied to the dropped iOS Mobile Broker work).
Check each with `git log upstream/main..HEAD -- <path>` before resetting.

## Things that broke last time (check first)

- Upstream folded `exa-web-search-provider.shared.ts` into `exa-web-search-provider.ts`; our `EXA_API_KEYS` envVars entry had to move with it, and the local `ExaSearchType`/`ExaSearchResult` types needed redefining in the runtime file.
- `extensions/elevenlabs/speech-provider-factory.ts` typed `normalizeVoiceSettings` via `typeof elevenLabsTTS`; ours uses `ElevenLabsTtsRequestParams`.
- Mistral realtime factory now takes `{ createRealtimeTranscriptionWebSocketSession }`; tests that call it must pass it.
