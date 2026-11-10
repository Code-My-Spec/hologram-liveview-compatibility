defmodule HologramLiveviewSpikeWeb.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  #
  # This module lives in the WEB namespace, not HologramLiveviewSpike. It
  # supervises both the Repo and the Endpoint, so hosting it under
  # HologramLiveviewSpike would make the core namespace depend on the web one
  # and violate the boundary declared in lib/hologram_liveview_spike.ex.
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # shortcut: Hologram's deserializer only accepts atoms that already exist, and dev mode loads modules lazily, so a struct
    # from a not-yet-loaded module (Ecto.Changeset in a socket the browser sends back) fails to decode. Releases load everything.
    # Upgrade: have the deserializer load a struct's module first, or drop this once the app only runs as a release.
    for app <- [:ecto, :phoenix_ecto, :phoenix_html, :phoenix_live_view, :hologram_liveview_spike],
        module <- Application.spec(app, :modules) || [] do
      Code.ensure_loaded(module)
    end

    children = [
      HologramLiveviewSpikeWeb.Telemetry,
      HologramLiveviewSpike.Repo,
      {DNSCluster,
       query: Application.get_env(:hologram_liveview_spike, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: HologramLiveviewSpike.PubSub},
      HologramLiveviewSpike.LvStore,
      {Registry, keys: :unique, name: HologramLiveviewSpike.PubSubBridge.Registry},
      {DynamicSupervisor,
       name: HologramLiveviewSpike.PubSubBridge.Supervisor, strategy: :one_for_one},
      # Start a worker by calling: HologramLiveviewSpike.Worker.start_link(arg)
      # {HologramLiveviewSpike.Worker, arg},
      # Start to serve requests, typically the last entry
      HologramLiveviewSpikeWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HologramLiveviewSpikeWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HologramLiveviewSpikeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
