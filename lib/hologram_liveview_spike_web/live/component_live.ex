defmodule HologramLiveviewSpikeWeb.ComponentLive do
  # A LiveView that embeds two stateful LiveComponents and renames one from the parent, which re-runs its update/2.
  use HologramLiveviewSpikeWeb, :live_view

  alias HologramLiveviewSpikeWeb.CounterComponent

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, name_a: "Apples")}

  @impl true
  def handle_event("rename", _params, socket), do: {:noreply, assign(socket, name_a: "Pears")}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <button id="rename" phx-click="rename">Rename A</button>
      <.live_component module={CounterComponent} id="counter-a" label={@name_a} />
      <.live_component module={CounterComponent} id="counter-b" label="Bananas" />
    </Layouts.app>
    """
  end
end
