defmodule HologramLiveviewSpikeWeb.Holo.LvPatchTest do
  use HologramLiveviewSpike.DataCase, async: true

  alias HologramLiveviewSpike.Catalog
  alias HologramLiveviewSpikeWeb.FilterLive
  alias HologramLiveviewSpikeWeb.Holo.LvRunner

  @uri "http://localhost:4100/items_filter"

  setup do
    {:ok, _} = Catalog.create_item(%{name: "Nav one", qty: 1})
    {:ok, _} = Catalog.create_item(%{name: "Other", qty: 2})
    :ok
  end

  defp names(state), do: state.socket.assigns.items |> Enum.map(& &1.name) |> Enum.sort()

  test "handle_params runs after mount, reading the query params" do
    {_diff, state} = LvRunner.new(FilterLive, nil, %{"q" => "nav"}, %{}, @uri <> "?q=nav")
    assert names(state) == ["Nav one"]
  end

  test "a client live_patch re-runs handle_params and returns a delta" do
    {_diff, state} = LvRunner.new(FilterLive, nil, %{}, %{}, @uri)
    assert names(state) == ["Nav one", "Other"]

    {diff, state} = LvRunner.patch(state, nil, %{"q" => "other"}, @uri <> "?q=other")
    assert names(state) == ["Other"]
    refute Map.has_key?(diff, :p)
  end

  test "push_patch in an event applies the new URL and leaves a pending patch for the client" do
    {_diff, state} = LvRunner.new(FilterLive, nil, %{}, %{}, @uri)

    {_diff, state} = LvRunner.event(state, "filter", %{"q" => "nav"})
    assert names(state) == ["Nav one"]
    assert %{to: "/items_filter?q=nav"} = state.socket.private.lv_pending_patch
    assert state.socket.redirected == nil
  end
end
