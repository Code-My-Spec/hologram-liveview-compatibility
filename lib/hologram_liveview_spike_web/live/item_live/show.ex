defmodule HologramLiveviewSpikeWeb.ItemLive.Show do
  use HologramLiveviewSpikeWeb, :live_view

  alias HologramLiveviewSpike.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Item {@item.id}
        <:subtitle>This is a item record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/items"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/items/#{@item}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit item
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@item.name}</:item>
        <:item title="Qty">{@item.qty}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Item")
     |> assign(:item, Catalog.get_item!(id))}
  end
end
