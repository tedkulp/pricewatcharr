defmodule Pricarr.Repo.Migrations.CreateProductUrls do
  use Ecto.Migration

  def change do
    create table(:product_urls) do
      add :url, :text, null: false
      add :retailer, :string, null: false
      add :check_interval_minutes, :integer, default: 60, null: false
      add :last_checked_at, :utc_datetime
      add :last_price, :decimal, precision: 10, scale: 2
      add :last_available, :boolean, default: true
      add :active, :boolean, default: true, null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:product_urls, [:product_id])
    create index(:product_urls, [:active])
    create index(:product_urls, [:last_checked_at])
  end
end
