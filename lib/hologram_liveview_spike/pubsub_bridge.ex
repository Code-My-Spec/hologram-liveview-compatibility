defmodule HologramLiveviewSpike.PubSubBridge do
  @moduledoc """
  Server side of a browser-run LiveView's `Phoenix.PubSub.subscribe/2`: one process per topic
  subscribes to the real PubSub, records each message in `LvStore`, and re-broadcasts it as a Hologram action on
  `{:pubsub, topic}`.
  """
  # shortcut: a topic's bridge lives until the node stops (no unsubscribe, topics unbounded by clients);
  # upgrade by stopping a bridge when its last Hologram subscriber leaves.
  use GenServer

  @registry HologramLiveviewSpike.PubSubBridge.Registry
  @sup HologramLiveviewSpike.PubSubBridge.Supervisor

  def ensure(topic) do
    case DynamicSupervisor.start_child(@sup, %{
           id: topic,
           start: {__MODULE__, :start_link, [topic]},
           restart: :temporary
         }) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end

  def start_link(topic),
    do: GenServer.start_link(__MODULE__, topic, name: {:via, Registry, {@registry, topic}})

  @impl true
  def init(topic) do
    :ok = Phoenix.PubSub.subscribe(HologramLiveviewSpike.PubSub, topic)
    {:ok, topic}
  end

  @impl true
  def handle_info(message, topic) do
    # The message is recorded first: the browser logs only {topic, seq}, and the server replays from this record.
    seq = HologramLiveviewSpike.LvStore.record_message(topic, message)

    Hologram.Realtime.broadcast_action({:pubsub, topic}, :lv_info, %{
      topic: topic,
      seq: seq,
      message: message
    })

    {:noreply, topic}
  end
end
