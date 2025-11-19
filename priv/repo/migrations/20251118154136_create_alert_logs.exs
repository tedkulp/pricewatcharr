defmodule Pricarr.Repo.Migrations.CreateAlertLogs do
  use Ecto.Migration

  def change do
    create table(:alert_logs) do
      add :triggered_price, :decimal, precision: 10, scale: 2, null: false
      add :previous_price, :decimal, precision: 10, scale: 2
      add :notification_status, :string, null: false
      add :error_message, :text
      add :alert_rule_id, references(:alert_rules, on_delete: :delete_all), null: false
      add :product_url_id, references(:product_urls, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:alert_logs, [:alert_rule_id])
    create index(:alert_logs, [:product_url_id])
    create index(:alert_logs, [:inserted_at])
  end
end
