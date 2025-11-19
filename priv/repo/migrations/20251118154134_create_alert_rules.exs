defmodule Pricarr.Repo.Migrations.CreateAlertRules do
  use Ecto.Migration

  def change do
    create table(:alert_rules) do
      add :name, :string, null: false
      add :trigger_type, :string, null: false
      add :target_price, :decimal, precision: 10, scale: 2
      add :percentage_threshold, :decimal, precision: 5, scale: 2
      add :apprise_urls, {:array, :string}, default: []
      add :enabled, :boolean, default: true, null: false
      add :cooldown_minutes, :integer, default: 60, null: false
      add :last_triggered_at, :utc_datetime
      add :product_id, references(:products, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:alert_rules, [:product_id])
    create index(:alert_rules, [:enabled])
  end
end
