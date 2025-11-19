defmodule Pricarr.Alerts.AlertRule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alert_rules" do
    field :name, :string
    field :trigger_type, Ecto.Enum, values: [:below_price, :percentage_drop, :both]
    field :target_price, :decimal
    field :percentage_threshold, :decimal
    field :apprise_urls, {:array, :string}, default: []
    field :enabled, :boolean, default: true
    field :cooldown_minutes, :integer, default: 60
    field :last_triggered_at, :utc_datetime

    belongs_to :product, Pricarr.Products.Product
    has_many :alert_logs, Pricarr.Alerts.AlertLog

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(alert_rule, attrs) do
    alert_rule
    |> cast(attrs, [
      :name,
      :trigger_type,
      :target_price,
      :percentage_threshold,
      :apprise_urls,
      :enabled,
      :cooldown_minutes,
      :last_triggered_at,
      :product_id
    ])
    |> validate_required([:name, :trigger_type, :product_id])
    |> validate_trigger_requirements()
    |> validate_number(:cooldown_minutes, greater_than_or_equal_to: 0)
    |> validate_length(:apprise_urls, min: 1, message: "at least one notification URL is required")
    |> foreign_key_constraint(:product_id)
  end

  defp validate_trigger_requirements(changeset) do
    trigger_type = get_field(changeset, :trigger_type)

    changeset
    |> maybe_validate_target_price(trigger_type)
    |> maybe_validate_percentage(trigger_type)
  end

  defp maybe_validate_target_price(changeset, trigger_type)
       when trigger_type in [:below_price, :both] do
    validate_required(changeset, [:target_price])
  end

  defp maybe_validate_target_price(changeset, _), do: changeset

  defp maybe_validate_percentage(changeset, trigger_type)
       when trigger_type in [:percentage_drop, :both] do
    validate_required(changeset, [:percentage_threshold])
  end

  defp maybe_validate_percentage(changeset, _), do: changeset
end
