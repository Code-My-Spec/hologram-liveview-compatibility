defmodule HologramLiveviewSpike.CatalogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HologramLiveviewSpike.Catalog` context.
  """

  @doc """
  Generate a item.
  """
  def item_fixture(attrs \\ %{}) do
    {:ok, item} =
      attrs
      |> Enum.into(%{
        name: "some name",
        qty: 42
      })
      |> HologramLiveviewSpike.Catalog.create_item()

    item
  end
end
