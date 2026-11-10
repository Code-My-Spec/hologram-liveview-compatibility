# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :hologram_liveview_spike,
  ecto_repos: [HologramLiveviewSpike.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :hologram_liveview_spike, HologramLiveviewSpikeWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HologramLiveviewSpikeWeb.ErrorHTML, json: HologramLiveviewSpikeWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: HologramLiveviewSpike.PubSub,
  live_view: [signing_salt: "ULjPKLqw"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :hologram_liveview_spike, HologramLiveviewSpike.Mailer, adapter: Swoosh.Adapters.Local

# Modules whose functions only run on the server; in the browser their calls raise and the LiveView event
# is re-run on the server (see Holo.LvLocalPage). change_item is pure Ecto and stays client-side.
# LiveComponent modules: Phoenix calls their mount/update/render through a variable module, so each needs these edges.
# shortcut: listed by hand (and again in Holo.LvComponents); upgrade by generating both from `use Phoenix.LiveComponent`.
live_components = [HologramLiveviewSpikeWeb.CounterComponent]

component_edges =
  for component <- live_components,
      edge <- [
        {{Phoenix.LiveView.Utils, :maybe_call_live_component_mount!, 2}, {component, :mount, 1}},
        {{Phoenix.LiveView.Utils, :maybe_call_update!, 3}, {component, :update, 2}},
        {{Phoenix.LiveView.Renderer, :to_rendered, 2}, {component, :render, 1}},
        {{Phoenix.Component, :live_component, 1}, {component, :__live__, 0}}
      ],
      do: edge

config :hologram,
  server_only_modules: [
    {HologramLiveviewSpike.Catalog, except: [change_item: 1, change_item: 2]},
    HologramLiveviewSpike.Repo
  ],
  # Calls Hologram's static call graph can't see (the callee module is data at the call site).
  dynamic_dispatch_edges:
    [
      {{Phoenix.VerifiedRoutes, :static_path, 2},
       {HologramLiveviewSpikeWeb.Endpoint, :static_path, 1}},
      {{Phoenix.VerifiedRoutes, :guarded_unverified_path, 4},
       {HologramLiveviewSpikeWeb.Endpoint, :path, 1}},
      {{Phoenix.HTML.Safe.Phoenix.LiveView.JS, :to_iodata, 1}, {Jason, :encode!, 1}}
    ] ++ component_edges,
  client_module_overrides: [
    {HologramLiveviewSpikeWeb.Endpoint, HologramLiveviewSpikeWeb.Holo.EndpointClient},
    {Jason, HologramLiveviewSpikeWeb.Holo.JasonClient},
    {Gettext, HologramLiveviewSpikeWeb.Holo.GettextClient}
  ]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  hologram_liveview_spike: [
    args:
      ~w(js/app.js js/local_lv.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  hologram_liveview_spike: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
