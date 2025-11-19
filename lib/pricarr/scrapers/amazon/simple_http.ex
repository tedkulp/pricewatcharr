defmodule Pricarr.Scrapers.Amazon.SimpleHTTP do
  @moduledoc """
  Simple HTTP-based scraper for Amazon product pages.
  Uses Req for HTTP requests and Floki for HTML parsing.
  """

  @behaviour Pricarr.Scrapers.BaseScraper

  require Logger

  @user_agents [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15"
  ]

  @price_selectors [
    # Prefer .a-offscreen which contains the full formatted price like "$549.00"
    "span.a-price span.a-offscreen",
    ".a-price .a-offscreen",
    "#corePrice_feature_div span.a-offscreen",
    "#priceblock_ourprice",
    "#priceblock_dealprice",
    "#price_inside_buybox"
  ]

  @impl true
  def can_handle?(url) do
    uri = URI.parse(url)

    uri.host in [
      "www.amazon.com",
      "amazon.com",
      "www.amazon.ca",
      "amazon.ca",
      "www.amazon.co.uk",
      "amazon.co.uk"
    ]
  end

  @impl true
  def scrape_price(url) do
    # Add random delay to be polite
    :timer.sleep(:rand.uniform(2000) + 1000)

    headers = build_headers()

    case Req.get(url, headers: headers, retry: :transient, max_retries: 3) do
      {:ok, %{status: 200, body: body}} ->
        parse_price(body)

      {:ok, %{status: status}} ->
        Logger.warning("Amazon returned status #{status} for #{url}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("Failed to fetch Amazon URL #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_headers do
    [
      {"user-agent", Enum.random(@user_agents)},
      {"accept",
       "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"},
      {"accept-language", "en-US,en;q=0.9"},
      {"accept-encoding", "gzip, deflate, br"},
      {"dnt", "1"},
      {"connection", "keep-alive"},
      {"upgrade-insecure-requests", "1"},
      {"sec-fetch-dest", "document"},
      {"sec-fetch-mode", "navigate"},
      {"sec-fetch-site", "none"},
      {"cache-control", "max-age=0"}
    ]
  end

  defp parse_price(html) do
    with {:ok, document} <- Floki.parse_document(html),
         {:ok, price} <- extract_price(document) do
      {:ok,
       %{
         price: price,
         available: true,
         metadata: %{
           scraped_at: DateTime.utc_now(),
           scraper: "simple_http"
         }
       }}
    else
      {:error, :price_not_found} ->
        # Check if product is unavailable
        case check_availability(html) do
          false ->
            {:ok,
             %{
               price: nil,
               available: false,
               metadata: %{
                 scraped_at: DateTime.utc_now(),
                 scraper: "simple_http",
                 reason: "unavailable"
               }
             }}

          true ->
            {:error, :price_not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_price(document) do
    # Try each selector until we find a price
    result =
      Enum.find_value(@price_selectors, fn selector ->
        case Floki.find(document, selector) do
          [] ->
            nil

          [first_element | _] ->
            # Only use the first matching element to avoid concatenation issues
            text = Floki.text(first_element)
            parse_price_text(text)
        end
      end)

    case result do
      nil -> {:error, :price_not_found}
      price -> {:ok, price}
    end
  end

  defp parse_price_text(text) do
    # Remove currency symbols, commas, and whitespace
    cleaned =
      text
      |> String.replace(~r/[$£€,\s]/, "")
      |> String.trim()

    case Decimal.parse(cleaned) do
      {decimal, _} -> decimal
      :error -> nil
    end
  end

  defp check_availability(html) do
    # Simple check - if we see "unavailable" or "out of stock" text, product is unavailable
    unavailable_patterns = [
      "currently unavailable",
      "out of stock",
      "not available",
      "temporarily out of stock"
    ]

    not Enum.any?(unavailable_patterns, fn pattern ->
      String.contains?(String.downcase(html), pattern)
    end)
  end
end
