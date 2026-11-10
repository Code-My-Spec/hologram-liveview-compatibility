defmodule HologramLiveviewSpike.Repo do
  use Ecto.Repo,
    otp_app: :hologram_liveview_spike,
    adapter: Ecto.Adapters.Postgres
end
