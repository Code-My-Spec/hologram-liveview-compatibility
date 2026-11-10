defmodule HologramLiveviewSpike do
  @moduledoc """
  HologramLiveviewSpike keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  # The application core. This boundary claims HologramLiveviewSpike and every
  # module beneath it, and deliberately has no deps — the core must not reach
  # out to the web layer. Add a dep only when a context genuinely needs
  # another top-level boundary.
  use Boundary, top_level?: true, deps: [], exports: :all
end
