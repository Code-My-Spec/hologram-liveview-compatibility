// Runs the stock LiveView client against an in-browser "server": instead of a WebSocket,
// frames go to a Hologram page (transpiled LiveView code) and diffs come back via lvLocalReply.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

const pending = new Map() // ref -> [join_ref, topic]
let conn = null

let joined = null // [join_ref, topic] of the one LiveView this spike hosts

const frame = (jr, ref, topic, event, payload) =>
  conn.onmessage({data: JSON.stringify([jr, ref, topic, event, payload])})

class LocalConn {
  constructor() {
    conn = this
    this.readyState = 0
    setTimeout(() => { this.readyState = 1; this.onopen && this.onopen({}) }, 0)
  }
  close() { this.readyState = 3; this.onclose && this.onclose({code: 1000}) }
  send(data) {
    const [jr, ref, topic, event, payload] = JSON.parse(data)
    if (event === "phx_join" || event === "event" || event === "live_patch") {
      pending.set(ref, [jr, topic])
      if (event === "phx_join") joined = [jr, topic]
      // Forms arrive urlencoded, clicks as an object; either way hand Elixir [key, value] string pairs.
      const v = payload.value
      const value = event !== "event" ? [] : typeof v === "string"
        ? [...new URLSearchParams(v).entries()]
        : Object.entries(v || {}).map(([k, x]) => [k, String(x)])
      // A navigation join carries the target as `redirect`, the first one as `url`; the route table is on the Elixir side.
      const target = new URL(payload.url || payload.redirect || "/", location.href)
      globalThis.Hologram.dispatchAction("lv", "page", {
        ref, kind: event === "phx_join" ? "join" : event === "live_patch" ? "patch" : "event", event: payload.event || "", cid: payload.cid ?? null, value,
        url: target.pathname + target.search, href: target.href,
      })
    } else {
      // Only these are acknowledged; anything else is unimplemented and must say so.
      const ok = ["heartbeat", "phx_leave", "cids_will_destroy", "cids_destroyed"].includes(event)
      if (!ok) console.error(`local_lv: unhandled LiveView frame "${event}" on ${topic}`, payload)
      setTimeout(() => frame(jr, ref, topic, "phx_reply", ok ? {status: "ok", response: {}} : {status: "error", response: {reason: `unimplemented: ${event}`}}), 0)
    }
  }
}

// Called from the transpiled Elixir side with the diff already encoded as JSON.
// `responseJson` is the whole channel reply body: {rendered}, {diff}, {live_redirect}, {live_patch} or {redirect}.
globalThis.lvLocalReply = (ref, kind, responseJson) => {
  const [jr, topic] = pending.get(ref)
  pending.delete(ref)
  const response = JSON.parse(responseJson)
  if (kind === "join") response.liveview_version = globalThis.liveSocket.version()
  frame(jr, ref, topic, "phx_reply", {status: "ok", response})
}

// Server-initiated render (handle_info): the same diff frame a real channel would push.
globalThis.lvLocalPush = (diffJson) => frame(joined[0], null, joined[1], "diff", JSON.parse(diffJson))
globalThis.lvLocalPushMsg = (event, payloadJson) => frame(joined[0], null, joined[1], event, JSON.parse(payloadJson))

// An unguessable id for each LiveView mount; the server keys its copy of the socket on it (plus the tab's identity).
globalThis.lvNewId = () => (globalThis.crypto?.randomUUID?.() ?? Array.from({length: 4}, () => Math.random().toString(16).slice(2)).join(""))

// Topics recorded by the ported Phoenix.PubSub.subscribe/3, drained by the page.
globalThis.lvTakeTopics = () => { const t = [...(globalThis.__lvTopics ?? [])]; globalThis.__lvTopics = new Set(); return t }

const liveSocket = new LiveSocket("/live", Socket, {transport: LocalConn})
globalThis.liveSocket = liveSocket

// shortcut: Hologram has no "page mounted" event, so wrap pageMountData (called once at mount) and
// connect shortly after; the timer covers a mount that already happened. Upgrade: ask upstream for the event.
let started = false
const start = () => { if (!started) { started = true; liveSocket.connect() } }
const mountData = globalThis.Hologram?.pageMountData
if (mountData) {
  globalThis.Hologram.pageMountData = (deps) => { const r = mountData(deps); setTimeout(start, 150); return r }
}
setTimeout(start, 4000)
