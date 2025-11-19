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
  Schedules price checks for all active URLs that are overdue.
  Called on application startup.

  To avoid getting IP banned, URLs that were checked less than 1 hour ago
  will be scheduled to run 1 hour after their last check instead of immediately.
  """
  def schedule_due_checks do
    urls = Products.list_urls_due_for_check()

    Logger.info("Scheduling checks for #{length(urls)} overdue URL(s)")

    Enum.each(urls, fn url ->
      delay = calculate_delay(url.last_checked_at)

      if delay > 0 do
        Logger.debug("Scheduling check for URL #{url.id} in #{delay} seconds")
        PriceChecker.schedule_check_in(url.id, delay)
      else
        Logger.debug("Scheduling immediate check for URL #{url.id}")
        PriceChecker.schedule_check(url.id)
      end
    end)

    {:ok, length(urls)}
  end

  # Calculate delay in seconds before running a check
  # Returns 0 if check can run immediately, otherwise returns seconds to wait
  defp calculate_delay(nil), do: 0

  defp calculate_delay(last_checked_at) do
    now = DateTime.utc_now()
    seconds_since_check = DateTime.diff(now, last_checked_at, :second)

    if seconds_since_check < @min_delay_seconds do
      # Schedule for 1 hour after last check
      @min_delay_seconds - seconds_since_check
    else
      # More than an hour ago, run immediately
      0
    end
  end
end
