# Poolside OpenClaw provider (vendored)

OpenClaw provider plugin for Poolside's Laguna model family, version 1.0.2 of
the MIT-licensed [`@poolside/openclaw-provider`](https://github.com/poolsideai/openclaw-provider)
ClawHub package.

That package's source repository is private; only a built `dist/index.js` is
published. This directory vendors that build output as `index.js` and treats
it as pseudo-source (patched directly, no separate build step) since no real
source is available to build from. See `index.js`'s header comment for the
local patch.

## Configure

```sh
export POOLSIDE_API_KEY=...
# or a comma-separated pool for rotation on rate limits:
export POOLSIDE_API_KEYS=key-1,key-2
```

Or run `openclaw onboard` and pick Poolside.

## Models

Every Laguna model supports text input, tool calling, and reasoning, and
returns up to 32k output tokens:

| Model ref                     | Context | Max output |
| ----------------------------- | ------: | ---------: |
| `poolside/laguna-s-2.1`       |    262k |        32k |
| `poolside/laguna-s-2.1:fast`  |  1.048M |        32k |
| `poolside/laguna-xs-2.1`      |    262k |        32k |
| `poolside/laguna-xs-2.1:fast` |    262k |        32k |
| `poolside/laguna-m.1`         |    262k |        32k |
| `poolside/laguna-m.1:fast`    |    262k |        32k |

The endpoint uses a temperature-only sampling contract: the plugin defaults
temperature to 0.7 when the caller sets none, and strips top_p, top_k, min_p,
penalties, and n.
