defmodule HologramLiveviewSpikeWeb.HealthController do
  @moduledoc """
  Liveness endpoint for the deploy proxy.

  The proxy gates the traffic swap on this response, so it does the least
  possible work: no session, no authentication, and no database round-trip.
  A health check that queries the database reports the app as down whenever
  the database is briefly unavailable — and takes the app out of rotation at
  exactly the moment it is most needed.
  """

  use HologramLiveviewSpikeWeb, :controller

  def show(conn, _params) do
    send_resp(conn, 200, "ok")
  end
end
