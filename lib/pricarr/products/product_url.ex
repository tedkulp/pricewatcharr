defmodule Pricarr.Products.ProductUrl do
  use Ecto.Schema
  import Ecto.Changeset

  schema "product_urls" do
    field :url, :string
    field :retailer, :string
    field :check_interval_minutes, :integer, default: 60
    field :last_checked_at, :utc_datetime
    field :last_price, :decimal
    field :last_available, :boolean, default: true
    field :active, :boolean, default: true

    belongs_to :product, Pricarr.Products.Product
    has_many :price_histories, Pricarr.Products.PriceHistory
    has_many :alert_logs, Pricarr.Alerts.AlertLog

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product_url, attrs) do
    product_url
    |> cast(attrs, [
      :url,
      :retailer,
      :check_interval_minutes,
      :last_checked_at,
      :last_price,
      :last_available,
      :active,
      :product_id
    ])
    |> validate_required([:url, :retailer, :product_id])
    |> validate_number(:check_interval_minutes, greater_than: 0)
    |> foreign_key_constraint(:product_id)
  end
end
