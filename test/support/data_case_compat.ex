defmodule HologramLiveviewSpike.DataCase do
  @moduledoc """
  Compatibility shim: Phoenix generators emit `use HologramLiveviewSpike.DataCase`.
  The real case module is `HologramLiveviewSpikeTest.DataCase` — forward to it.

  See `HologramLiveviewSpikeWeb.ConnCase` for the rationale.
  """
  defmacro __using__(opts) do
    quote do
      use HologramLiveviewSpikeTest.DataCase, unquote(opts)
    end
  end
end
