# Shortcut debt

Every deliberate shortcut in this spike carries a `shortcut:` comment naming its ceiling and upgrade path. This is the
ledger of those, regenerated from the code on 2026-11-09: **33 markers, 0 with no upgrade trigger.**

Re-scan: `git grep --no-index --exclude-standard -nE '(#|//|/[*]) ?(shortcut|ponytail):' | grep -v 'node_modules\|^deps/\|^_build/\|^priv/static/\|^patches/'`

Grouped by what to do first. `file:line` points at the comment.

## 0. Closed

- **The server trusted the socket the browser sent.** It now keeps its own copy (`LvStore`) and accepts only events,
  mount inputs and `{topic, seq}` references. A forged `:socket` param is never read (`lv_store_test.exs`).
- **The browser could forge `handle_info` messages through the replay log.** The log now carries `{topic, seq}`; the
  server resolves it from its own record of what the PubSub bridge delivered, and drops anything unrecorded, on a topic the
  LiveView did not subscribe to, or already applied (`lv_store_test.exs`, "bridged messages").
- **The browser chose which PubSub topics it was subscribed to.** The server now derives them by running the same mount
  (`LvSubscriptions`); the browser's list is only a trigger.

Still trusted from the browser: mount inputs (URL params and flash), event params, and the `href` it reports.

## 1. Fix before anything real

| Where | What was simplified | Ceiling | Upgrade |
|---|---|---|---|
| `lv_subscriptions.ex:8` | topics are derived from mount only | a view that subscribes in `handle_event`, `handle_params` or `handle_info` gets no bridged messages | run the replayed log under the same recorder |
| `lv_local_page.ex:76` | the server's socket replaces the browser's and the log is emptied after a server round trip | an event handled in the browser during the round trip is lost | queue events during a round trip, or re-apply the leftover log |
| `lv_store.ex:34` | in-memory ETS, one node, entries and messages swept after an hour | state is lost on restart and not shared across nodes; a client offline for over an hour has its logged messages dropped; leaving a view never deletes its entry | monitor the page, or share the store across nodes |
| `pubsub_bridge.ex:7` | a topic's bridge process lives until the node stops | topics are now server-derived, so bounded by the views, but never stopped | stop a bridge when its last subscriber leaves |

## 2. LiveComponents

Stateful components work when the parent mounts in the browser, and when it mounts on the server as long as the component
registry holds no closures. What does not:

| Where | What was simplified | Ceiling | Upgrade |
|---|---|---|---|
| `lv_local_page.ex:205` | a component event that reaches a server-only call cannot fall back | the server does not hold component state, so it raises | keep the component registry in `LvStore` and replay component events |
| `lv_runner.ex:185` | the component registry crosses the wire only if it has no closures | a component with a slot, stream or hook is reset on export and then stops answering events (loudly: `no LiveComponent with cid N`) | export component specs the way `export_socket/1` does for streams |
| `lv_components.ex:8`, `config.exs:42` | components are listed by hand in two places | a new component needs both lists | generate both from `use Phoenix.LiveComponent` |

Not tried: `send_update/3` (it uses `send(self(), ...)`, and the browser has no process model), `update_many/1`, `preload/1`,
nested components with slots, and components that mount through a server-only call.

## 3. Limits that will bite on real LiveViews

| Where | What was simplified | Ceiling | Upgrade |
|---|---|---|---|
| `lv_runner.ex:180` | closures are stripped from a socket before it crosses the wire and only `stream/4`'s are rebuilt | a custom `dom_id` (`stream_configure/3`) and hooks from other `attach_hook/4` calls are lost; the render state resets so the next render is full | export hook and `dom_id` specs instead of closures |
| `server.ex:10` | a handler that reaches a server-only call is re-run on the server | work done before that call is discarded and repeated | split the handler at the call if earlier work is costly |
| `lv_views.ex:10` | views are registered by hand | a view must be added to the list | collect every `use Phoenix.LiveView` module in a namespace |
| `lv_views.ex:31` | query strings are split on `&` and `=` | no URL decoding, repeated or nested keys | port `URI.decode_query` |
| `lv_params.ex:3` | form params decode one level of nesting plus `[]` lists | `a[b][c]` is wrong | port `Plug.Conn.Query.decode` |
| `signup_live.ex:63` | plain `<form>` | `<.form>` pulls in CSRF token generation | port or stub `Plug.CSRFProtection` |
| `lv_json.ex:2`, `jason_client.ex:5` | JSON encoder covers diff shapes only | escapes `\ " \n \r \t` only; no floats, structs or options | a real `:json` port |
| `lv_local_page.ex:27` | `data-phx-session` and `data-phx-static` are dummy tokens | nothing is signed or verified | real tokens if sessions or redirects need them |

