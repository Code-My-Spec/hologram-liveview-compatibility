defmodule HologramLiveviewSpikeWeb.Holo.JasonClient do
  @moduledoc "Browser-side stand-in for `Jason` (see `client_module_overrides` in config.exs)."
  alias HologramLiveviewSpikeWeb.Holo.LvJson

  # shortcut: only encode!/1, via LvJson (maps, lists, binaries, ints, atoms); no structs, floats or encode options.
  def encode!(term), do: LvJson.enc(term)
end
