defmodule HologramLiveviewSpike.MixProject do
  use Mix.Project

  def project do
    [
      app: :hologram_liveview_spike,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: compilers(Mix.env()),
      spex: [pattern: "test/spex/**/*_spex.exs", boundary: HologramLiveviewSpikeSpex],
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # The Application module lives in the WEB namespace: it supervises both
  # the Repo and the Endpoint, so keeping it under HologramLiveviewSpike would
  # make the core namespace depend on the web one and violate the boundary.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {HologramLiveviewSpikeWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test, spex: :test, agent_test: :test]
    ]
  end

  # The :spex compiler only runs in :test — it compiles the BDD spec files
  # under test/spex, which do not exist in any other environment.
  # The LiveView compiler is listed only when this project has the HTML
  # stack; under --no-html that dep is absent and it cannot resolve.
  defp compilers(:test),
    do: [:boundary, :diagnostics, :phoenix_live_view, :erlang, :elixir, :spex, :app, :hologram]

  defp compilers(_),
    do: [:boundary, :diagnostics, :phoenix_live_view, :erlang, :elixir, :app, :hologram]

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.10"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0-rc.3"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.9"},
      {:hologram, path: "vendor/hologram"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.3"},
      {:bandit, "~> 1.5"},

      # CodeMySpec harness. `:boundary` and `:client_utils` supply the
      # `:boundary` and `:diagnostics` compilers declared in compilers/1,
      # so they are runtime-visible in every environment, not dev-only.
      #
      # `>= 0.0.0` on client_utils: whatever is newest when this project is
      # generated. Not laziness — a version pinned in a generator template is a
      # number nobody looks at again, and this one went stale in a way that
      # mattered. It said `~> 0.1.19` while hex sat at 0.1.28 and two fixes a
      # generated app needs waited on the master branch: `ANTHROPIC_BASE_URL`
      # becoming opt-in (carrying it points every model turn at a proxy that
      # only understands `/v1/messages`, silently breaking every other Anthropic
      # surface Claude Code needs), and `mix harness.onboard` no longer stamping
      # `"project_id" => nil` over a `.cms_harness.json` a host had filled in.
      #
      # `mix.lock` still pins the moment it resolves, so this means "newest at
      # generation", plus whenever someone runs `mix deps.update client_utils`.
      # No requirement can mean more than that — the lock exists to stop a build
      # changing under you.
      #
      # The trade, stated: a future breaking release is taken without anyone
      # deciding to. That is accepted because this library and this generator
      # ship together, and a generated project tracking the harness it was made
      # for is the point. Pin it if that ever stops being true.
      {:boundary, "~> 0.12"},
      {:client_utils, ">= 0.0.0"},
      {:credo, "~> 1.7.13", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.18", only: [:dev, :test], runtime: false},
      {:sexy_spex, "~> 0.2", only: [:dev, :test]},
      # For the support widget's client, which `cms_gen.support_widget` writes
      # with `use Slipstream`. That generator only *prints* an instruction to
      # add this — the same shape as the Scope edit that used to be printed
      # too — so a project that ran the standard generator chain and was then
      # built failed inside the container with
      #
      #   ** (CompileError) cannot compile module <App>.CodeMySpec.WidgetClient
      #       expanding macro: Kernel.use/1
      #
      # It belongs in the generator, which should add what its own output
      # needs. Here until that ships, because every generated project runs
      # that generator.
      {:slipstream, "~> 1.1"},
      # `~> 0.2`, not `~> 0.1.0`. 0.2.0 is the release where the generators
      # apply the two edits they previously only *printed* instructions for —
      # without it `cms_gen.accounts` leaves `Users.Scope` without
      # `active_account_id`, the accounts module it just wrote references that
      # field, and the generated project does not compile:
      #
      #   ** (KeyError) key :active_account_id not found
      #       expanding struct: <App>.Users.Scope.__struct__/1
      #
      # `~> 0.1.0` means `< 0.2.0`, so it could never have resolved the fix
      # however long it sat on hex.
      {:code_my_spec_generators, "~> 0.2", only: :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      spex: ["ecto.create --quiet", "ecto.migrate --quiet", "spex"],
      "assets.setup": [
        &npm_install/1,
        "tailwind.install --if-missing",
        "esbuild.install --if-missing"
      ],
      "assets.build": [
        "compile",
        "tailwind hologram_liveview_spike",
        "esbuild hologram_liveview_spike"
      ],
      "assets.deploy": [
        "tailwind hologram_liveview_spike --minify",
        "esbuild hologram_liveview_spike --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  # `tailwind.install`/`esbuild.install` fetch their own standalone binaries
  # and were chosen specifically so a generated app never needs Node — most
  # never gain an `assets/package.json` at all. But one that does (a JS
  # library added later that only ships via npm) needs its dependencies
  # installed too, or every hook silently never loads: nothing about a
  # missing `node_modules` fails the build or the boot, an asset bundler just
  # resolves a bare import to nothing and every `phx-click` bound to it goes
  # inert with no error anywhere.
  #
  # Conditional, not unconditional: an unconditional `npm install` would put
  # a Node/npm requirement on every generated app, defeating the reason
  # `tailwind.install`/`esbuild.install` exist. This runs only when
  # `assets/package.json` says there is something for npm to install.
  defp npm_install(args) do
    if File.exists?(Path.join("assets", "package.json")) do
      Mix.shell().info("==> npm install (assets/package.json)")
      {_, 0} = System.cmd("npm", ["install"], cd: "assets", into: IO.stream())
    end

    args
  end
end
