defmodule HologramLiveviewSpikeWeb.Holo.LvViews do
  @moduledoc """
  Which LiveViews can run in the browser, and dispatch to them. Hologram's call graph can't follow
  `view.mount(...)` on a variable, but it follows these clauses, so every listed view is bundled.
  """
  alias HologramLiveviewSpikeWeb.Holo.SignupLive
  alias HologramLiveviewSpikeWeb.{ComponentLive, ComponentServerLive, FilterLive, ItemLive}
  alias HologramLiveviewSpikeWeb.Router

  # shortcut: views are listed by hand; upgrade by collecting every `use Phoenix.LiveView` module in a namespace.
  @views %{
    "signup" => SignupLive,
    "items" => ItemLive.Index,
    "item_show" => ItemLive.Show,
    "item_form" => ItemLive.Form,
    "filter" => FilterLive,
    "components" => ComponentLive,
    "components_server" => ComponentServerLive
  }

  # The router's live routes for the registered views, as {path segments, view, live_action}, in router order.
  @routes (for route <- Phoenix.Router.routes(Router),
               {view, action, _opts, _live_session} <- [route.metadata[:phoenix_live_view]],
               view in Map.values(@views) do
             {String.split(route.path, "/", trim: true), view, action}
           end)

  def resolve(name), do: Map.fetch!(@views, name)

  @doc "Maps a request path (with optional query) to {view, live_action, params}; /lv/:name is the entry page."
  # shortcut: query values are not URL-decoded and repeated or nested keys are not supported; upgrade by porting URI.decode_query.
  def resolve_url(url) do
    [path | query] = String.split(url, "?", parts: 2)
    segments = String.split(path, "/", trim: true)

    case segments do
      ["lv", name] ->
        {resolve(name), nil, %{}}

      _ ->
        Enum.find_value(@routes, fn {pattern, view, action} ->
          case match(pattern, segments, parse_query(query)) do
            {:ok, params} -> {view, action, params}
            :error -> nil
          end
        end) || raise ArgumentError, "no live route for #{url}"
    end
  end

  defp match([], [], params), do: {:ok, params}

  defp match([":" <> name | pattern], [segment | rest], params),
    do: match(pattern, rest, Map.put(params, name, segment))

  defp match([segment | pattern], [segment | rest], params), do: match(pattern, rest, params)
  defp match(_pattern, _segments, _params), do: :error

  defp parse_query([]), do: %{}

  defp parse_query([query]) do
    query
    |> String.split("&", trim: true)
    |> Map.new(fn pair ->
      case String.split(pair, "=", parts: 2) do
        [key, value] -> {key, value}
        [key] -> {key, ""}
      end
    end)
  end

  # Callbacks a view doesn't define get LiveView's own default: no-op for events and messages.
  for {_name, view} <- @views do
    Code.ensure_compiled!(view)

    def mount(unquote(view), params, session, socket),
      do: unquote(view).mount(params, session, socket)

    def render(unquote(view), assigns), do: unquote(view).render(assigns)

    if function_exported?(view, :handle_event, 3) do
      def handle_event(unquote(view), name, params, socket),
        do: unquote(view).handle_event(name, params, socket)
    end

    if function_exported?(view, :handle_params, 3) do
      def handle_params(unquote(view), params, uri, socket),
        do: unquote(view).handle_params(params, uri, socket)
    end

    if function_exported?(view, :handle_info, 2) do
      def handle_info(unquote(view), message, socket),
        do: unquote(view).handle_info(message, socket)
    end
  end

  def handle_event(_view, _name, _params, socket), do: {:noreply, socket}
  def handle_info(_view, _message, socket), do: {:noreply, socket}
  def handle_params(_view, _params, _uri, socket), do: {:noreply, socket}
end
