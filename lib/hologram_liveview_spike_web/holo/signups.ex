defmodule HologramLiveviewSpikeWeb.Holo.Signups do
  # Server-only. Never referenced statically from browser code.
  alias HologramLiveviewSpike.Repo
  alias HologramLiveviewSpikeWeb.Holo.Signup

  def insert(%{"name" => name, "email" => email} = params) do
    changeset = Signup.changeset(params)

    if changeset.valid? do
      Repo.query!(
        "insert into signups (name, email, inserted_at, updated_at) values ($1, $2, now(), now())",
        [name, email]
      )

      %{rows: [[total]]} = Repo.query!("select count(*)::int from signups")
      Phoenix.PubSub.broadcast(HologramLiveviewSpike.PubSub, "signups", {:signup, total})
      {:ok, total}
    else
      {:error, Signup.errors(changeset)}
    end
  end
end