## 4. Stand-ins for modules that can't run in the browser

| Where | Stands in for | Ceiling | Upgrade |
|---|---|---|---|
| `endpoint_client.ex:4` | `Endpoint.static_path/path` | paths come back as given: no digest or `vsn`, no host, so production URLs differ | ship the static manifest, or render static paths on the server |
| `gettext_client.ex:4` | `Gettext` | English only, no catalogs or locales | translate on the server, or ship compiled catalogs |
| `signup.ex:14` | Gettext for the signup demo | `%{key}` interpolation, English | covered by the Gettext row above |
| `application.ex:15` | dev-mode lazy module loading | modules are preloaded at boot so structs in a decoded socket have their atoms | have Hologram's deserializer load a struct's module first |

## 5. Cosmetic or timing

| Where | What | Upgrade |
|---|---|---|
| `local_lv.js:69` | page-mounted detection wraps `pageMountData` plus a timer | ask Hologram for a mount event |
| `layout.ex:5` | `local_lv.js` loads on every page | load it only where a LiveView lives |

## 6. Changes to vendored Hologram (`vendor/hologram`)

These are why the app only runs against a patched copy. They are split into one patch per concern in
`patches/hologram/` and verified to reproduce the vendored tree from pristine 0.12.7 (see that README).

| Where | Change | Ceiling | Upgrade |
|---|---|---|---|
| `interpreter.mjs:2729` | comprehension filters bind variables | none known; this is a bug fix | upstream it; `patches/hologram/checks/0001-comprehension-filter.mjs` reproduces it |
| `erlang.mjs:2163` | `:erlang.get/put/erase` use one global map | no per-process semantics | only if it ever matters |
| `telemetry.mjs:11` | `:telemetry.span/3` runs its function and drops the events | no handlers on the client | dispatch to handlers the app registers |
| `application.mjs:12` | `Application.get_env` returns the default on the client | no app config reaches the browser | ship selected config to the client |
| `call_graph.ex:103` | three form-field dispatch edges, written for `FormData.Map` | other `FormData` impls need an edge; changeset-backed forms worked without one in the CRUD form | declare edges via the config below |
| `call_graph.ex:97` | `config :hologram, dynamic_dispatch_edges` | not part of the call-graph cache key | a documented option that invalidates the cache |
| `ir.ex:575` | `config :hologram, server_only_modules` | not in the IR cache key; clear the PLTs when it changes | a documented option and a cache key |
| `ir.ex:561` | `config :hologram, client_module_overrides` | same cache gap | same |
| `phoenix_pubsub.mjs:6` | `Phoenix.PubSub.subscribe/3` recorded in the browser | no unsubscribe, one PubSub name | port `unsubscribe/2` and scope by name |
| `mix.exs:204` | `dep?` always true | breaks if Hologram goes back to `deps/` | drop it then |

## Untracked

Not shortcuts but unverified, so they will not show up in a re-scan:

- Replay assumes handlers are deterministic; replaying a long log was never measured.
- A fresh browser with no session cookie and two tabs opened at the same moment: Hologram's identity cross-check returns
  403 to the tab that loses the race. This is Hologram's behavior, hit while testing, and not investigated further.
- No test for back/forward navigation, or a reload on `/items/new`.
- No comparison of server-rendered `/items` against the browser render byte for byte.
- Everything ran against the dev server, never a release.
- Uploads, `assign_async`, `on_mount` hooks and `live_session` boundaries.
- `handle_params` and `push_patch` work (see `FilterLive`), but a patch between two different LiveViews,
  `replace: true`, and `JS.patch` were not exercised.
