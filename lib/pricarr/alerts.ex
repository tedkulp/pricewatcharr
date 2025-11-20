defmodule Pricarr.Alerts do
  @moduledoc """
  The Alerts context.
  """

  import Ecto.Query, warn: false
  alias Pricarr.Repo

  alias Pricarr.Alerts.{AlertRule, AlertLog}

  ## Alert Rules

  @doc """
  Returns the list of alert_rules.
  """
  def list_alert_rules do
    Repo.all(AlertRule)
    |> Repo.preload(:product)
  end

  @doc """
  Returns the list of enabled alert_rules for a product.
  """
  def list_enabled_alert_rules_for_product(product_id) do
    AlertRule
    |> where([ar], ar.product_id == ^product_id and ar.enabled == true)
    |> Repo.all()
  end

  @doc """
  Returns all alert_rules for a product.
  """
  def list_alert_rules_for_product(product_id) do
    AlertRule
    |> where([ar], ar.product_id == ^product_id)
    |> Repo.all()
  end

  @doc """
  Gets a single alert_rule.
  """
  def get_alert_rule!(id) do
    Repo.get!(AlertRule, id)
    |> Repo.preload([:product, :alert_logs])
  end

  @doc """
  Creates a alert_rule.
  """
  def create_alert_rule(attrs \\ %{}) do
    %AlertRule{}
    |> AlertRule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a alert_rule.
  """
  def update_alert_rule(%AlertRule{} = alert_rule, attrs) do
    alert_rule
    |> AlertRule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a alert_rule.
  """
  def delete_alert_rule(%AlertRule{} = alert_rule) do
    Repo.delete(alert_rule)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking alert_rule changes.
  """
  def change_alert_rule(%AlertRule{} = alert_rule, attrs \\ %{}) do
    AlertRule.changeset(alert_rule, attrs)
  end

  @doc """
  Checks if an alert rule should be triggered based on price change.
  Only alerts if price meets threshold AND price has changed since last alert.
  """
  def should_trigger_alert?(%AlertRule{} = rule, new_price, old_price, product_url_id) do
    cond do
      not rule.enabled ->
        false

      in_cooldown?(rule) ->
        false

      not price_changed_since_last_alert?(rule.id, product_url_id, new_price) ->
        false

      true ->
        case rule.trigger_type do
          :below_price ->
            Decimal.compare(new_price, rule.target_price) == :lt

          :percentage_drop ->
            check_percentage_drop(new_price, old_price, rule.percentage_threshold)

          :both ->
            Decimal.compare(new_price, rule.target_price) == :lt or
              check_percentage_drop(new_price, old_price, rule.percentage_threshold)
        end
    end
  end

  defp in_cooldown?(%AlertRule{last_triggered_at: nil}), do: false

  defp in_cooldown?(%AlertRule{last_triggered_at: last_triggered, cooldown_minutes: cooldown}) do
    now = DateTime.utc_now()
    cooldown_end = DateTime.add(last_triggered, cooldown * 60, :second)
    DateTime.compare(now, cooldown_end) == :lt
  end

  defp check_percentage_drop(new_price, old_price, threshold) when not is_nil(old_price) do
    drop_percentage =
      Decimal.sub(old_price, new_price)
      |> Decimal.div(old_price)
      |> Decimal.mult(Decimal.new(100))

    Decimal.compare(drop_percentage, threshold) != :lt
  end

  defp check_percentage_drop(_new_price, nil, _threshold), do: false

  defp price_changed_since_last_alert?(alert_rule_id, product_url_id, new_price) do
    last_log =
      AlertLog
      |> where([al], al.alert_rule_id == ^alert_rule_id and al.product_url_id == ^product_url_id)
      |> order_by([al], desc: al.inserted_at)
      |> limit(1)
      |> Repo.one()

    case last_log do
      nil ->
        # No previous alert, so this is a new alert
        true

      log ->
        # Alert only if price has changed
        Decimal.compare(new_price, log.triggered_price) != :eq
    end
  end

  @doc """
  Updates the last_triggered_at timestamp for an alert rule.
  """
  def mark_alert_triggered(%AlertRule{} = alert_rule) do
    update_alert_rule(alert_rule, %{last_triggered_at: DateTime.utc_now()})
  end

  ## Alert Logs

  @doc """
  Returns the list of alert_logs.
  """
  def list_alert_logs(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    AlertLog
    |> order_by([al], desc: al.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload([:alert_rule, :product_url])
  end

  @doc """
  Returns alert logs for a specific alert rule.
  """
  def list_alert_logs_for_rule(alert_rule_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    AlertLog
    |> where([al], al.alert_rule_id == ^alert_rule_id)
    |> order_by([al], desc: al.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload(:product_url)
  end

  @doc """
  Creates an alert_log entry.
  """
  def create_alert_log(attrs \\ %{}) do
    %AlertLog{}
    |> AlertLog.changeset(attrs)
    |> Repo.insert()
  end
end
