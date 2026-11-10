# Hologram patches

`vendor/hologram` is Hologram 0.12.7 plus the changes in this directory. Each patch is one concern, in the order they
apply. Applied in order to pristine 0.12.7 they reproduce `vendor/hologram` byte for byte (checked with `git apply`).

```sh
mkdir /tmp/holo && tar -xf ~/.hex/packages/hexpm/hologram-0.12.7.tar -C /tmp/holo
mkdir /tmp/holo/src && tar -xzf /tmp/holo/contents.tar.gz -C /tmp/holo/src
cd /tmp/holo/src && for p in /path/to/patches/hologram/*.patch; do git apply "$p"; done
```

## What each one is worth offering upstream

| Patch | Upstream? | Why |
|---|---|---|
| `0001-comprehension-filter-binds-variables` | **yes, first** | A real bug. `for x <- xs, y = f(x), do: {x, y}` loses `y` in the body, so `Phoenix.LiveView.Engine.to_component_static` breaks on every second render of a component. `checks/0001-comprehension-filter.mjs` reproduces it (passes patched, fails pristine; run `node` with the path to an `assets/js`, needs `lodash` resolvable). It is a standalone check, not a test in Hologram's own suite, and I only have the Hex package, which ships no JS tests. |
| `0002-erlang-process-dictionary` | maybe | Fills a gap (`:erlang.get/put/erase`), but with one global map for the page, which will not match a real process model. |
| `0003-client-application-get-env` | needs design | Returns the default on the client. Shipping real config to the browser is a design question for the maintainers. |
| `0004-form-field-dispatch-edges` | maybe | Three edges so `form[:field]` works for map-backed `Phoenix.HTML.Form`. Ties the compiler to `phoenix_html`; a general mechanism (0005) is the better home. |
| `0005-configurable-dynamic-dispatch-edges` | with design | `config :hologram, dynamic_dispatch_edges`. Needs to be part of the call-graph cache key. |
| `0006-server-only-modules` | with design | `config :hologram, server_only_modules`. Stubs a module's functions to `:erlang.error(:hologram_server_only)` in the IR so the module's dependencies never reach the client bundle. Needs a documented error and a cache key. |
| `0007-client-module-overrides` | with design | `config :hologram, client_module_overrides`. Compiles a stand-in module as the real one for the browser only. |
| `0008-phoenix-pubsub-port` | no | App-level. Hologram has its own realtime layer; this exists only so an unmodified `Phoenix.PubSub.subscribe` records a topic. |
| `0009-LOCAL-ONLY-path-dep-application-start` | no | `dep?` checks the source path ends in `/deps/hologram/mix.exs`, so a `path:` dependency never declares its application and the app starts without Hologram's supervisor (every request 500s with "no persistent term stored"). A real fix would detect "compiled as a dependency" some other way. |
| `0010-erlang-telemetry-span` | maybe | `:telemetry.span/3` as run-and-return. LiveView's component mount and update paths wrap their work in it, so no LiveComponent runs without it. Upstream may prefer real client handlers. |

The IR cache is not keyed on the configs in 0005 to 0007. After changing them, clear the compiler's cached files in
`_build/<env>/lib/hologram/priv` before compiling.
