defmodule HologramLiveviewSpikeWeb.Holo.Signup do
  @moduledoc "Pure validation: runs transpiled in the browser (live) and natively on the server (authoritative)."
  import Ecto.Changeset

  def changeset(params) do
    {%{}, %{name: :string, email: :string}}
    |> cast(params, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_length(:name, min: 2)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+$/, message: "must look like an email")
  end

  # %{field => first message}
  # shortcut: English only, %{key} interpolation without Gettext (not bundled); upgrade by translating server-side
  def errors(%Ecto.Changeset{errors: errors}) do
    Enum.reduce(errors, %{}, fn {field, {msg, opts}}, acc ->
      Map.put_new(
        acc,
        field,
        Enum.reduce(opts, msg, fn {k, v}, m -> String.replace(m, "%{#{k}}", to_string(v)) end)
      )
    end)
  end
end
