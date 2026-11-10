defmodule HologramLiveviewSpikeTest do
  @moduledoc """
  Boundary for test support modules under `test/support/`.

  Case templates and fixtures may depend on the application core; the web
  layer is deliberately absent so support code cannot smuggle web concerns
  into unit tests.
  """
  use Boundary, top_level?: true, deps: [HologramLiveviewSpike]
end
