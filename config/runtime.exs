import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/hologram_liveview_spike start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :hologram_liveview_spike, HologramLiveviewSpikeWeb.Endpoint, server: true
end

# The port, for every environment — deliberately outside the `:prod` guard
# below. A workspace container is handed its port through the environment and
# has no opportunity to edit config, so this has to be the one place that
# decides it.
#
# The default is 4100, not Phoenix's 4000, because a generated app is not the
# only thing on the machine that generated it. CodeMySpec's own dev server runs
# on 4000, and an app generated to be worked on beside it collided by
# construction: `mix phx.server` in a fresh app either failed with `:eaddrinuse`
# on a port it never configured, or took the platform's port and stopped every
# other agent's hooks and analysis runs. That happened three times in one hour
# on this machine before anyone worked out which process was which — the app
# reports a port it cannot find in its own dev.exs, and the server reports a
# clean shutdown that reads as somebody restarting it on purpose.
#
# `PORT` still wins, so containers and platforms are unaffected.
#
# Worth stating where somebody will hit it: setting a port in `config/dev.exs`
# does nothing, because this runs afterwards and overrides it. Use
# `PORT=4321 mix phx.server`.
config :hologram_liveview_spike, HologramLiveviewSpikeWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4100"))]

# A working copy's harness tells the app it launches its own preview hostname
# at boot (`PHX_HOST`), the same variable the `:prod` block below already
# reads. Without this, `Endpoint.url()` only ever learns a real host in
# `:prod`, so a link this app generates outside of a request's own Host
# header — a login email, for instance — fell back to whatever host was
# last hardcoded or defaulted here instead of the address a browser could
# actually reach. Port and scheme are forced to the tunnel's own
# (443/https), not the local dev listener's — the address this resolves to
# is only ever reached through Cloudflare's edge, never directly against
# PORT. A no-op when PHX_HOST isn't set, which is every checkout the harness
# isn't holding a tunnel for.
if preview_host = System.get_env("PHX_HOST") do
  config :hologram_liveview_spike, HologramLiveviewSpikeWeb.Endpoint,
    url: [host: preview_host, port: 443, scheme: "https"]
end

# Where this app's preview answers, for `ClientUtils.PreviewFraming` — the
# tunnel that actually carries the preview is the harness's, not this app's;
# see its own supervisor. This app only needs to know the embedder to allow
# framing from.
#
# Read at boot rather than handed to the app by whoever started it, so a preview
# provisioned after the app was first run is picked up by restarting it and
# nothing else.
#
# Two sources, because there are two ways this app runs. On a developer's
# machine the values are in the checkout; in a container there is no checkout at
# all, so they arrive as CMS_PREVIEW_* variables. `config/2` reads whichever
# applies.
#
# Empty when neither says anything, which leaves the framing plug a no-op —
# the ordinary state for an app nobody has previewed yet.
config :hologram_liveview_spike,
       :preview,
       ClientUtils.Harness.Preview.config(File.cwd!(),
         origin_url: "http://127.0.0.1:#{System.get_env("PORT", "4100")}"
       )

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :hologram_liveview_spike, HologramLiveviewSpike.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :hologram_liveview_spike, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :hologram_liveview_spike, HologramLiveviewSpikeWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base,
    # The deploy proxy terminates TLS and probes the app port directly over
    # plain HTTP, with no X-Forwarded-Proto header. Without excluding the
    # health path, force_ssl answers that probe with a 301, the proxy reads
    # the redirect as an unhealthy container, and the traffic swap never
    # completes — a deploy that fails for a reason unrelated to the app.
    # Keyword form, because that is the only one Plug.SSL reads: a flat list of
    # strings is not `[hosts: ...]`, `[paths: ...]` or `[conn: ...]`, so it
    # excludes nothing and the probe still gets its 301. Identical to
    # config/prod.exs, and it has to be — Phoenix marks `:force_ssl`
    # compile-time, so a runtime value that differs aborts the boot.
    force_ssl: [
      rewrite_on: [:x_forwarded_proto],
      exclude: [paths: ["/health"], hosts: ["localhost", "127.0.0.1"]]
    ]

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :hologram_liveview_spike, HologramLiveviewSpikeWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :hologram_liveview_spike, HologramLiveviewSpikeWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :hologram_liveview_spike, HologramLiveviewSpike.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://swoosh.hexdocs.pm/Swoosh.html#module-installation for details.
end

# The Resend inbound-mail webhook's Svix signing secret. Read at runtime, and
# unconditionally rather than only under `:prod`, so dev/test simply see
# `nil` and `ResendWebhookController` skips verification instead of raising.
# Unset until inbound mail setup mints one and writes it to the encrypted
# env — the controller degrades gracefully until then.
config :hologram_liveview_spike, :resend_webhook_secret, System.get_env("RESEND_WEBHOOK_SECRET")
