defmodule PricarrWeb.AlertLive.Index do
  use PricarrWeb, :live_view

  alias Pricarr.Alerts
  alias Pricarr.Alerts.AlertRule
  alias Pricarr.Alerts.Notifier
  alias Pricarr.Products

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:products, Products.list_products())
     |> stream(:alert_rules, Alerts.list_alert_rules())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Alert Rules")
    |> assign(:alert_rule, nil)
  end

  defp apply_action(socket, :new, params) do
    product_id = params["product_id"]

    socket
    |> assign(:page_title, "New Alert Rule")
    |> assign(:alert_rule, %AlertRule{
      product_id: product_id && String.to_integer(product_id),
      apprise_urls: []
    })
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Alert Rule")
    |> assign(:alert_rule, Alerts.get_alert_rule!(id))
  end

  @impl true
  def handle_info({PricarrWeb.AlertLive.FormComponent, {:saved, alert_rule}}, socket) do
    {:noreply, stream_insert(socket, :alert_rules, alert_rule)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    alert_rule = Alerts.get_alert_rule!(id)
    {:ok, _} = Alerts.delete_alert_rule(alert_rule)

    {:noreply, stream_delete(socket, :alert_rules, alert_rule)}
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    alert_rule = Alerts.get_alert_rule!(id)
    {:ok, updated} = Alerts.update_alert_rule(alert_rule, %{enabled: !alert_rule.enabled})

    {:noreply, stream_insert(socket, :alert_rules, updated)}
  end

  @impl true
  def handle_event("test", %{"id" => id}, socket) do
    alert_rule = Alerts.get_alert_rule!(id)

    case Notifier.send_test_notification(alert_rule) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Test notification sent successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to send test notification")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 class="text-3xl font-bold text-base-content">Alert Rules</h1>
          <p class="mt-2 text-sm text-base-content/70">
            Get notified when prices drop below your target
          </p>
        </div>
        <div class="mt-4 sm:mt-0">
          <.link patch={~p"/alerts/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="h-5 w-5 mr-2" /> Create Alert
          </.link>
        </div>
      </div>

      <div class="bg-base-200 shadow rounded-lg hover:bg-base-300">
        <div id="alert_rules" phx-update="stream" class="divide-y divide-base-200">
          <%= for {id, alert} <- @streams.alert_rules do %>
            <div id={id} class="p-6">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-3">
                    <h3 class="text-lg font-medium text-base-content">
                      <%= alert.name %>
                    </h3>
                    <button
                      phx-click="toggle"
                      phx-value-id={alert.id}
                      class={[
                        "relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2",
                        if(alert.enabled, do: "bg-blue-600", else: "bg-base-200")
                      ]}
                    >
                      <span class={[
                        "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-base-100 shadow ring-0 transition duration-200 ease-in-out",
                        if(alert.enabled, do: "translate-x-5", else: "translate-x-0")
                      ]} />
                    </button>
                  </div>

                  <p class="mt-1 text-sm text-base-content/70">
                    Product: <span class="font-medium"><%= alert.product.name %></span>
                  </p>

                  <div class="mt-2 space-y-1 text-sm text-base-content/70">
                    <div>
                      <span class="font-medium">Trigger:</span>
                      <%= format_trigger(alert) %>
                    </div>
                    <div>
                      <span class="font-medium">Cooldown:</span>
                      <%= alert.cooldown_minutes %> minutes
                    </div>
                    <div>
                      <span class="font-medium">Notifications:</span>
                      <%= length(alert.apprise_urls) %> channel(s)
                    </div>
                    <%= if alert.last_triggered_at do %>
                      <div class="text-green-600">
                        Last triggered: <%= Timex.from_now(alert.last_triggered_at) %>
                      </div>
                    <% end %>
                  </div>
                </div>

                <div class="ml-4 flex items-center gap-2">
                  <button
                    phx-click="test"
                    phx-value-id={alert.id}
                    class="btn btn-sm"
                  >
                    Test
                  </button>
                  <.link patch={~p"/alerts/#{alert.id}/edit"} class="btn btn-sm">
                    Edit
                  </.link>
                  <button
                    phx-click="delete"
                    phx-value-id={alert.id}
                    data-confirm="Are you sure you want to delete this alert?"
                    class="btn btn-sm btn-danger"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="alert-modal"
      show
      on_cancel={JS.patch(~p"/alerts")}
    >
      <.live_component
        module={PricarrWeb.AlertLive.FormComponent}
        id={@alert_rule.id || :new}
        title={@page_title}
        action={@live_action}
        alert_rule={@alert_rule}
        products={@products}
        patch={~p"/alerts"}
      />
    </.modal>
    """
  end

  defp format_trigger(alert) do
    case alert.trigger_type do
      :below_price ->
        "When price drops below $#{alert.target_price}"

      :percentage_drop ->
        "When price drops by #{alert.percentage_threshold}% or more"

      :both ->
        "When price drops below $#{alert.target_price} OR by #{alert.percentage_threshold}%"
    end
  end
end
