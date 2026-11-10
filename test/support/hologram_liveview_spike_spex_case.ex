defmodule HologramLiveviewSpikeSpex.Case do
  @moduledoc """
  Base case for spex (BDD spec) tests.

  Wires up Phoenix.ConnTest for HTTP assertions, Phoenix.LiveViewTest
  for driving LiveViews, the SexySpex DSL (spex/scenario/given_/when_/then_),
  and the DB sandbox.
  """
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      @endpoint HologramLiveviewSpikeWeb.Endpoint

      use HologramLiveviewSpikeWeb, :verified_routes
      use SexySpex

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import HologramLiveviewSpikeSpex.Case
    end
  end

  # Owns the sandbox directly rather than borrowing
  # `HologramLiveviewSpikeTest.DataCase.setup_sandbox/1`: spex are a separate
  # boundary from test support, and reaching into DataCase would force
  # HologramLiveviewSpikeSpex to depend on HologramLiveviewSpikeTest for one
  # function.
  setup tags do
    pid = Sandbox.start_owner!(HologramLiveviewSpike.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
