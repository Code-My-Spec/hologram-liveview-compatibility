defmodule HologramLiveviewSpike.Catalog.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "items" do
    field :name, :string
    field :qty, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :qty])
    |> validate_required([:name, :qty])
  end
end
