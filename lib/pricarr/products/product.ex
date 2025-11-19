defmodule Pricarr.Products.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :description, :string
    field :image_url, :string
    field :active, :boolean, default: true

    has_many :product_urls, Pricarr.Products.ProductUrl
    has_many :alert_rules, Pricarr.Alerts.AlertRule

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :description, :image_url, :active])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
  end
end
