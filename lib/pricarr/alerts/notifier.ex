defmodule Pricarr.Alerts.Notifier do
  @moduledoc """
  Handles sending notifications via Apprise.
  """

  require Logger

  @doc """
  Sends a price alert notification via Apprise.
  """
  def send_price_alert(alert_rule, product, product_url, new_price, old_price) do
    title = "Price Alert: #{product.name}"
    message = format_alert_message(product, product_url, new_price, old_price, alert_rule)

    send_notifications(alert_rule.apprise_urls, title, message)
  end

  @doc """
  Sends a test notification to verify the alert configuration.
  """
  def send_test_notification(alert_rule) do
    title = "Test Alert: #{alert_rule.name}"

    message = """
    This is a test notification from Pricarr.

    Alert: #{alert_rule.name}

    If you received this message, your notification settings are working correctly!
    """

    send_notifications(alert_rule.apprise_urls, title, message)
  end

  defp format_alert_message(product, product_url, new_price, old_price, alert_rule) do
    lines = [
      "Product: #{product.name}",
      "Retailer: #{product_url.retailer}",
      "",
      "Current Price: $#{Decimal.to_string(new_price)}"
    ]

    lines =
      if old_price do
        price_diff = Decimal.sub(new_price, old_price)
        percentage = calculate_percentage_change(new_price, old_price)

        lines ++
          [
            "Previous Price: $#{Decimal.to_string(old_price)}",
            "Change: $#{Decimal.to_string(price_diff)} (#{percentage}%)"
          ]
      else
        lines
      end

    lines =
      case alert_rule.trigger_type do
        :below_price ->
          lines ++ ["", "Alert: Price dropped below $#{Decimal.to_string(alert_rule.target_price)}"]

        :percentage_drop ->
          lines ++
            [
              "",
              "Alert: Price dropped by #{Decimal.to_string(alert_rule.percentage_threshold)}% or more"
            ]

        :both ->
          lines ++
            [
              "",
              "Alert: Price target or percentage threshold met"
            ]
      end

    lines = lines ++ ["", "URL: #{product_url.url}"]

    Enum.join(lines, "\n")
  end

  defp calculate_percentage_change(new_price, old_price) do
    Decimal.sub(new_price, old_price)
    |> Decimal.div(old_price)
    |> Decimal.mult(Decimal.new(100))
    |> Decimal.round(2)
    |> Decimal.to_string()
  end

  defp send_notifications(apprise_urls, title, message) do
    results =
      Enum.map(apprise_urls, fn url ->
        send_via_apprise(url, title, message)
      end)

    # Return success if at least one notification was sent
    if Enum.any?(results, fn {status, _} -> status == :ok end) do
      {:ok, results}
    else
      {:error, results}
    end
  end

  defp send_via_apprise(apprise_url, title, message) do
    case Rambo.run("apprise", ["-t", title, "-b", message, apprise_url]) do
      {:ok, %{status: 0}} ->
        Logger.info("Notification sent successfully via #{mask_url(apprise_url)}")
        {:ok, apprise_url}

      {:ok, %{status: status, out: output, err: error}} ->
        Logger.error(
          "Apprise notification failed for #{mask_url(apprise_url)} (status #{status}): #{output} #{error}"
        )

        {:error, {:apprise_error, status, output <> error}}

      {:error, error} ->
        Logger.error("Failed to execute apprise for #{mask_url(apprise_url)}: #{inspect(error)}")
        {:error, error}
    end
  end

  # Mask sensitive parts of URLs for logging
  defp mask_url(url) do
    uri = URI.parse(url)

    case uri.scheme do
      nil -> url
      scheme -> "#{scheme}://[REDACTED]"
    end
  end
end
