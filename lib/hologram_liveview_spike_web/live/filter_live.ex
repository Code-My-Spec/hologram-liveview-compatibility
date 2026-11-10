defmodule HologramLiveviewSpikeWeb.FilterLive do
  # A LiveView that drives its state from the URL: handle_params reads ?q=, a form push_patches it,
  # and <.link patch> changes it. The list read is a server-only call made inside handle_params.
  use HologramLiveviewSpikeWeb, :live_view

  alias HologramLiveviewSpike.Catalog

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, q: "", items: [])}

  @impl true
  def handle_params(params, _uri, socket) do
    q = Map.get(params, "q", "")
    needle = String.downcase(q)
    items = Enum.filter(Catalog.list_items(), &String.contains?(String.downcase(&1.name), needle))
    {:noreply, assign(socket, q: q, items: items)}
  end

  @impl true
  def handle_event("filter", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: ~p"/items_filter?#{[q: q]}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <form id="filter-form" phx-change="filter">
        <input id="q" name="q" value={@q} placeholder="Filter items" />
      </form>
      <.link id="only-nav" patch={~p"/items_filter?q=Nav"}>Only "Nav"</.link>
      <.link id="clear" patch={~p"/items_filter"}>Clear</.link>
      <ul id="filtered">
        <li :for={item <- @items} id={"item-#{item.id}"}>{item.name} ({item.qty})</li>
      </ul>
    </Layouts.app>
    """
  end
end
