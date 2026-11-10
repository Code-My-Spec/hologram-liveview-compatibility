defmodule HologramLiveviewSpikeWeb.PageController do
  use HologramLiveviewSpikeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
