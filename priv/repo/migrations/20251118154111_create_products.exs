defmodule Pricarr.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :string, null: false
      add :description, :text
      add :image_url, :string
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:products, [:active])
  end
end
