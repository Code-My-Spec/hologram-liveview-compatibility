defmodule HologramLiveviewSpikeWeb.Holo.LvRunner do
  # Minimal stand-in for Phoenix.LiveView.Channel: the same socket setup, lifecycle hooks and render
  # steps, minus transport, components and navigation.
  alias HologramLiveviewSpikeWeb.Holo.{LvComponents, LvViews}
  alias Phoenix.LiveView.{Diff, Lifecycle, LiveStream, Socket, Utils}

  def new(view, live_action, params, flash, uri) do
    socket = %Socket{
      id: "phx-local",
      view: view,
      assigns: %{__changed__: %{}, flash: flash, live_action: live_action},
      private: %{
        connect_params: %{},
        connect_info: %{},
        assign_new: {%{}, []},
        lifecycle: %Lifecycle{},
        root_view: view,
        live_temp: %{},
        live_session_name: nil,
        lv_origin: origin(uri)
      }
    }

    {:ok, socket} = LvViews.mount(view, params, %{}, socket)
    socket = call_handle_params(view, socket, params, uri)

    paint(
      %{
        view: view,
        socket: socket,
        prints: Diff.new_fingerprints(),
        comps: Diff.new_components()
      },
      true
    )
  end

  # Runs wherever it is called: in the browser first; the page re-runs it on the server if it reaches a server-only call.
  def handle(_view, socket, "lv:clear-flash", params) do
    case params do
      %{"key" => key} -> Utils.clear_flash(socket, key)
      _ -> Utils.clear_flash(socket)
    end
  end

  def handle(view, socket, name, params) do
    case Lifecycle.handle_event(name, params, socket) do
      {:cont, socket} ->
        {:noreply, socket} = LvViews.handle_event(view, name, params, socket)
        apply_patch_redirect(view, socket)

      {:halt, socket} ->
        socket
    end
  end

  # handle_params runs after mount, on a live_patch from the client, and when a handler calls push_patch.
  def call_handle_params(view, socket, params, uri) do
    case Lifecycle.handle_params(params, uri, socket) do
      {:cont, socket} ->
        {:noreply, socket} = LvViews.handle_params(view, params, uri, socket)
        socket

      {_halt, socket} ->
        socket
    end
  end

  # A live_patch from the client: new action and params, same LiveView.
  def patch(state, live_action, params, uri) do
    paint(
      %{state | socket: apply_patch(state.view, state.socket, live_action, params, uri)},
      false
    )
  end

  def apply_patch(view, socket, live_action, params, uri) do
    socket = socket |> Phoenix.Component.assign(:live_action, live_action) |> Utils.clear_flash()
    call_handle_params(view, socket, params, uri)
  end

  # push_patch in a handler: like the channel, drop the redirect, run handle_params for the new URL, and remember the
  # patch so the page can tell the client to update its URL.
  def apply_patch_redirect(view, socket) do
    case socket.redirected do
      {:live, :patch, %{to: to} = opts} ->
        {_view, live_action, params} = LvViews.resolve_url(to)

        socket =
          %{socket | redirected: nil} |> Phoenix.Component.assign(:live_action, live_action)

        socket = call_handle_params(view, socket, params, socket.private.lv_origin <> to)
        %{socket | private: Map.put(socket.private, :lv_pending_patch, opts)}

      _other ->
        socket
    end
  end

  defp origin(uri) do
    [scheme, "", host | _rest] = String.split(uri, "/", parts: 4)
    scheme <> "//" <> host
  end

  # An event aimed at a LiveComponent (phx-target={@myself}): run it on that component's own socket and render only its diff,
  # the way the channel does with Diff.write_component/4.
  def component_event(state, cid, name, params) do
    fun = fn component_socket, component ->
      component_socket =
        case Lifecycle.handle_event(name, params, component_socket) do
          {:cont, component_socket} ->
            {:noreply, component_socket} =
              LvComponents.handle_event(component, name, params, component_socket)

            component_socket

          {:halt, component_socket} ->
            component_socket
        end

      {component_socket, {component_socket.redirected, component_socket.assigns.flash}}
    end

    case Diff.write_component(state.socket, cid, state.comps, fun) do
      {diff, comps, _extra} -> {diff, %{state | comps: comps}}
      # The channel answers an unknown cid with a stale error so the client reloads; here it must not pass silently.
      :error -> raise ArgumentError, "no LiveComponent with cid #{cid}"
    end
  end

  # What a render leaves behind (hooks, cleared changes) without rendering: the state a socket is in between events.
  def settle(socket) do
    socket = socket |> Lifecycle.after_render() |> Utils.clear_changed() |> Utils.clear_temp()
    %{socket | private: Map.delete(socket.private, :lv_pending_patch)}
  end

  # Re-applies the events and messages the browser handled locally since the last sync, as the server would have seen them.
  # The log must already be resolved by the server: {:info, message} entries come from LvStore's record of what the bridge
  # delivered, never from the browser (see LvLocalPage.resolve_log/2).
  def replay(view, socket, log) do
    Enum.reduce(log, socket, fn
      {:event, name, params}, socket ->
        socket |> then(&handle(view, &1, name, params)) |> settle()

      {:info, message}, socket ->
        apply_info(view, socket, message) |> settle()

      {:patch, live_action, params, uri}, socket ->
        apply_patch(view, socket, live_action, params, uri) |> settle()
    end)
  end

  def apply_info(view, socket, message) do
    {:noreply, socket} = LvViews.handle_info(view, message, socket)
    socket
  end

  def info(state, message) do
    paint(%{state | socket: apply_info(state.view, state.socket, message)}, false)
  end

  def event(state, name, params),
    do: paint(%{state | socket: handle(state.view, state.socket, name, params)}, false)

  def paint(%{view: view, socket: socket} = state, force?) do
    # Like the channel, a redirect skips the render.
    if socket.redirected == nil and (force? or Utils.changed?(socket)) do
      {diff, prints, comps} =
        Diff.render(socket, LvViews.render(view, socket.assigns), state.prints, state.comps)

      socket = socket |> Lifecycle.after_render() |> Utils.clear_changed() |> Utils.clear_temp()
      {diff, %{state | socket: socket, prints: prints, comps: comps}}
    else
      {%{}, state}
    end
  end

  # A socket crosses the Hologram wire (browser <-> server) as plain data, so the closures Phoenix keeps in it are
  # dropped on the way out and rebuilt on the way in: each stream's dom_id and its after_render hook.
  # shortcut: only the closures `stream/4` creates are rebuilt (default dom_id); a custom dom_id from stream_configure/3 and
  # hooks from other attach_hook/4 calls are lost across the wire. Upgrade by exporting hook/dom_id specs instead of closures.
  # The render-tracking state (prints) holds slot closures too, so it is reset: the receiver's next render is a full one.
  # The component registry (each LiveComponent's own assigns and state) crosses the wire only if it holds no closures;
  # otherwise it is reset, and the components it described stop answering events (component_event/4 then raises).
  # shortcut: a component with a slot, a stream or a hook in it (any closure) cannot be exported; upgrade by exporting
  # the component specs the way export_socket/1 does for streams.
  def export(state) do
    comps = if has_function?(state.comps), do: Diff.new_components(), else: state.comps

    %{state | socket: export_socket(state.socket), prints: Diff.new_fingerprints(), comps: comps}
  end

  defp has_function?(term) when is_function(term), do: true
  defp has_function?(%_{} = struct), do: struct |> Map.from_struct() |> has_function?()

  defp has_function?(map) when is_map(map),
    do: Enum.any?(map, fn {key, value} -> has_function?(key) or has_function?(value) end)

  defp has_function?(list) when is_list(list), do: Enum.any?(list, &has_function?/1)
  defp has_function?(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> has_function?()
  defp has_function?(_other), do: false

  def import(state), do: %{state | socket: import_socket(state.socket)}

  def export_socket(socket) do
    # __changed__ keeps the previous value of changed assigns, so it can hold the old streams (and their closures) too.
    changed = Map.update(socket.assigns.__changed__, :streams, nil, &strip_streams/1)
    changed = if changed.streams == nil, do: Map.delete(changed, :streams), else: changed

    assigns =
      socket.assigns
      |> Map.put(:__changed__, changed)
      |> Map.update(:streams, %{}, &strip_streams/1)

    %{socket | assigns: assigns, private: Map.put(socket.private, :lifecycle, %Lifecycle{})}
  end

  defp strip_streams(streams) when is_map(streams) do
    Map.new(streams, fn
      {name, %LiveStream{} = stream} -> {name, %{stream | dom_id: nil}}
      other -> other
    end)
  end

  defp strip_streams(other), do: other

  def import_socket(socket) do
    socket.assigns
    |> Map.get(:streams, %{})
    |> Enum.reduce(socket, fn
      {name, %LiveStream{} = stream}, socket ->
        stream = %{
          stream
          | dom_id: fn item -> Atom.to_string(name) <> "-" <> to_string(item.id) end
        }

        streams = Map.put(socket.assigns.streams, name, stream)

        socket
        |> Map.update!(:assigns, &Map.put(&1, :streams, streams))
        |> Phoenix.LiveView.attach_hook(name, :after_render, &prune_stream(&1, name))

      _other, socket ->
        socket
    end)
  end

  defp prune_stream(socket, name) do
    if name in socket.assigns.streams.__changed__ do
      Phoenix.Component.update(socket, :streams, fn streams ->
        streams
        |> Map.update!(:__changed__, &MapSet.delete(&1, name))
        |> Map.update!(name, &LiveStream.prune/1)
      end)
    else
      socket
    end
  end
end
