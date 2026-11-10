defmodule HologramLiveviewSpikeWeb.Holo.SignupPage do
  use Hologram.Page
  alias HologramLiveviewSpikeWeb.Holo.Signup

  route "/signup"
  layout HologramLiveviewSpikeWeb.Holo.Layout

  def init(_params, component, server) do
    component =
      put_state(component,
        name_error: nil,
        email_error: nil,
        name_invalid: "false",
        email_invalid: "false",
        status: "idle",
        total: nil
      )

    {component, put_subscription(server, :signups)}
  end

  def template do
    ~HOLO"""
    <div class="rounded-2xl bg-white p-8 shadow-sm ring-1 ring-slate-200">
      <h1 class="text-2xl font-semibold tracking-tight">Sign up</h1>
      <p class="mt-1 text-sm text-slate-500">
        Validated in your browser by transpiled Ecto, saved by the server.
      </p>

      <form id="signup-form" class="mt-6 space-y-5" $change="validate" $submit="submit">
        <div>
          <label for="name" class="block text-sm font-medium text-slate-700">Name</label>
          <input id="name" name="name" type="text" autocomplete="off" aria-invalid={@name_invalid}
            class="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm shadow-sm outline-none transition focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 aria-invalid:border-rose-500 aria-invalid:ring-2 aria-invalid:ring-rose-100" />
          {%if @name_error}
            <p id="name-error" class="mt-1 text-sm text-rose-600">{@name_error}</p>
          {/if}
        </div>

        <div>
          <label for="email" class="block text-sm font-medium text-slate-700">Email</label>
          <input id="email" name="email" type="text" autocomplete="off" aria-invalid={@email_invalid}
            class="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-sm shadow-sm outline-none transition focus:border-indigo-500 focus:ring-2 focus:ring-indigo-200 aria-invalid:border-rose-500 aria-invalid:ring-2 aria-invalid:ring-rose-100" />
          {%if @email_error}
            <p id="email-error" class="mt-1 text-sm text-rose-600">{@email_error}</p>
          {/if}
        </div>

        <button id="submit" type="submit"
          class="inline-flex w-full items-center justify-center rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 active:scale-[0.99]">
          Create account
        </button>
      </form>

      <p id="status" class="mt-4 text-center text-sm text-slate-500">{@status}</p>
      {%if @total}
        <p id="total" class="mt-1 text-center text-sm font-medium text-emerald-600">Saved. {@total} signups in the database.</p>
      {/if}
    </div>
    """
  end

  # Live validation in the browser; only complain about fields the user has typed in.
  def action(:validate, %{event: event}, component) do
    errors = event |> Signup.changeset() |> Signup.errors()

    visible =
      for {k, v} <- errors, event[Atom.to_string(k)] not in [nil, ""], into: %{}, do: {k, v}

    put_errors(component, visible)
  end

  def action(:submit, %{event: event}, component) do
    changeset = Signup.changeset(event)

    if changeset.valid? do
      component
      |> put_errors(%{})
      |> put_state(:status, "saving…")
      |> put_command(:save, name: event["name"], email: event["email"])
    else
      component
      |> put_errors(Signup.errors(changeset))
      |> put_state(:status, "fix the errors above")
    end
  end

  def action(:saved, %{total: total}, component) do
    component |> put_state(:status, "done") |> put_state(:total, total)
  end

  # Pushed by the server to every subscribed browser, including other tabs.
  def action(:total, %{total: total}, component), do: put_state(component, :total, total)

  def action(:rejected, %{errors: errors}, component) do
    component |> put_errors(errors) |> put_state(:status, "rejected by server")
  end

  # Server re-validates (never trust the browser), then inserts.
  def command(:save, %{name: name, email: email}, server) do
    changeset = Signup.changeset(%{"name" => name, "email" => email})

    if changeset.valid? do
      alias HologramLiveviewSpike.Repo

      Repo.query!(
        "insert into signups (name, email, inserted_at, updated_at) values ($1, $2, now(), now())",
        [name, email]
      )

      %{rows: [[total]]} = Repo.query!("select count(*) from signups")
      server |> put_action(:saved, total: total) |> put_broadcast(:signups, :total, total: total)
    else
      put_action(server, :rejected, errors: Signup.errors(changeset))
    end
  end

  defp put_errors(component, errors) do
    put_state(component,
      name_error: errors[:name],
      email_error: errors[:email],
      name_invalid: if(errors[:name], do: "true", else: "false"),
      email_invalid: if(errors[:email], do: "true", else: "false")
    )
  end
end
