defmodule HologramLiveviewSpikeWeb.Holo.LvComponentsTest do
  use ExUnit.Case, async: true

  alias HologramLiveviewSpikeWeb.ComponentLive
  alias HologramLiveviewSpikeWeb.Holo.LvRunner

  @uri "http://localhost:4100/components"

  test "mount renders both components into the diff's component map" do
    {diff, state} = LvRunner.new(ComponentLive, nil, %{}, %{}, @uri)
    assert map_size(diff.c) == 2
    assert inspect(diff) =~ "Apples"
    assert inspect(diff) =~ "Bananas"
    assert elem(state.comps, 0) |> map_size() == 2
  end

  test "an event with a cid changes only that component and returns only its diff" do
    {_diff, state} = LvRunner.new(ComponentLive, nil, %{}, %{}, @uri)

    {diff, state} = LvRunner.component_event(state, 1, "inc", %{"by" => "1"})
    assert [cid] = Map.keys(diff.c)
    assert is_integer(cid)
    assert inspect(diff) =~ "1"
    refute Map.has_key?(diff, 0)

    {diff, _state} = LvRunner.component_event(state, 1, "inc", %{"by" => "1"})
    assert inspect(diff) =~ "2"
  end

  test "a parent change re-runs the component's update/2 with the new assigns" do
    {_diff, state} = LvRunner.new(ComponentLive, nil, %{}, %{}, @uri)
    {_d, state} = LvRunner.component_event(state, 1, "inc", %{"by" => "1"})

    {diff, _state} = LvRunner.event(state, "rename", %{})
    assert inspect(diff) =~ "Pears"
    # the component keeps its own count across the parent's update
    assert inspect(diff) =~ "1"
  end

  test "components survive an export to the browser when they hold no closures" do
    {_diff, state} = LvRunner.new(ComponentLive, nil, %{}, %{}, @uri)
    exported = LvRunner.export(state)

    {diff, _state} = LvRunner.component_event(exported, 1, "inc", %{"by" => "1"})
    assert inspect(diff) =~ "1"
  end

  test "an event for a cid the registry doesn't know raises instead of passing silently" do
    {_diff, state} = LvRunner.new(ComponentLive, nil, %{}, %{}, @uri)

    assert_raise ArgumentError, ~r/no LiveComponent with cid 99/, fn ->
      LvRunner.component_event(state, 99, "inc", %{})
    end
  end
end
