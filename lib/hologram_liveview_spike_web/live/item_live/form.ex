defmodule HologramLiveviewSpikeWeb.ItemLive.Form do
  use HologramLiveviewSpikeWeb, :live_view

  alias HologramLiveviewSpike.Catalog
  alias HologramLiveviewSpike.Catalog.Item

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage item records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="item-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:qty]} type="number" label="Qty" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Item</.button>
          <.button navigate={return_path(@return_to, @item)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    item = Catalog.get_item!(id)

    socket
    |> assign(:page_title, "Edit Item")
    |> assign(:item, item)
    |> assign(:form, to_form(Catalog.change_item(item)))
  end

  defp apply_action(socket, :new, _params) do
    item = %Item{}

    socket
    |> assign(:page_title, "New Item")
    |> assign(:item, item)
    |> assign(:form, to_form(Catalog.change_item(item)))
  end

  @impl true
  def handle_event("validate", %{"item" => item_params}, socket) do
    changeset = Catalog.change_item(socket.assigns.item, item_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"item" => item_params}, socket) do
    save_item(socket, socket.assigns.live_action, item_params)
  end

  defp save_item(socket, :edit, item_params) do
    case Catalog.update_item(socket.assigns.item, item_params) do
      {:ok, item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Item updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, item))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_item(socket, :new, item_params) do
    case Catalog.create_item(item_params) do
      {:ok, item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Item created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, item))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _item), do: ~p"/items"
  defp return_path("show", item), do: ~p"/items/#{item}"
end
