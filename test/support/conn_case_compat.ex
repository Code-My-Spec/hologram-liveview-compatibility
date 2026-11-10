defmodule HologramLiveviewSpikeWeb.ConnCase do
  @moduledoc """
  Compatibility shim: Phoenix generators emit `use HologramLiveviewSpikeWeb.ConnCase`.
  The real case module is `HologramLiveviewSpikeTest.ConnCase` — forward to it.

  `mix phx.gen.auth` / `phx.gen.live` / `phx.gen.html` hardcode the default
  case-module names in every test they emit; without this shim their output
  does not compile. Newly generated tests compile as-emitted — normalize them
  to the `HologramLiveviewSpikeTest.*` names whenever you next touch them.
  """
  defmacro __using__(opts) do
    quote do
      use HologramLiveviewSpikeTest.ConnCase, unquote(opts)
    end
  end
end
