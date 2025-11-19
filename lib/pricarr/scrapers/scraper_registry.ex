defmodule Pricarr.Scrapers.ScraperRegistry do
  @moduledoc """
  Registry for managing and routing to different scrapers.
  """

  require Logger

  alias Pricarr.Scrapers.Amazon.SimpleHTTP

  @scrapers [
    SimpleHTTP
  ]

  @doc """
  Scrapes a URL using the appropriate scraper.
  """
  def scrape_url(url) do
    case find_scraper(url) do
      {:ok, scraper_module} ->
        Logger.info("Scraping #{url} with #{inspect(scraper_module)}")
        scraper_module.scrape_price(url)

      {:error, :no_scraper} ->
        Logger.error("No scraper found for URL: #{url}")
        {:error, :no_scraper_available}
    end
  end

  @doc """
  Finds the appropriate scraper for the given URL.
  """
  def find_scraper(url) do
    case Enum.find(@scrapers, fn scraper -> scraper.can_handle?(url) end) do
      nil -> {:error, :no_scraper}
      scraper -> {:ok, scraper}
    end
  end

  @doc """
  Returns the list of registered scrapers.
  """
  def list_scrapers, do: @scrapers
end
