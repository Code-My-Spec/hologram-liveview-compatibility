defmodule HologramLiveviewSpike.LvStore do
  @moduledoc """
  What the server knows about each browser-run LiveView, keyed by `{session_id, instance_id, lv_id}`:
  its own copy of the socket, the PubSub topics it subscribed to (derived by the server, never taken from the browser),
  and the last message it applied per topic. Also the log of messages the PubSub bridge delivered, by `{topic, seq}`.

  The browser never sends assigns or message contents back: it sends events, and `{topic, seq}` references the server
  resolves here.
  """
  use GenServer

  @entries __MODULE__
  @messages HologramLiveviewSpike.LvStore.Messages
  @seqs HologramLiveviewSpike.LvStore.Seqs
  @ttl_seconds 3600

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl true
  def init(_) do
    :ets.new(@entries, [:named_table, :public, :set])
    :ets.new(@messages, [:named_table, :public, :set])
    :ets.new(@seqs, [:named_table, :public, :set])
    {:ok, nil}
  end

  def fetch(key) do
    case :ets.lookup(@entries, key) do
      [{^key, entry, _at}] -> entry
      [] -> %{socket: nil, topics: [], applied: %{}}
    end
  end

  # shortcut: one node, in-memory, entries and messages older than an hour are swept on each write (a leaving LiveView is
  # never told to delete its entry); upgrade by monitoring the page or sharing the store across nodes.
  def save(key, entry) do
    now = System.system_time(:second)
    sweep(@entries, now)
    :ets.insert(@entries, {key, entry, now})
    :ok
  end

  @doc "Records a message the bridge delivered on `topic` and returns its sequence number."
  def record_message(topic, message) do
    now = System.system_time(:second)
    sweep(@messages, now)
    seq = :ets.update_counter(@seqs, topic, 1, {topic, 0})
    :ets.insert(@messages, {{topic, seq}, message, now})
    seq
  end

  def fetch_message(topic, seq) do
    case :ets.lookup(@messages, {topic, seq}) do
      [{_key, message, _at}] -> {:ok, message}
      [] -> :error
    end
  end

  defp sweep(table, now) do
    :ets.select_delete(table, [{{:_, :_, :"$1"}, [{:<, :"$1", now - @ttl_seconds}], [true]}])
  end
end
