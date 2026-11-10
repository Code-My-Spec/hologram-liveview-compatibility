import Config

# Configure your database
#
# MIX_TEST_PARTITION gives built-in test partitioning in CI — run
# `mix help test` for more. Unset, it defaults to one database per
# checkout, so two checkouts cannot re-schema each other.
#
# A linked git worktree shares this machine's database server. Running the
# suite in one migrates the database every other checkout is using, from
# whatever branch that one happens to be on. The symptoms never name the
# cause: undefined modules first, then NOT NULL violations on columns the
# code has never heard of, as the schema shifts under successive runs.
#
# In a linked worktree `.git` is a file pointing at the real git dir rather
# than a directory. That is the whole test. The primary checkout keeps the
# bare name.
#
# These databases are disposable and nothing sweeps them: `mix ecto.drop`
# in a worktree you are finished with.
#
# The recorded name wins over everything except the analyzer's own
# sub-partition. `mix cms.harness.onboard` writes it into
# `.claude/settings.local.json`, and that file is the answer — read here
# rather than taken from the environment, because the variable only
# reaches a process Claude Code exported it into. Anything else that
# runs the suite (an analyzer, a script, a shell you opened yourself) got
# a different database from the same checkout, and the two disagreed
# about the schema without either of them being wrong.
#
# Read as text rather than through a library: config runs before deps are
# loaded, so there is nothing to call yet.
recorded_partition =
  with {:ok, contents} <-
         File.read(Path.join(File.cwd!(), ".claude/settings.local.json")),
       [_, value] <-
         Regex.run(~r/"MIX_TEST_PARTITION"\s*:\s*"([^"]+)"/, contents) do
    value
  else
    _ -> nil
  end

requested_partition = System.get_env("MIX_TEST_PARTITION")

# The one environment value allowed to win over the recorded one. A
# harness analyzer gives its exunit and spex sweeps their own database by
# appending a letter to this copy's own recorded partition (an "a" for
# exunit, an "s" for spex), and MIX_TEST_PARTITION is the only channel it
# has to say so. Recorded-first, full stop, silently drops that suffix
# and collapses both sweeps and an interactive mix test onto one
# database — a sweep truncating under the suite still using it.
#
# Narrow on purpose: not "an environment value" but "the recorded value
# plus one suffix" — a name that can only describe *this* working copy.
# A value inherited from another worktree cannot match, and still loses.
own_sub_partition? =
  is_binary(recorded_partition) and is_binary(requested_partition) and
    requested_partition in [recorded_partition <> "a", recorded_partition <> "s"]

partition =
  cond do
    own_sub_partition? ->
      requested_partition

    recorded_partition ->
      recorded_partition

    requested_partition ->
      requested_partition

    File.regular?(Path.join(File.cwd!(), ".git")) ->
      "_" <> Path.basename(File.cwd!())

    true ->
      ""
  end

config :hologram_liveview_spike, HologramLiveviewSpike.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hologram_liveview_spike_test#{partition}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :hologram_liveview_spike, HologramLiveviewSpikeWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "fpDRklpDBYoj+A5CBQfTjO9wAxaMGfv3ZNe7k97H2eMjNYBI52O+n1Ldv4rkFuUF",
  server: false

# In test we don't send emails
config :hologram_liveview_spike, HologramLiveviewSpike.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
