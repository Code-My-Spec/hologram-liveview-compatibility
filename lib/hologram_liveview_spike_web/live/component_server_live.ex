defmodule HologramLiveviewSpikeWeb.ComponentServerLive do
  # Same as ComponentLive, but mount reads the database, so it mounts on the server and its components must survive the
  # trip to the browser.
  use HologramLiveviewSpikeWeb, :live_view

  alias HologramLiveviewSpike.Catalog
  alias HologramLiveviewSpikeWeb.CounterComponent

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, item_count: length(Catalog.list_items()))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <p id="item-count">{@item_count} items</p>
      <.live_component module={CounterComponent} id="counter-a" label="Server-mounted" />
    </Layouts.app>
    """
  end
end
