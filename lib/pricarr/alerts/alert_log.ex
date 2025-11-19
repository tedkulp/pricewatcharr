defmodule Pricarr.Alerts.AlertLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alert_logs" do
    field :triggered_price, :decimal
    field :previous_price, :decimal
    field :notification_status, Ecto.Enum, values: [:sent, :failed, :skipped]
    field :error_message, :string

    belongs_to :alert_rule, Pricarr.Alerts.AlertRule
    belongs_to :product_url, Pricarr.Products.ProductUrl

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(alert_log, attrs) do
    alert_log
    |> cast(attrs, [
      :triggered_price,
      :previous_price,
      :notification_status,
      :error_message,
      :alert_rule_id,
      :product_url_id
    ])
    |> validate_required([:triggered_price, :notification_status, :alert_rule_id, :product_url_id])
    |> foreign_key_constraint(:alert_rule_id)
    |> foreign_key_constraint(:product_url_id)
  end
end
