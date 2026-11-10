defmodule HologramLiveviewSpikeWeb.Holo.LvLocalPage do
  # The LiveView below runs in the browser, except mounts and events that reach a server-only call. Those run on
  # the server against its own copy of the socket (LvStore); the browser only sends inputs: the mount URL, the events
  # it handled locally since the last sync (the log), and the event itself. This page is only the bridge between
  # phoenix_live_view.js (local_lv.js) and the transpiled LvRunner.
  use Hologram.Page
  use Hologram.JS
  alias HologramLiveviewSpike.LvStore
  alias HologramLiveviewSpikeWeb.Holo.{LvJson, LvParams, LvRunner, LvSubscriptions, LvViews}

  route "/lv/:view"
  param :view, :string
  layout HologramLiveviewSpikeWeb.Holo.Layout

  def init(params, component, _server),
    do:
      put_state(component,
        lv: nil,
        view: params.view,
        flash_next: %{},
        lv_id: nil,
        inputs: nil,
        log: []
      )

  # The root never changes from Hologram's point of view; the LiveView client owns its children.
  # shortcut: data-phx-session/static are dummy tokens (nothing is signed or verified); upgrade if sessions or redirects are needed.
  def template do
    ~HOLO"""
    <div id="lv-root" data-phx-main="true" data-phx-session="s" data-phx-static="t"></div>
    """
  end

  def action(:lv, %{ref: ref, kind: "join", url: url, href: href}, component) do
    Process.put(:lv_client?, true)
    {view, live_action, params} = LvViews.resolve_url(url)
    flash = component.state.flash_next
    inputs = %{view: view, live_action: live_action, params: params, flash: flash, href: href}
    lv_id = JS.call(:lvNewId, [])

    component =
      put_state(component, flash_next: %{}, lv_id: lv_id, inputs: inputs, log: [])

    try do
      {diff, st} = LvRunner.new(view, live_action, params, flash, href)
      reply(component, ref, "join", diff, st)
    rescue
      e ->
        # mount reached a server-only call: run mount on the server and take the result.
        if server_only?(e),
          do: put_command(component, :lv_mount, ref: ref, lv_id: lv_id, inputs: inputs),
          else: raise(e)
    end
  end

  def action(:lv, %{ref: ref, kind: "patch", url: url, href: href}, component) do
    Process.put(:lv_client?, true)
    {_view, live_action, params} = LvViews.resolve_url(url)
    local(component, ref, {:patch, live_action, params, href})
  end

  def action(:lv, %{ref: ref, event: event, cid: cid, value: pairs}, component)
      when is_integer(cid) do
    Process.put(:lv_client?, true)
    local(component, ref, {:component_event, cid, event, LvParams.decode(pairs)})
  end

  def action(:lv, %{ref: ref, event: event, value: pairs}, component) do
    Process.put(:lv_client?, true)
    local(component, ref, {:event, event, LvParams.decode(pairs)})
  end

  def action(:lv_mounted, %{ref: ref, diff: diff, st: st}, component),
    do: reply(component, ref, "join", diff, st)

  # shortcut: the server's socket replaces ours and the log is emptied, so an event handled in the browser while the
  # server round trip was in flight is lost; upgrade by queueing events during a round trip, or re-applying the leftover log.
  def action(:lv_done, %{ref: ref, socket: socket}, component) do
    {diff, st} =
      LvRunner.paint(%{component.state.lv | socket: LvRunner.import_socket(socket)}, false)

    reply(put_state(component, :log, []), ref, "event", diff, st)
  end

  # A bridged PubSub message arrived from the server: run handle_info and push the diff to the LiveView client.
  def action(:lv_info, %{topic: topic, seq: seq, message: message}, component) do
    {diff, st} = LvRunner.info(component.state.lv, message)
    JS.call(:lvLocalPush, [LvJson.enc(diff)])

    component
    |> put_state(:lv, st)
    |> put_state(:log, component.state.log ++ [{:info, topic, seq}])
    |> subscribe_new_topics()
  end

  def command(:lv_mount, %{ref: ref, lv_id: lv_id, inputs: inputs}, server) do
    {{diff, st}, topics} = LvSubscriptions.mount(inputs)
    LvStore.save(store_key(server, lv_id), %{socket: st.socket, topics: topics, applied: %{}})
    server = bridge(server, topics)
    put_action(server, :lv_mounted, ref: ref, diff: diff, st: LvRunner.export(st))
  end

  # The browser says its mount subscribed to something; the server decides to what, by mounting the same inputs.
  def command(:lv_subscribe, %{lv_id: lv_id, inputs: inputs}, server) do
    key = store_key(server, lv_id)
    topics = LvSubscriptions.derive(inputs)
    LvStore.save(key, %{LvStore.fetch(key) | topics: topics})
    bridge(server, topics)
  end

  def command(:lv_server, %{ref: ref, lv_id: lv_id, inputs: inputs, log: log, op: op}, server) do
    key = store_key(server, lv_id)
    entry = LvStore.fetch(key)
    view = inputs.view

    # The server's copy is the authority. If this LiveView never touched the server (it mounted in the browser), mount it
    # here from the same inputs; then catch up on what the browser handled locally.
    socket =
      case entry.socket do
        nil ->
          {_diff, st} =
            LvRunner.new(view, inputs.live_action, inputs.params, inputs.flash, inputs.href)

          st.socket

        stored ->
          LvRunner.settle(stored)
      end

    {log, applied} = resolve_log(log, entry)

    socket =
      socket
      |> then(&LvRunner.replay(view, &1, log))
      |> then(&apply_op(view, &1, op))

    LvStore.save(key, %{entry | socket: socket, applied: applied})
    put_action(server, :lv_done, ref: ref, socket: LvRunner.export_socket(socket))
  end

  # The browser's log names bridged messages by {topic, seq}. Only ones the server recorded, on a topic this LiveView
  # subscribed to, and newer than the last one applied, become messages; anything else is dropped.
  defp resolve_log(log, entry) do
    Enum.reduce(log, {[], entry.applied}, fn
      {:info, topic, seq}, {resolved, applied} ->
        with true <- topic in entry.topics,
             true <- seq > Map.get(applied, topic, 0),
             {:ok, message} <- LvStore.fetch_message(topic, seq) do
          {resolved ++ [{:info, message}], Map.put(applied, topic, seq)}
        else
          _ -> {resolved, applied}
        end

      op, {resolved, applied} ->
        {resolved ++ [op], applied}
    end)
  end

  defp bridge(server, topics) do
    Enum.reduce(topics, server, fn topic, server ->
      :ok = HologramLiveviewSpike.PubSubBridge.ensure(topic)
      put_subscription(server, {:pubsub, topic})
    end)
  end

  defp apply_op(view, socket, {:event, event, params}),
    do: LvRunner.handle(view, socket, event, params)

  defp apply_op(view, socket, {:patch, live_action, params, href}),
    do: LvRunner.apply_patch(view, socket, live_action, params, href)

  defp store_key(server, lv_id) do
    # Hologram cross-checks the instance against the session, so the key can't be reached from another tab's identity.
    {server.session_id, server.instance_id, lv_id}
  end

  # Runs an event or a patch in the browser and keeps it in the log; if it reaches a server-only call, the server's copy
  # of the socket catches up on the log and runs it instead.
  defp local(component, ref, op) do
    st = component.state.lv

    try do
      {diff, st} = run_op(st, op)
      reply(component |> log(op), ref, "event", diff, st)
    rescue
      e ->
        if server_only?(e) and not component_op?(op),
          do:
            put_command(component, :lv_server,
              ref: ref,
              lv_id: component.state.lv_id,
              inputs: component.state.inputs,
              log: component.state.log,
              op: op
            ),
          else: raise(e)
    end
  end

  # Component events are not logged: a component's state lives in the browser's render state, not in the parent socket
  # the server keeps, so there is nothing for the server to replay.
  defp log(component, {:component_event, _cid, _event, _params}), do: component
  defp log(component, op), do: put_state(component, :log, component.state.log ++ [op])

  # shortcut: a component event that reaches a server-only call cannot fall back, because the server does not hold
  # component state; it raises. Upgrade by keeping the component registry in LvStore and replaying component events.
  defp component_op?({:component_event, _cid, _event, _params}), do: true
  defp component_op?(_op), do: false

  defp run_op(st, {:component_event, cid, event, params}),
    do: LvRunner.component_event(st, cid, event, params)

  defp run_op(st, {:event, event, params}), do: LvRunner.event(st, event, params)

  defp run_op(st, {:patch, live_action, params, href}),
    do: LvRunner.patch(st, live_action, params, href)

  defp server_only?(%ErlangError{original: :hologram_server_only}), do: true
  defp server_only?(_), do: false

  defp reply(component, ref, kind, diff, st) do
    redirected = st.socket.redirected

    # A push_patch left a pending patch on the socket: tell the client to update its URL after the diff.
    patch = Map.get(st.socket.private, :lv_pending_patch)
    st = %{st | socket: %{st.socket | private: Map.delete(st.socket.private, :lv_pending_patch)}}

    JS.call(:lvLocalReply, [ref, kind, LvJson.enc(response(kind, diff, redirected))])
    if patch, do: JS.call(:lvLocalPushMsg, ["live_patch", LvJson.enc(patch)])
    component = put_state(component, :lv, st)

    # Flash survives a redirect: the next join reads it back (a signed token in real LiveView).
    component =
      if redirected == nil,
        do: component,
        else: put_state(component, :flash_next, st.socket.assigns.flash)

    subscribe_new_topics(component)
  end

  defp response("join", diff, _redirected), do: %{rendered: diff}
  defp response("event", diff, nil), do: %{diff: diff}

  defp response("event", _diff, {:live, :redirect, %{to: to, kind: kind}}),
    do: %{live_redirect: %{to: to, kind: Atom.to_string(kind)}}

  defp response("event", _diff, {:live, :patch, %{to: to, kind: kind}}),
    do: %{live_patch: %{to: to, kind: Atom.to_string(kind)}}

  defp response("event", _diff, {:redirect, %{to: to}}), do: %{redirect: %{to: to}}

  # Phoenix.PubSub.subscribe/3 is ported in the browser to record topics; hand any new ones to the server.
  defp subscribe_new_topics(component) do
    case JS.call(:lvTakeTopics, []) do
      [] ->
        component

      _topics ->
        put_command(component, :lv_subscribe,
          lv_id: component.state.lv_id,
          inputs: component.state.inputs
        )
    end
  end
end
