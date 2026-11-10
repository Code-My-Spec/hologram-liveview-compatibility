defmodule HologramLiveviewSpikeWeb.CounterComponent do
  # A stateful LiveComponent: its own mount/update/handle_event, targeted with phx-target={@myself}.
  use HologramLiveviewSpikeWeb, :live_component

  @impl true
  def mount(socket), do: {:ok, assign(socket, count: 0)}

  @impl true
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @impl true
  def handle_event("inc", %{"by" => by}, socket) do
    {:noreply, update(socket, :count, &(&1 + String.to_integer(by)))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex items-center gap-3 py-1">
      <span id={"#{@id}-label"}>{@label}: {@count}</span>
      <button
        id={"#{@id}-inc"}
        phx-click="inc"
        phx-value-by="1"
        phx-target={@myself}
        class="btn btn-sm"
      >
        +1
      </button>
    </div>
    """
  end
end
