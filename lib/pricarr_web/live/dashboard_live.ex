defmodule PricarrWeb.DashboardLive do
  use PricarrWeb, :live_view

  alias Pricarr.Products
  alias Pricarr.Alerts

  @impl true
  def mount(_params, _session, socket) do
    products = Products.list_products()
    alert_rules = Alerts.list_alert_rules()
    alert_logs = Alerts.list_alert_logs(limit: 10)

    {:ok,
     assign(socket,
       products: products,
       alert_rules: alert_rules,
       alert_logs: alert_logs,
       page_title: "Dashboard"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h1 class="text-3xl font-bold text-base-content">Price Tracker Dashboard</h1>
        <p class="mt-2 text-sm text-base-content/70">
          Monitor prices and get alerts when your products drop in price
        </p>
      </div>

      <!-- Stats -->
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-3">
        <div class="bg-base-200 overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-cube" class="h-6 w-6 text-base-content/50" />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-base-content/70 truncate">
                    Total Products
                  </dt>
                  <dd class="text-3xl font-semibold text-base-content">
                    <%= length(@products) %>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-base-200 overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-bell-alert" class="h-6 w-6 text-base-content/50" />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-base-content/70 truncate">
                    Active Alerts
                  </dt>
                  <dd class="text-3xl font-semibold text-base-content">
                    <%= Enum.count(@alert_rules, & &1.enabled) %>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-base-200 overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <.icon name="hero-link" class="h-6 w-6 text-base-content/50" />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-base-content/70 truncate">
                    Tracked URLs
                  </dt>
                  <dd class="text-3xl font-semibold text-base-content">
                    <%= @products |> Enum.map(&length(&1.product_urls)) |> Enum.sum() %>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Recent Products -->
      <div class="bg-base-200 shadow rounded-lg">
        <div class="px-4 py-5 sm:px-6 border-b border-base-200">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-medium text-base-content">Products</h2>
            <.link navigate={~p"/products/new"} class="btn btn-primary">
              Add Product
            </.link>
          </div>
        </div>
        <div class="px-4 py-5 sm:p-6">
          <%= if Enum.empty?(@products) do %>
            <div class="text-center py-12">
              <.icon name="hero-cube" class="mx-auto h-12 w-12 text-base-content/50" />
              <h3 class="mt-2 text-sm font-medium text-base-content">No products</h3>
              <p class="mt-1 text-sm text-base-content/70">
                Get started by adding a product to track.
              </p>
              <div class="mt-6">
                <.link navigate={~p"/products/new"} class="btn btn-primary">
                  Add Product
                </.link>
              </div>
            </div>
          <% else %>
            <div class="space-y-4">
              <%= for product <- @products do %>
                <div class="border border-base-300 rounded-lg p-4 hover:bg-base-300">
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
                        <%= if best_price = get_best_price(product) do %>
                          <span class="font-semibold text-green-600">
                            Best: $<%= best_price %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                    <div class="ml-4">
                      <.link navigate={~p"/products/#{product.id}"} class="btn btn-sm">
                        View
                      </.link>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Recent Alerts -->
      <%= if not Enum.empty?(@alert_logs) do %>
        <div class="bg-base-100 shadow rounded-lg">
          <div class="px-4 py-5 sm:px-6 border-b border-base-200">
            <h2 class="text-lg font-medium text-base-content">Recent Alerts</h2>
          </div>
          <div class="px-4 py-5 sm:p-6">
            <div class="space-y-3">
              <%= for log <- @alert_logs do %>
                <div class="flex items-center justify-between py-2 border-b border-base-200 last:border-b-0">
                  <div class="flex-1">
                    <div class="text-sm font-medium text-base-content">
                      <%= log.alert_rule.name %>
                    </div>
                    <div class="text-sm text-base-content/70">
                      Price: $<%= log.triggered_price %>
                      <%= if log.previous_price do %>
                        (was $<%= log.previous_price %>)
                      <% end %>
                    </div>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class={[
                      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                      status_color(log.notification_status)
                    ]}>
                      <%= log.notification_status %>
                    </span>
                    <span class="text-xs text-base-content/70">
                      <%= relative_time(log.inserted_at) %>
                    </span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_best_price(product) do
    product.product_urls
    |> Enum.filter(& &1.last_price)
    |> Enum.map(& &1.last_price)
    |> case do
      [] -> nil
      prices -> Enum.min(prices)
    end
  end

  defp status_color(:sent), do: "bg-green-100 text-green-800"
  defp status_color(:failed), do: "bg-red-100 text-red-800"
  defp status_color(:skipped), do: "bg-yellow-100 text-yellow-800"

  defp relative_time(datetime) do
    Timex.from_now(datetime)
  end
end
