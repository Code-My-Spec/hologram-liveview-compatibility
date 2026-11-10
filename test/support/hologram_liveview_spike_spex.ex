defmodule HologramLiveviewSpikeSpex do
  @moduledoc """
  Boundary for BDD spec files under `test/spex/`.

  Spex drive the application the way a user does — over HTTP, through
  LiveView, or via the harness's MCP tools — so they may depend on the web
  layer and on test support, but never reach into contexts or the Repo
  directly. The `:spex` compiler enforces this via the `boundary:` key in
  `mix.exs`.
  """
  use Boundary, top_level?: true, deps: [HologramLiveviewSpike, HologramLiveviewSpikeWeb]
end
