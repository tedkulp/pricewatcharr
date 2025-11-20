defmodule Pricarr.Workers.Scheduler do
  @moduledoc """
  Schedules periodic price checks for all active product URLs.

  This module is called on application startup to ensure all URLs
  that are due for checking have jobs scheduled.
  """

  require Logger

  alias Pricarr.Products
  alias Pricarr.Workers.PriceChecker

  # Minimum time since last check before running immediately (1 hour in seconds)
  @min_delay_seconds 3600

  @doc """
  Schedules price checks for all active URLs.
  Called on application startup.

  - URLs that were never checked: run immediately
  - URLs checked less than 1 hour ago: schedule for 1 hour after last check (to avoid IP bans)
  - URLs that are overdue but checked within 1 hour: schedule for 1 hour after last check
  - URLs that are overdue and checked more than 1 hour ago: run immediately
  """
  def schedule_due_checks do
    urls = Products.list_active_urls()

    Logger.info("Scheduling checks for #{length(urls)} active URL(s)")

    Enum.each(urls, fn url ->
      delay = calculate_delay(url)

      if delay > 0 do
        Logger.info("Scheduling check for URL #{url.id} in #{div(delay, 60)} minutes")
        PriceChecker.schedule_check_in(url.id, delay)
      else
        Logger.info("Scheduling immediate check for URL #{url.id}")
        PriceChecker.schedule_check(url.id)
      end
    end)

    {:ok, length(urls)}
  end

  # Calculate delay in seconds before running a check
  defp calculate_delay(%{last_checked_at: nil}), do: 0

  defp calculate_delay(url) do
    now = DateTime.utc_now()
    seconds_since_check = DateTime.diff(now, url.last_checked_at, :second)
    interval_seconds = url.check_interval_minutes * 60

    # When is the next check due?
    seconds_until_due = interval_seconds - seconds_since_check

    if seconds_until_due <= 0 do
      # URL is overdue - but still enforce minimum 1 hour since last check
      if seconds_since_check < @min_delay_seconds do
        @min_delay_seconds - seconds_since_check
      else
        0
      end
    else
      # URL is not due yet - schedule for when it's due
      # But also enforce minimum 1 hour since last check
      max(seconds_until_due, @min_delay_seconds - seconds_since_check)
    end
  end
end
