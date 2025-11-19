defmodule PricarrWeb.ProductLive.Index do
  use PricarrWeb, :live_view

  alias Pricarr.Products
  alias Pricarr.Products.Product

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :products, Products.list_products())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Products")
    |> assign(:product, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Product")
    |> assign(:product, %Product{})
  end

  @impl true
  def handle_info({PricarrWeb.ProductLive.FormComponent, {:saved, product}}, socket) do
    {:noreply, stream_insert(socket, :products, product)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    product = Products.get_product!(id)
    {:ok, _} = Products.delete_product(product)

    {:noreply, stream_delete(socket, :products, product)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 class="text-3xl font-bold text-base-content">Products</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Manage products you want to track for price changes
          </p>
        </div>
        <div class="mt-4 sm:mt-0">
          <.link patch={~p"/products/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="h-5 w-5 mr-2" /> Add Product
          </.link>
        </div>
      </div>

      <div class="bg-base-200 shadow rounded-lg">
        <div id="products" phx-update="stream" class="divide-y divide-base-200">
          <%= for {id, product} <- @streams.products do %>
            <div id={id} class="p-6 hover:bg-base-300">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <h3 class="text-lg font-medium text-base-content">
                    <.link navigate={~p"/products/#{product.id}"} class="hover:text-blue-600">
                      <%= product.name %>
                    </.link>
                  </h3>
                  <%= if product.description do %>
                    <p class="mt-1 text-sm text-base-content/70"><%= product.description %></p>
                  <% end %>
                  <div class="mt-2 flex items-center gap-4 text-sm text-base-content/70">
                    <span>
                      <.icon name="hero-link" class="h-4 w-4 inline" />
                      <%= length(product.product_urls) %> URL(s)
                    </span>
                    <span :if={!product.active} class="text-red-600">
                      Inactive
                    </span>
                  </div>
                </div>
                <div class="ml-4 flex items-center gap-2">
                  <.link navigate={~p"/products/#{product.id}"} class="btn btn-sm">
                    View
                  </.link>
                  <.link
                    phx-click={JS.push("delete", value: %{id: product.id})}
                    data-confirm="Are you sure you want to delete this product? This will also delete all URLs and price history."
                    class="btn btn-sm btn-danger"
                  >
                    Delete
                  </.link>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action == :new}
      id="product-modal"
      show
      on_cancel={JS.patch(~p"/products")}
    >
      <.live_component
        module={PricarrWeb.ProductLive.FormComponent}
        id={@product.id || :new}
        title={@page_title}
        action={@live_action}
        product={@product}
        patch={~p"/products"}
      />
    </.modal>
    """
  end
end
