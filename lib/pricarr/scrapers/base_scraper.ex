defmodule Pricarr.Scrapers.BaseScraper do
  @moduledoc """
  Behavior for implementing product price scrapers.

  Each scraper must implement the `scrape_price/1` callback which takes
  a URL and returns price information.
  """

  @type scrape_result :: {:ok, result_map()} | {:error, reason :: term()}
  @type result_map :: %{
          price: Decimal.t() | nil,
          available: boolean(),
          metadata: map()
        }

  @doc """
  Scrapes price information from the given URL.

  Returns:
  - `{:ok, %{price: Decimal, available: boolean, metadata: map}}` on success
  - `{:error, reason}` on failure
  """
  @callback scrape_price(url :: String.t()) :: scrape_result()

  @doc """
  Returns true if this scraper can handle the given URL.
  """
  @callback can_handle?(url :: String.t()) :: boolean()
end
