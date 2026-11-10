defmodule HologramLiveviewSpikeWeb.Holo.LvRunnerTest do
  use ExUnit.Case, async: true

  alias HologramLiveviewSpikeWeb.Holo.{LvJson, LvParams, LvRunner, LvViews, Server}

  @uri "http://localhost:4100/lv/signup"

  test "form params decode from urlencoded pairs" do
    pairs = [
      ["signup[name]", "Ada"],
      ["signup[email]", "a@b.co"],
      ["_target[]", "signup"],
      ["_target[]", "name"]
    ]

    assert LvParams.decode(pairs) == %{
             "signup" => %{"name" => "Ada", "email" => "a@b.co"},
             "_target" => ["signup", "name"]
           }
  end

  test "validate runs locally and returns a delta" do
    {full, st} = LvRunner.new(LvViews.resolve("signup"), nil, %{}, %{}, @uri)
    assert Map.has_key?(full, :p)

    {diff, _} = LvRunner.event(st, "validate", %{"signup" => %{"name" => "A", "email" => ""}})
    assert inspect(diff) =~ "at least 2"
  end

  test "save reaches Server.call: raises in the browser, applies on the server" do
    {_, st} = LvRunner.new(LvViews.resolve("signup"), nil, %{}, %{}, @uri)
    params = %{"signup" => %{"name" => "A", "email" => "x"}}

    Process.put(:lv_client?, true)
    assert catch_error(LvRunner.event(st, "save", params)) == :hologram_server_only
    Process.delete(:lv_client?)

    assert Server.call(Enum, :count, [[1, 2]]) == 2
  end

  test "urls resolve to the router's live routes, in router order" do
    alias HologramLiveviewSpikeWeb.ItemLive

    assert LvViews.resolve_url("/items") == {ItemLive.Index, :index, %{}}
    assert LvViews.resolve_url("/items/new") == {ItemLive.Form, :new, %{}}
    assert LvViews.resolve_url("/items/7") == {ItemLive.Show, :show, %{"id" => "7"}}

    assert LvViews.resolve_url("/items/7/edit?return_to=show") ==
             {ItemLive.Form, :edit, %{"id" => "7", "return_to" => "show"}}

    assert {HologramLiveviewSpikeWeb.Holo.SignupLive, nil, %{}} =
             LvViews.resolve_url("/lv/signup")

    assert_raise ArgumentError, fn -> LvViews.resolve_url("/nope") end
  end

  test "json encoding escapes strings and stringifies keys" do
    assert LvJson.enc(%{0 => "a\"b\n", :s => [1, nil, true]}) ==
             ~s({"0":"a\\"b\\n","s":[1,null,true]})
  end
end
