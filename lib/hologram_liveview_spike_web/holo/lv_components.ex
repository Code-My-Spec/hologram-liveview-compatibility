defmodule HologramLiveviewSpikeWeb.Holo.LvComponents do
  @moduledoc """
  Static dispatch to LiveComponent callbacks the runner calls itself (`handle_event/3`). The callbacks Phoenix calls
  (mount/1, update/2, render/1) are reached through `dynamic_dispatch_edges` in config/config.exs.
  """
  alias HologramLiveviewSpikeWeb.CounterComponent

  # shortcut: components are listed by hand here and again in config/config.exs (the edges); upgrade by generating both
  # from the modules that `use Phoenix.LiveComponent`.
  @components [CounterComponent]

  for component <- @components do
    Code.ensure_compiled!(component)

    if function_exported?(component, :handle_event, 3) do
      def handle_event(unquote(component), event, params, socket),
        do: unquote(component).handle_event(event, params, socket)
    end
  end
end
