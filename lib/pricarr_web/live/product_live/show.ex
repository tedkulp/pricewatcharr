defmodule PricarrWeb.ProductLive.Show do
  use PricarrWeb, :live_view

  alias Pricarr.Alerts
  alias Pricarr.Products
  alias Pricarr.Products.ProductUrl
  alias Pricarr.Workers.PriceChecker

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    product_id = String.to_integer(id)
    product = Products.get_product!(product_id)
    product_urls = Products.list_product_urls(product_id)
    price_history = Products.get_price_history_for_chart(product_id)
    alert_rules = Alerts.list_alert_rules_for_product(product_id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action, product))
     |> assign(:product, product)
     |> assign(:product_urls, product_urls)
     |> assign(:price_history, price_history)
     |> assign(:alert_rules, alert_rules)
     |> assign(:show_url_form, false)
     |> assign(:url_form, to_form(Products.change_product_url(%ProductUrl{})))}
  end

  defp page_title(:show, product), do: product.name
  defp page_title(:edit, product), do: "Edit #{product.name}"

  @impl true
  def handle_event("add_url", _, socket) do
    {:noreply, assign(socket, :show_url_form, true)}
  end

  @impl true
  def handle_event("cancel_url", _, socket) do
    {:noreply,
     socket
     |> assign(:show_url_form, false)
     |> assign(:url_form, to_form(Products.change_product_url(%ProductUrl{})))}
  end

  @impl true
  def handle_event("validate_url", %{"product_url" => params}, socket) do
    changeset =
      %ProductUrl{}
      |> Products.change_product_url(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :url_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_url", %{"product_url" => params}, socket) do
    params = Map.put(params, "product_id", socket.assigns.product.id)

    case Products.create_product_url(params) do
      {:ok, product_url} ->
        # Schedule initial price check
        PriceChecker.schedule_check(product_url.id)
        product_urls = Products.list_product_urls(socket.assigns.product.id)

        {:noreply,
         socket
         |> assign(:product_urls, product_urls)
         |> assign(:show_url_form, false)
         |> assign(:url_form, to_form(Products.change_product_url(%ProductUrl{})))
         |> put_flash(:info, "URL added successfully. Price check scheduled.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :url_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete_url", %{"id" => id}, socket) do
    product_url = Products.get_product_url!(id)
    {:ok, _} = Products.delete_product_url(product_url)

    product_urls = Products.list_product_urls(socket.assigns.product.id)

    {:noreply,
     socket
     |> assign(:product_urls, product_urls)
     |> put_flash(:info, "URL deleted successfully")}
  end

  @impl true
  def handle_event("check_now", %{"id" => id}, socket) do
    {:ok, _job} = PriceChecker.schedule_check(String.to_integer(id))

    {:noreply, put_flash(socket, :info, "Price check scheduled")}
  end

  @impl true
  def handle_info({PricarrWeb.ProductLive.FormComponent, {:saved, product}}, socket) do
    {:noreply,
     socket
     |> assign(:product, product)
     |> assign(:page_title, page_title(socket.assigns.live_action, product))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="sm:flex sm:items-start sm:justify-between">
        <div>
          <.link navigate={~p"/products"} class="text-sm text-base-content/70 hover:text-base-content/80 mb-2 inline-block">
            ← Back to Products
          </.link>
          <h1 class="text-3xl font-bold text-base-content"><%= @product.name %></h1>
          <%= if @product.description do %>
            <p class="mt-2 text-sm text-base-content/70"><%= @product.description %></p>
          <% end %>
        </div>
        <div class="mt-4 sm:mt-0">
          <.link patch={~p"/products/#{@product.id}/edit"} class="btn btn-sm">
            Edit Product
          </.link>
        </div>
      </div>

      <!-- Best Price -->
      <%= if best_price = Products.get_lowest_current_price(@product.id) do %>
        <div class="bg-green-50 border border-green-200 rounded-lg p-4">
          <div class="flex items-center">
            <.icon name="hero-currency-dollar" class="h-6 w-6 text-green-600 mr-3" />
            <div>
              <h3 class="text-lg font-semibold text-green-900">
                Best Price: $<%= format_price(best_price.price) %>
              </h3>
              <p class="text-sm text-green-700">
                <%= best_price.retailer %> • Last checked: <%= format_datetime(best_price.checked_at) %>
              </p>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Price History Chart -->
      <div class="bg-base-200 shadow rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-base-200">
          <h2 class="text-lg font-medium text-base-900">Price History (Last 30 Days)</h2>
        </div>
        <div class="p-4">
          <.price_chart data={@price_history} width={800} height={300} />
        </div>
      </div>

      <!-- Product URLs -->
      <div class="bg-base-200 shadow rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-base-200">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-medium text-base-content">Tracked URLs</h2>
            <button phx-click={JS.push("add_url")} class="btn btn-sm btn-primary">
              <.icon name="hero-plus" class="h-4 w-4 mr-1" /> Add URL
            </button>
          </div>
        </div>
        <div class="divide-y divide-base-200">
          <%= if Enum.empty?(@product_urls) do %>
            <div class="px-4 py-12 text-center">
              <.icon name="hero-link" class="mx-auto h-12 w-12 text-base-content/50" />
              <h3 class="mt-2 text-sm font-medium text-base-content">No URLs tracked</h3>
              <p class="mt-1 text-sm text-base-content/70">
                Add a URL to start tracking prices for this product.
              </p>
            </div>
          <% else %>
            <%= for url <- @product_urls do %>
              <div class="px-4 py-4 hover:bg-base-300">
                <div class="flex items-start justify-between">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2">
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        <%= url.retailer %>
                      </span>
                      <span :if={!url.active} class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-base-200 text-base-content">
                        Inactive
                      </span>
                    </div>
                    <div class="mt-2 text-sm text-base-content break-all">
                      <a href={url.url} target="_blank" class="hover:text-blue-600">
                        <%= url.url %>
                      </a>
                    </div>
                    <div class="mt-2 flex flex-wrap gap-4 text-sm text-base-content/70">
                      <%= if url.last_price do %>
                        <span class="font-semibold text-base-content">
                          $<%= format_price(url.last_price) %>
                        </span>
                      <% end %>
                      <%= if url.last_checked_at do %>
                        <span>
                          Checked: <%= format_datetime(url.last_checked_at) %>
                        </span>
                      <% else %>
                        <span class="text-yellow-600">Not checked yet</span>
                      <% end %>
                      <span>
                        Check every <%= url.check_interval_minutes %> min
                      </span>
                    </div>
                  </div>
                  <div class="ml-4 flex items-center gap-2">
                    <button
                      phx-click="check_now"
                      phx-value-id={url.id}
                      class="btn btn-sm"
                    >
                      Check Now
                    </button>
                    <button
                      phx-click="delete_url"
                      phx-value-id={url.id}
                      data-confirm="Are you sure? This will delete all price history for this URL."
                      class="btn btn-sm btn-danger"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <!-- Alerts -->
      <div class="bg-base-200 shadow rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-base-200">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-medium text-base-content">Price Alerts</h2>
            <.link navigate={~p"/alerts/new?product_id=#{@product.id}"} class="btn btn-sm btn-primary">
              <.icon name="hero-plus" class="h-4 w-4 mr-1" /> Add Alert
            </.link>
          </div>
        </div>
        <div class="divide-y divide-base-200">
          <%= if Enum.empty?(@alert_rules) do %>
            <div class="px-4 py-12 text-center">
              <.icon name="hero-bell" class="mx-auto h-12 w-12 text-base-content/50" />
              <h3 class="mt-2 text-sm font-medium text-base-content">No alerts configured</h3>
              <p class="mt-1 text-sm text-base-content/70">
                Add an alert to get notified when the price drops.
              </p>
            </div>
          <% else %>
            <%= for alert <- @alert_rules do %>
              <div class="px-4 py-4 hover:bg-base-300">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <div class="flex items-center gap-2">
                      <h3 class="text-sm font-medium text-base-content"><%= alert.name %></h3>
                      <span class={[
                        "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
                        if(alert.enabled, do: "bg-green-100 text-green-800", else: "bg-base-200 text-base-content")
                      ]}>
                        <%= if alert.enabled, do: "Active", else: "Inactive" %>
                      </span>
                    </div>
                    <p class="mt-1 text-sm text-base-content/70">
                      <%= format_trigger(alert) %>
                    </p>
                    <%= if alert.last_triggered_at do %>
                      <p class="mt-1 text-xs text-base-content/50">
                        Last triggered: <%= format_datetime(alert.last_triggered_at) %>
                      </p>
                    <% end %>
                  </div>
                  <div class="ml-4">
                    <.link navigate={~p"/alerts/#{alert.id}/edit"} class="btn btn-sm">
                      Edit
                    </.link>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Add URL Modal -->
    <.modal :if={@show_url_form} id="url-modal" show on_cancel={JS.push("cancel_url")}>
      <.header>
        Add URL to Track
        <:subtitle>Enter the product URL and check settings</:subtitle>
      </.header>

      <.simple_form
        for={@url_form}
        id="url-form"
        phx-change="validate_url"
        phx-submit="save_url"
      >
        <.input field={@url_form[:url]} type="text" label="Product URL" placeholder="https://www.amazon.com/dp/..." required />
        <.input
          field={@url_form[:retailer]}
          type="select"
          label="Retailer"
          options={[{"Amazon", "Amazon"}]}
          required
        />
        <.input field={@url_form[:check_interval_minutes]} type="number" label="Check Interval (minutes)" required />
        <.input field={@url_form[:active]} type="checkbox" label="Active" />
        <:actions>
          <button type="button" phx-click="cancel_url" class="btn">Cancel</button>
          <.button phx-disable-with="Saving...">Add URL</.button>
        </:actions>
      </.simple_form>
    </.modal>

    <!-- Edit Product Modal -->
    <.modal
      :if={@live_action == :edit}
      id="product-modal"
      show
      on_cancel={JS.patch(~p"/products/#{@product.id}")}
    >
      <.live_component
        module={PricarrWeb.ProductLive.FormComponent}
        id={@product.id}
        title={@page_title}
        action={@live_action}
        product={@product}
        patch={~p"/products/#{@product.id}"}
      />
    </.modal>
    """
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    Timex.format!(datetime, "{relative}", :relative)
  end

  defp format_price(nil), do: "N/A"

  defp format_price(price) do
    price
    |> Decimal.round(2)
    |> Decimal.to_string()
  end

  defp format_trigger(alert) do
    case alert.trigger_type do
      :below_price ->
        "When price drops below $#{alert.target_price}"

      :percentage_drop ->
        "When price drops by #{alert.percentage_threshold}%"

      :both ->
        "Below $#{alert.target_price} or #{alert.percentage_threshold}% drop"
    end
  end
end
