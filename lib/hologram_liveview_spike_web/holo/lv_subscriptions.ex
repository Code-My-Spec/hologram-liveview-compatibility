defmodule HologramLiveviewSpikeWeb.Holo.LvSubscriptions do
  @moduledoc """
  Which PubSub topics a LiveView subscribes to, found by running its mount on the server. The browser is never asked: a
  browser-run mount reports that it subscribed, but the server decides to what.
  """
  alias HologramLiveviewSpikeWeb.Holo.LvRunner

  # shortcut: only subscriptions made in mount are found; a view that subscribes later (in handle_event, handle_params or
  # handle_info) gets no bridged messages. Upgrade by running the replayed log under the same recorder.
  def derive(inputs), do: inputs |> mount() |> elem(1)

  @doc "Mounts on the server in a throwaway process and returns {{diff, state}, topics it subscribed to}."
  def mount(inputs) do
    %{view: view, live_action: live_action, params: params, flash: flash, href: href} = inputs

    # The real PubSub registers the subscriber's pid, and the registry reports it back; the process then exits.
    Task.async(fn ->
      result = LvRunner.new(view, live_action, params, flash, href)
      {result, HologramLiveviewSpike.PubSub |> Registry.keys(self()) |> Enum.sort()}
    end)
    |> Task.await()
  end
end
