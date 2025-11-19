defmodule Pricarr.Products.PriceHistory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "price_histories" do
    field :price, :decimal
    field :available, :boolean, default: true
    field :checked_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :product_url, Pricarr.Products.ProductUrl

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(price_history, attrs) do
    price_history
    |> cast(attrs, [:price, :available, :checked_at, :metadata, :product_url_id])
    |> validate_required([:checked_at, :product_url_id])
    |> foreign_key_constraint(:product_url_id)
  end
end
