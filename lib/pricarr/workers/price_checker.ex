defmodule Pricarr.Workers.PriceChecker do
  @moduledoc """
  Oban worker for checking product prices.

  This worker:
  1. Fetches a product URL
  2. Scrapes the current price
  3. Saves price history
  4. Updates the product URL with latest price
  5. Checks alert rules and enqueues AlertSender if needed
  6. Reschedules itself based on the product's check interval
  """

  use Oban.Worker,
    queue: :price_check,
    max_attempts: 3,
    unique: [period: 60, fields: [:args]]

  require Logger

  alias Pricarr.Products
  alias Pricarr.Alerts
  alias Pricarr.Scrapers.ScraperRegistry
  alias Pricarr.Workers.AlertSender

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"product_url_id" => product_url_id}}) do
    product_url = Products.get_product_url!(product_url_id)

    Logger.info("Checking price for product URL #{product_url_id}: #{product_url.url}")

    case ScraperRegistry.scrape_url(product_url.url) do
      {:ok, %{price: price, available: available, metadata: metadata}} ->
        handle_successful_scrape(product_url, price, available, metadata)

      {:error, reason} ->
        Logger.error("Failed to scrape product URL #{product_url_id}: #{inspect(reason)}")
        handle_failed_scrape(product_url, reason)
    end

    # Always reschedule for next check
    schedule_next_check(product_url)

    :ok
  end

  defp handle_successful_scrape(product_url, price, available, metadata) do
    now = DateTime.utc_now()

    # Create price history entry
    {:ok, _price_history} =
      Products.create_price_history(%{
        price: price,
        available: available,
        checked_at: now,
        metadata: metadata,
        product_url_id: product_url.id
      })

    # Update product URL with latest price
    {:ok, updated_url} =
      Products.update_product_url(product_url, %{
        last_price: price,
        last_available: available,
        last_checked_at: now
      })

    Logger.info(
      "Price updated for product URL #{product_url.id}: #{price} (available: #{available})"
    )

    # Check alert rules if price is available
    if available and price do
      check_alert_rules(updated_url, price)
    end
  end

  defp handle_failed_scrape(product_url, _reason) do
    # Still update last_checked_at to prevent repeated failures in quick succession
    Products.update_product_url(product_url, %{
      last_checked_at: DateTime.utc_now()
    })
  end

  defp check_alert_rules(product_url, new_price) do
    # Get all enabled alert rules for this product
    alert_rules = Alerts.list_enabled_alert_rules_for_product(product_url.product_id)

    old_price = product_url.last_price

    Enum.each(alert_rules, fn rule ->
      if Alerts.should_trigger_alert?(rule, new_price, old_price, product_url.id) do
        # Enqueue alert sender job
        %{
          alert_rule_id: rule.id,
          product_url_id: product_url.id,
          new_price: Decimal.to_string(new_price),
          old_price: if(old_price, do: Decimal.to_string(old_price), else: nil)
        }
        |> AlertSender.new()
        |> Oban.insert()

        Logger.info("Alert triggered for rule #{rule.id} (#{rule.name})")
      else
        Logger.debug(
          "Alert not triggered for rule #{rule.id} (#{rule.name}) - conditions not met or price unchanged"
        )
      end
    end)
  end

  defp schedule_next_check(product_url) do
    if product_url.active do
      %{product_url_id: product_url.id}
      |> new(schedule_in: product_url.check_interval_minutes * 60)
      |> Oban.insert()

      Logger.info(
        "Scheduled next check for product URL #{product_url.id} in #{product_url.check_interval_minutes} minutes"
      )
    else
      Logger.info("Skipping reschedule for inactive product URL #{product_url.id}")
    end
  end

  @doc """
  Schedules an immediate price check for a product URL.
  """
  def schedule_check(product_url_id) do
    %{product_url_id: product_url_id}
    |> new()
    |> Oban.insert()
  end

  @doc """
  Schedules a price check for a product URL with a delay in seconds.
  """
  def schedule_check_in(product_url_id, delay_seconds) when delay_seconds > 0 do
    %{product_url_id: product_url_id}
    |> new(schedule_in: delay_seconds)
    |> Oban.insert()
  end

  def schedule_check_in(product_url_id, _delay_seconds) do
    schedule_check(product_url_id)
  end
end
