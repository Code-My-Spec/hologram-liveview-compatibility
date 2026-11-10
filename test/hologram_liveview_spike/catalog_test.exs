defmodule HologramLiveviewSpike.CatalogTest do
  use HologramLiveviewSpike.DataCase

  alias HologramLiveviewSpike.Catalog

  describe "items" do
    alias HologramLiveviewSpike.Catalog.Item

    import HologramLiveviewSpike.CatalogFixtures

    @invalid_attrs %{name: nil, qty: nil}

    test "list_items/0 returns all items" do
      item = item_fixture()
      assert Catalog.list_items() == [item]
    end

    test "get_item!/1 returns the item with given id" do
      item = item_fixture()
      assert Catalog.get_item!(item.id) == item
    end

    test "create_item/1 with valid data creates a item" do
      valid_attrs = %{name: "some name", qty: 42}

      assert {:ok, %Item{} = item} = Catalog.create_item(valid_attrs)
      assert item.name == "some name"
      assert item.qty == 42
    end

    test "create_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_item(@invalid_attrs)
    end

    test "update_item/2 with valid data updates the item" do
      item = item_fixture()
      update_attrs = %{name: "some updated name", qty: 43}

      assert {:ok, %Item{} = item} = Catalog.update_item(item, update_attrs)
      assert item.name == "some updated name"
      assert item.qty == 43
    end

    test "update_item/2 with invalid data returns error changeset" do
      item = item_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_item(item, @invalid_attrs)
      assert item == Catalog.get_item!(item.id)
    end

    test "delete_item/1 deletes the item" do
      item = item_fixture()
      assert {:ok, %Item{}} = Catalog.delete_item(item)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_item!(item.id) end
    end

    test "change_item/1 returns a item changeset" do
      item = item_fixture()
      assert %Ecto.Changeset{} = Catalog.change_item(item)
    end
  end
end
