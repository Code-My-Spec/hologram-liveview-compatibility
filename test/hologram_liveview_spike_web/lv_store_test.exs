defmodule HologramLiveviewSpikeWeb.Holo.LvStoreTest do
  use ExUnit.Case, async: true

  alias HologramLiveviewSpike.LvStore
  alias HologramLiveviewSpikeWeb.Holo.{LvLocalPage, SignupLive}

  defp command(server, lv_id, log, op) do
    inputs = %{
      view: SignupLive,
      live_action: nil,
      params: %{},
      flash: %{},
      href: "http://localhost:4100/lv/signup"
    }

    LvLocalPage.command(
      :lv_server,
      %{ref: "1", lv_id: lv_id, inputs: inputs, log: log, op: op},
      server
    )
  end

  test "the server keeps its own socket, replays the browser's log on it, and keys it by identity" do
    server = %Hologram.Server{session_id: "s1", instance_id: "i1"}
    lv_id = "lv-#{System.unique_integer([:positive])}"
    bad = %{"signup" => %{"name" => "A", "email" => "nope"}}

    # The browser mounted locally, validated locally, then hit a server-only call (an invalid save never reaches the DB).
    server = command(server, lv_id, [{:event, "validate", bad}], {:event, "save", bad})

    assert %{name: :lv_done, params: %{socket: socket}} = server.next_action
    assert socket.assigns.status == "fix the errors above"

    # The stored copy is the full socket (with its closures); another session or tab can't see it.
    assert %Phoenix.LiveView.Socket{} = LvStore.fetch({"s1", "i1", lv_id}).socket
    assert LvStore.fetch({"s2", "i1", lv_id}).socket == nil
    assert LvStore.fetch({"s1", "i2", lv_id}).socket == nil
  end

  test "an event the client sends cannot smuggle assigns: only inputs are accepted" do
    server = %Hologram.Server{session_id: "s1", instance_id: "i1"}
    lv_id = "lv-#{System.unique_integer([:positive])}"

    inputs = %{
      view: SignupLive,
      live_action: nil,
      params: %{},
      flash: %{},
      href: "http://localhost:4100/lv/signup"
    }

    # A forged :socket param is simply never read by the command.
    forged = %{
      ref: "1",
      lv_id: lv_id,
      inputs: inputs,
      log: [],
      op: {:event, "validate", %{"signup" => %{"name" => "", "email" => ""}}},
      socket: :forged
    }

    server = LvLocalPage.command(:lv_server, forged, server)
    assert %{params: %{socket: %Phoenix.LiveView.Socket{}}} = server.next_action
  end

  describe "bridged messages in the browser's log" do
    setup do
      topic = "topic-#{System.unique_integer([:positive])}"
      server = %Hologram.Server{session_id: "s1", instance_id: "i1"}
      lv_id = "lv-#{System.unique_integer([:positive])}"
      key = {"s1", "i1", lv_id}
      %{topic: topic, server: server, lv_id: lv_id, key: key}
    end

    defp total_after(server, lv_id, log) do
      server =
        command(
          server,
          lv_id,
          log,
          {:event, "validate", %{"signup" => %{"name" => "", "email" => ""}}}
        )

      %{params: %{socket: socket}} = server.next_action
      socket.assigns.total
    end

    test "a message the server recorded, on a subscribed topic, is applied once", ctx do
      seq = LvStore.record_message(ctx.topic, {:signup, 7})
      LvStore.save(ctx.key, %{socket: nil, topics: [ctx.topic], applied: %{}})

      # The same reference twice, as a replaying client might send it.
      log = [{:info, ctx.topic, seq}, {:info, ctx.topic, seq}]
      assert total_after(ctx.server, ctx.lv_id, log) == 7
      assert LvStore.fetch(ctx.key).applied == %{ctx.topic => seq}
    end

    test "a forged sequence number, an unsubscribed topic, and a replayed old message are all dropped",
         ctx do
      real = LvStore.record_message(ctx.topic, {:signup, 7})
      other = "other-#{System.unique_integer([:positive])}"
      other_seq = LvStore.record_message(other, {:signup, 666})
      LvStore.save(ctx.key, %{socket: nil, topics: [ctx.topic], applied: %{ctx.topic => real}})

      log = [
        # no such message
        {:info, ctx.topic, real + 100},
        # a real message, but on a topic this LiveView never subscribed to
        {:info, other, other_seq},
        # already applied
        {:info, ctx.topic, real}
      ]

      assert total_after(ctx.server, ctx.lv_id, log) == nil
    end
  end
end
