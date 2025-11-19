defmodule PricarrWeb.AlertLive.FormComponent do
  use PricarrWeb, :live_component

  alias Pricarr.Alerts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Configure when and how you want to be notified about price drops.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="alert-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Alert Name" required />

        <.input
          field={@form[:product_id]}
          type="select"
          label="Product"
          options={Enum.map(@products, &{&1.name, &1.id})}
          required
        />

        <.input
          field={@form[:trigger_type]}
          type="select"
          label="Trigger Type"
          options={[
            {"Below target price", :below_price},
            {"Percentage drop", :percentage_drop},
            {"Either condition", :both}
          ]}
          required
        />

        <.input
          field={@form[:target_price]}
          type="number"
          label="Target Price ($)"
          step="0.01"
          phx-debounce="300"
        />

        <.input
          field={@form[:percentage_threshold]}
          type="number"
          label="Percentage Drop Threshold (%)"
          step="0.1"
          phx-debounce="300"
        />

        <.input
          field={@form[:cooldown_minutes]}
          type="number"
          label="Cooldown (minutes)"
          required
        />

        <div class="space-y-2">
          <label class="block text-sm font-medium text-base-content/80">
            Notification URLs (Apprise format)
          </label>
          <div class="space-y-2" id="apprise-urls">
            <%= for {url, i} <- Enum.with_index(@apprise_urls) do %>
              <div class="flex gap-2">
                <input
                  type="text"
                  name={"apprise_url_#{i}"}
                  value={url}
                  phx-target={@myself}
                  phx-change="update_url"
                  phx-value-index={i}
                  placeholder="e.g., mailto://user:pass@gmail.com"
                  class="flex-1 rounded-md border-base-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                />
                <button
                  type="button"
                  phx-click="remove_url"
                  phx-value-index={i}
                  phx-target={@myself}
                  class="btn btn-sm btn-danger"
                >
                  Remove
                </button>
              </div>
            <% end %>
          </div>
          <button
            type="button"
            phx-click="add_url"
            phx-target={@myself}
            class="btn btn-sm"
          >
            + Add Notification URL
          </button>
          <p class="text-xs text-base-content/70 mt-1">
            Examples: mailto://user:pass@gmail.com, discord://webhook_id/token, ntfy://topic
          </p>
        </div>

        <.input field={@form[:enabled]} type="checkbox" label="Enabled" />

        <:actions>
          <.button phx-disable-with="Saving...">Save Alert</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{alert_rule: alert_rule} = assigns, socket) do
    apprise_urls = alert_rule.apprise_urls || []

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:apprise_urls, if(Enum.empty?(apprise_urls), do: [""], else: apprise_urls))
     |> assign_new(:form, fn ->
       to_form(Alerts.change_alert_rule(alert_rule))
     end)}
  end

  @impl true
  def handle_event("validate", %{"alert_rule" => alert_params}, socket) do
    changeset = Alerts.change_alert_rule(socket.assigns.alert_rule, alert_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("add_url", _, socket) do
    {:noreply, assign(socket, :apprise_urls, socket.assigns.apprise_urls ++ [""])}
  end

  def handle_event("remove_url", %{"index" => index}, socket) do
    index = String.to_integer(index)
    urls = List.delete_at(socket.assigns.apprise_urls, index)
    {:noreply, assign(socket, :apprise_urls, urls)}
  end

  def handle_event("update_url", params, socket) do
    # Extract the target field name to find the index
    [target_field] = params["_target"]

    # Parse the index from the field name (e.g., "apprise_url_0" -> 0)
    index =
      target_field
      |> String.replace("apprise_url_", "")
      |> String.to_integer()

    value = params[target_field]
    urls = List.replace_at(socket.assigns.apprise_urls, index, value)
    {:noreply, assign(socket, :apprise_urls, urls)}
  end

  def handle_event("save", %{"alert_rule" => alert_params}, socket) do
    # Filter out empty URLs
    apprise_urls = Enum.reject(socket.assigns.apprise_urls, &(&1 == ""))
    alert_params = Map.put(alert_params, "apprise_urls", apprise_urls)

    save_alert_rule(socket, socket.assigns.action, alert_params)
  end

  defp save_alert_rule(socket, :edit, alert_params) do
    case Alerts.update_alert_rule(socket.assigns.alert_rule, alert_params) do
      {:ok, alert_rule} ->
        notify_parent({:saved, alert_rule})

        {:noreply,
         socket
         |> put_flash(:info, "Alert rule updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_alert_rule(socket, :new, alert_params) do
    case Alerts.create_alert_rule(alert_params) do
      {:ok, alert_rule} ->
        notify_parent({:saved, alert_rule})

        {:noreply,
         socket
         |> put_flash(:info, "Alert rule created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
