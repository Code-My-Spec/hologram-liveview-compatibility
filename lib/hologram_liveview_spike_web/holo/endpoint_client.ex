defmodule HologramLiveviewSpikeWeb.Holo.EndpointClient do
  @moduledoc "Browser-side stand-in for `HologramLiveviewSpikeWeb.Endpoint` (see `client_module_overrides` in config.exs)."

  # shortcut: paths come back exactly as given: no digest/vsn query, no host. Production static_path differs from this;
  # upgrade by shipping the static manifest to the client or rendering static paths on the server.
  def static_path(path), do: path
  def path(path), do: path
end
