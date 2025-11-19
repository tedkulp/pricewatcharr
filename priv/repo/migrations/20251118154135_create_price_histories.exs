defmodule Pricarr.Repo.Migrations.CreatePriceHistories do
  use Ecto.Migration

  def change do
    create table(:price_histories) do
      add :price, :decimal, precision: 10, scale: 2
      add :available, :boolean, default: true, null: false
      add :checked_at, :utc_datetime, null: false
      add :metadata, :map, default: %{}
      add :product_url_id, references(:product_urls, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:price_histories, [:product_url_id])
    create index(:price_histories, [:product_url_id, :checked_at])
    create index(:price_histories, [:checked_at])
  end
end
