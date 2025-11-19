defmodule Pricarr.Workers.AlertSender do
  @moduledoc """
  Oban worker for sending price alerts.

  This worker:
  1. Fetches the alert rule and product details
  2. Sends notifications via Apprise
  3. Logs the alert
  4. Updates the alert rule's last_triggered_at timestamp
  """

  use Oban.Worker,
    queue: :alerts,
    max_attempts: 3

  require Logger

  alias Pricarr.Alerts
  alias Pricarr.Alerts.Notifier
  alias Pricarr.Products

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "alert_rule_id" => alert_rule_id,
          "product_url_id" => product_url_id,
          "new_price" => new_price_str,
          "old_price" => old_price_str
        }
      }) do
    alert_rule = Alerts.get_alert_rule!(alert_rule_id)
    product_url = Products.get_product_url!(product_url_id)
    product = Products.get_product!(product_url.product_id)

    new_price = Decimal.new(new_price_str)
    old_price = if old_price_str, do: Decimal.new(old_price_str), else: nil

    Logger.info("Sending alert for rule #{alert_rule_id} (#{alert_rule.name})")

    # Send notifications
    case Notifier.send_price_alert(alert_rule, product, product_url, new_price, old_price) do
      {:ok, _results} ->
        # Log successful alert
        {:ok, _log} =
          Alerts.create_alert_log(%{
            triggered_price: new_price,
            previous_price: old_price,
            notification_status: :sent,
            alert_rule_id: alert_rule_id,
            product_url_id: product_url_id
          })

        # Update last_triggered_at
        Alerts.mark_alert_triggered(alert_rule)

        Logger.info("Alert sent successfully for rule #{alert_rule_id}")
        :ok

      {:error, reason} ->
        # Log failed alert
        {:ok, _log} =
          Alerts.create_alert_log(%{
            triggered_price: new_price,
            previous_price: old_price,
            notification_status: :failed,
            error_message: inspect(reason),
            alert_rule_id: alert_rule_id,
            product_url_id: product_url_id
          })

        Logger.error("Failed to send alert for rule #{alert_rule_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
