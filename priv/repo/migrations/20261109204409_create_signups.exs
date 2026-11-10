defmodule HologramLiveviewSpike.Repo.Migrations.CreateSignups do
  use Ecto.Migration

  def change do
    create table(:signups) do
      add :name, :string, null: false
      add :email, :string, null: false
      timestamps(type: :utc_datetime)
    end
  end
end
