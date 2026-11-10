defmodule HologramLiveviewSpikeWeb.Holo.SignupLive do
  # An ordinary LiveView: form, changeset validation, a Repo insert. Runs in the browser;
  # "save" runs on the server because it calls Server.call/3.
  use Phoenix.LiveView
  alias HologramLiveviewSpikeWeb.Holo.{Server, Signup, Signups}

  def mount(_params, _session, socket) do
    # The unmodified Phoenix call: in the browser it is ported to record the topic for the server to bridge.
    Phoenix.PubSub.subscribe(HologramLiveviewSpike.PubSub, "signups")
    {:ok, socket |> assign(status: "idle", total: nil) |> assign_form(%{}, false)}
  end

  def handle_info({:signup, total}, socket), do: {:noreply, assign(socket, total: total)}

  def handle_event("validate", %{"signup" => params}, socket) do
    {:noreply, assign_form(socket, params, false)}
  end

  def handle_event("save", %{"signup" => params}, socket) do
    case Server.call(Signups, :insert, [params]) do
      {:ok, total} ->
        {:noreply,
         socket
         |> assign(status: "Saved. #{total} signups in the database.")
         |> assign_form(%{}, false)}

      {:error, errors} ->
        {:noreply,
         socket |> assign(status: "fix the errors above") |> assign_form(params, true, errors)}
    end
  end

  # Live validation only flags fields the user has typed in; a submit flags everything.
  defp assign_form(socket, params, all?, errors \\ nil) do
    errors = errors || Signup.errors(Signup.changeset(params))

    shown =
      errors
      |> Enum.filter(fn {field, _} ->
        all? or Map.get(params, Atom.to_string(field), "") != ""
      end)
      |> Enum.map(fn {field, msg} -> {field, {msg, []}} end)

    assign(socket, form: to_form(params, as: :signup, errors: shown))
  end

  def field(assigns) do
    ~H"""
    <div class="flex flex-col gap-1">
      <label for={@field.id} class="text-sm font-medium">{@label}</label>
      <input
        id={@field.id}
        name={@field.name}
        value={@field.value}
        class="rounded-lg border border-slate-300 px-3 py-2"
      />
      <p :for={{msg, _} <- @field.errors} class="text-sm text-rose-600">{msg}</p>
    </div>
    """
  end

  def render(assigns) do
    # shortcut: plain <form>, not <.form>, which pulls in CSRF token generation; upgrade by porting or stubbing Plug.CSRFProtection.
    ~H"""
    <form id="signup-live" phx-change="validate" phx-submit="save" class="flex flex-col gap-4">
      <h1 class="text-2xl font-semibold">Sign up (LiveView)</h1>
      <.field field={@form[:name]} label="Name" />
      <.field field={@form[:email]} label="Email" />
      <button type="submit" class="rounded-lg bg-slate-900 px-4 py-2 text-white">Create account</button>
      <p id="lv-status">{@status}</p>
      <p id="lv-total" class="text-sm text-slate-500">{if @total, do: "#{@total} signups so far"}</p>
    </form>
    """
  end
end
