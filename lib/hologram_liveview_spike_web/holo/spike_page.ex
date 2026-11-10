defmodule HologramLiveviewSpikeWeb.Holo.SpikePage do
  use Hologram.Page

  route "/spike"
  layout HologramLiveviewSpikeWeb.Holo.Layout

  def init(_params, component, _server), do: put_state(component, status: "idle", now: nil)

  def template do
    ~HOLO"""
    <p id="status">{@status}</p>
    <p id="now">{@now}</p>
    <button id="load" $click="load">Load</button>
    """
  end

  # Browser side (transpiled): no side effects, just hand off to the server.
  def action(:load, _params, component) do
    component |> put_state(:status, "loading") |> put_command(:fetch_now)
  end

  def action(:loaded, %{now: now}, component) do
    put_state(component, status: "done", now: now)
  end

  # Server side: real Ecto, then message back to the browser.
  def command(:fetch_now, _params, server) do
    %{rows: [[now]]} = HologramLiveviewSpike.Repo.query!("select now()::text")
    put_action(server, :loaded, now: now)
  end
end
