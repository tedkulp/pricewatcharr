defmodule Pricarr.Products do
  @moduledoc """
  The Products context.
  """

  import Ecto.Query, warn: false
  alias Pricarr.Repo

  alias Pricarr.Products.{Product, ProductUrl, PriceHistory}

  ## Products

  @doc """
  Returns the list of products.
  """
  def list_products do
    Repo.all(Product)
    |> Repo.preload(:product_urls)
  end

  @doc """
  Gets a single product.
  """
  def get_product!(id) do
    Repo.get!(Product, id)
    |> Repo.preload(product_urls: [:price_histories])
  end

  @doc """
  Creates a product.
  """
  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a product.
  """
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a product.
  """
  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking product changes.
  """
  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end

  ## Product URLs

  @doc """
  Returns the list of product_urls for a product.
  """
  def list_product_urls(product_id) do
    ProductUrl
    |> where([pu], pu.product_id == ^product_id)
    |> Repo.all()
  end

  @doc """
  Gets a single product_url.
  """
  def get_product_url!(id) do
    Repo.get!(ProductUrl, id)
    |> Repo.preload([:product, :price_histories])
  end

  @doc """
  Creates a product_url.
  """
  def create_product_url(attrs \\ %{}) do
    %ProductUrl{}
    |> ProductUrl.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a product_url.
  """
  def update_product_url(%ProductUrl{} = product_url, attrs) do
    product_url
    |> ProductUrl.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a product_url.
  """
  def delete_product_url(%ProductUrl{} = product_url) do
    Repo.delete(product_url)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking product_url changes.
  """
  def change_product_url(%ProductUrl{} = product_url, attrs \\ %{}) do
    ProductUrl.changeset(product_url, attrs)
  end

  @doc """
  Returns all active product URLs.
  """
  def list_active_urls do
    ProductUrl
    |> where([pu], pu.active == true)
    |> Repo.all()
  end

  ## Price History

  @doc """
  Returns the price history for a product URL.
  """
  def list_price_history(product_url_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    PriceHistory
    |> where([ph], ph.product_url_id == ^product_url_id)
    |> order_by([ph], desc: ph.checked_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Creates a price_history entry.
  """
  def create_price_history(attrs \\ %{}) do
    %PriceHistory{}
    |> PriceHistory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets the lowest current price across all URLs for a product.
  """
  def get_lowest_current_price(product_id) do
    ProductUrl
    |> where([pu], pu.product_id == ^product_id and pu.active == true)
    |> where([pu], not is_nil(pu.last_price))
    |> select([pu], %{
      url: pu.url,
      price: pu.last_price,
      retailer: pu.retailer,
      checked_at: pu.last_checked_at
    })
    |> order_by([pu], asc: pu.last_price)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets price history for all URLs of a product, formatted for charting.
  Returns a list of maps with :retailer, :checked_at, and :price keys.
  """
  def get_price_history_for_chart(product_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    since = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    PriceHistory
    |> join(:inner, [ph], pu in ProductUrl, on: ph.product_url_id == pu.id)
    |> where([ph, pu], pu.product_id == ^product_id)
    |> where([ph], ph.checked_at >= ^since)
    |> where([ph], not is_nil(ph.price))
    |> select([ph, pu], %{
      retailer: pu.retailer,
      checked_at: ph.checked_at,
      price: ph.price
    })
    |> order_by([ph], asc: ph.checked_at)
    |> Repo.all()
  end
end
