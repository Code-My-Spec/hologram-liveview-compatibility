defmodule HologramLiveviewSpikeWeb.Holo.SignupTest do
  use ExUnit.Case, async: true

  alias HologramLiveviewSpikeWeb.Holo.Signup

  test "valid params have no errors" do
    assert Signup.errors(Signup.changeset(%{"name" => "Ada", "email" => "a@b.co"})) == %{}
  end

  test "bad params report per-field errors" do
    errors = Signup.errors(Signup.changeset(%{"name" => "A", "email" => "nope"}))
    assert errors.name =~ "at least 2"
    assert errors.email == "must look like an email"
  end
end
