# List available recipes
default:
    @just --list

# Prepare a freshly generated or connected checkout for local development.
# The generated Mix alias handles dependencies, database, and configured assets.
dev-setup:
    env MIX_ENV=dev mix setup

# The CodeMySpec gate runs its exunit lane through this recipe, passing the
# files and options it would have given `mix test`; change how the suite runs
# here, and keep passing the arguments through.
# Run tests
[positional-arguments]
test *args:
    mix test "$@"

# The CodeMySpec gate runs its spex lane through this recipe, with the files it
# wants run and `--jsonl=<path>`, where it reads the failures back. Change how
# the suite runs here (shard it, say), and keep both reaching `mix spex`.
# Run spex
[positional-arguments]
spex *args:
    mix spex "$@"

# Make a working copy of this project, adjacent to this checkout.
#
# The CodeMySpec harness calls this instead of running `git worktree add`
# itself. What a fresh copy of *this* project needs is this project's business —
# the harness serves every project and cannot know it — so put anything a new
# copy requires here: fixtures to link, files to write, services to prepare.
#
# Submodules are why this recipe exists at all. `git worktree add` does not
# populate them and nothing downstream notices: the harness scans the copy and
# computes the requirement graph from what it finds, so an unpopulated submodule
# does not read as a missing checkout — it reads as a project with no specs and
# no architecture, and the agent is told to redo work that already exists.
#
# Adjacent to the checkout rather than inside `.claude/`: a working copy is a
# peer of the checkout it came from, not disposable editor state.
init-worktree name target:
    #!/usr/bin/env bash
    set -euo pipefail

    # The main checkout owns the worktree list, and this may be invoked from a
    # worktree — `--git-common-dir` resolves there from either.
    main="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"

    echo "→ worktree: {{target}}"
    git -C "$main" worktree add -b "{{name}}" "{{target}}"

    if [ -f "{{target}}/.gitmodules" ]; then
      echo "→ submodules"
      git -C "{{target}}" submodule update --init --recursive
    fi

    # Dev/test secrets, committed sops-encrypted. The CodeMySpec harness puts
    # the project's age key in the machine's sops keyring when it serves it.
    for e in dev test; do
      if [ -f "envs/$e.enc.env" ]; then
        echo "→ .env.$e"
        sops -d --input-type dotenv --output-type dotenv "envs/$e.enc.env" > "{{target}}/.env.$e"
      fi
    done

    echo "→ deps"
    cd "{{target}}" && elixir -S mix deps.get

# Bring this working copy's own app up on its own port and database — story
# 1108. The harness (`CmsHarness.AppInstance`) runs exactly this, once per
# copy, with `PORT` and `DATABASE_NAME` (and, when relevant, `CMS_MAIN_COPY` /
# `CMS_TUNNEL_HELD_BY_HARNESS`) already set as environment variables rather
# than passed as arguments, so `config/dev.exs` and `config/runtime.exs` read
# them the same way whether this ran under the harness or by hand.
#
# `mix loadpaths` is the cheap check: it fails on a checkout with no `deps/`
# or a `_build` from a different Elixir/OTP, and both need
# `deps.get`/`deps.compile` before anything else here can run. A fresh
# working copy does not inherit a compiled `deps/` from the checkout it came
# from — `init-worktree` above copies `mix.lock`, not the compiled tree.
#
# `assets.setup` runs only when `assets/package.json` exists and
# `assets/node_modules` does not — most generated apps have no npm
# dependencies at all, and re-running it on every start would cost real time
# for nothing. Missing it silently is the actual defect this guards against:
# a copy can come up "serving" (the port answers) with every JS hook dead and
# nothing anywhere saying so.
serve:
    #!/usr/bin/env bash
    set -euo pipefail

    : "${PORT:?PORT must be set}"
    : "${DATABASE_NAME:?DATABASE_NAME must be set}"

    if ! MIX_ENV=dev mix loadpaths > /dev/null 2>&1; then
      MIX_ENV=dev mix deps.get
      MIX_ENV=dev mix deps.compile
    fi

    if [ -f assets/package.json ] && [ ! -d assets/node_modules ]; then
      MIX_ENV=dev mix assets.setup
    fi

    MIX_ENV=dev mix ecto.create
    MIX_ENV=dev mix ecto.migrate
    exec env MIX_ENV=dev elixir -S mix phx.server

# Bring the application back up on the code that is now checked out.
#
# A promotion runs exactly this, from the checkout it merged into, and reads the
# exit status: non-zero means the promotion failed and nothing is served. A
# project with no `restart` cannot be promoted at all — the gate refuses with
# "there is no `just restart` to bring the application back up".
#
# **Adapt the last step to how this app actually runs.** The build steps below
# are right for every project; the restart is not, because nothing here knows
# whether you run under systemd, a release, Docker, or `iex -S mix phx.server`
# in a terminal. Leaving it as an echo means a promotion reports success while
# the old code keeps serving — which is worse than failing, because the caller
# is told to go and QA a build that was never deployed.
restart:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "→ deps"
    elixir -S mix deps.get

    echo "→ compile"
    MIX_ENV=dev elixir -S mix compile

    echo "→ migrate"
    MIX_ENV=dev elixir -S mix ecto.migrate

    echo
    echo "TODO: restart HologramLiveviewSpike here — see the note above this recipe." >&2
    echo "Until then a promotion reports success without deploying anything." >&2
