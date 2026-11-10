defmodule HologramLiveviewSpike.Release do
  @moduledoc """
  Tasks that run inside the release, where Mix is not available.

  `bin/migrate` — the release overlay the deploy runs before it moves traffic —
  calls `migrate/0` here. Without this module the deploy reaches the migration
  container and dies with

      ** (UndefinedFunctionError) function HologramLiveviewSpike.Release.migrate/0
      is undefined (module HologramLiveviewSpike.Release is not available)

  which the deploy reports as "Migration failed (exit 1) — the previous version
  is still serving", naming neither the module nor the missing file.

  `load/0` rather than `ensure_all_started/1`: the repo is started by hand, one
  at a time, so a migration never races the application's own supervision tree.
  """

  @app :hologram_liveview_spike

  @doc """
  Run every pending migration for every repo, reporting a first deploy.

  The deploy skips its pre-swap health check on a first deploy, because that
  check probes the version *already serving* and a new site has none. It used
  to learn this from `bin/migrate` **failing** with "env/roles/*.env: no such
  file or directory" — the only signal there was. Once migrate started
  decrypting secrets baked into the image it no longer needed env files on the
  host, so it succeeds on a first deploy, the marker never printed, and every
  new site health-checked a host serving nothing and timed out.

  A database with no migrations applied is the positive form of the same fact,
  and unlike a failure string it is something this module can observe. Printed
  on stdout, which the deploy script already captures and echoes to the caller.
  """
  def migrate do
    load_app()

    first_deploy? =
      repos()
      |> Enum.map(fn repo ->
        {:ok, untouched?, _} =
          Ecto.Migrator.with_repo(repo, fn repo ->
            untouched? = Ecto.Migrator.migrated_versions(repo) == []
            Ecto.Migrator.run(repo, :up, all: true)
            untouched?
          end)

        untouched?
      end)
      |> Enum.all?()

    # Machine-readable, like `migrated=` and `swapped=` in bin/deploy.
    if first_deploy?, do: IO.puts("first_deploy=1")
  end

  @doc "Roll `repo` back to `version`."
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
