defmodule HologramLiveviewSpikeWeb.Holo.Server do
  @moduledoc """
  Marks a call as server-only. In the browser (the page sets `:lv_client?`) it raises
  `:hologram_server_only`, and the page re-runs the whole event on the server, where this applies the
  call. The module is a variable here, so Hologram's call graph cannot follow it and the callee never
  lands in the browser bundle. (Modules listed under `config :hologram, server_only_modules` get the
  same behaviour without calling this.)
  """

  # shortcut: a handler's side effects before this call are discarded and redone on the server (fine while handlers are
  # pure up to the call); upgrade by splitting the handler at the call if earlier work ever turns out to be costly.
  def call(mod, fun, args) do
    if Process.get(:lv_client?),
      do: :erlang.error(:hologram_server_only),
      else: apply(mod, fun, args)
  end
end
