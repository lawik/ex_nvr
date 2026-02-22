defmodule ExNVRWeb.EventConfigListLive do
  @moduledoc false

  use ExNVRWeb, :live_view

  alias ExNVR.Events

  def render(assigns) do
    ~H"""
    <div class="grow e-m-8">
      <div class="ml-4 sm:ml-0">
        <.link href={~p"/event-configs/new"}>
          <.button><.icon name="hero-plus-solid" class="h-4 w-4" /> Add Event Config</.button>
        </.link>
      </div>

      <.table id="event-configs" rows={@configs}>
        <:col :let={config} label="Name">{config.name}</:col>
        <:col :let={config} label="Sources">{length(config.event_source_configs)}</:col>
        <:col :let={config} label="Targets">{length(config.event_target_configs)}</:col>
        <:action :let={config}>
          <.three_dot
            id={"dropdownMenuIconButton_#{config.id}"}
            dropdown_id={"dropdownDots_#{config.id}"}
          />
          <div
            id={"dropdownDots_#{config.id}"}
            class="z-10 hidden text-left bg-white divide-y divide-gray-100 rounded-lg shadow w-44 dark:bg-gray-700 dark:divide-gray-600"
          >
            <ul
              class="py-2 text-sm text-gray-700 dark:text-gray-200"
              aria-labelledby={"dropdownMenuIconButton_#{config.id}"}
            >
              <li>
                <.link
                  href={~p"/event-configs/#{config.id}"}
                  class="block px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white"
                >
                  Update
                </.link>
              </li>
              <li>
                <.link
                  phx-click={show_modal("delete-config-modal-#{config.id}")}
                  class="block px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white"
                >
                  Delete
                </.link>
              </li>
            </ul>
          </div>
        </:action>
        <:action :let={config}>
          <.modal id={"delete-config-modal-#{config.id}"}>
            <div class="bg-white dark:bg-gray-800 m-8 rounded">
              <h2 class="text-xl text-white font-bold mb-4">
                Are you sure you want to delete this event config?
              </h2>
              <div class="mt-4">
                <button
                  phx-click="delete-config"
                  phx-value-config_id={config.id}
                  class="bg-red-500 hover:bg-red-600 text-white py-2 px-4 rounded mr-4"
                >
                  Confirm
                </button>
                <button
                  phx-click={hide_modal("delete-config-modal-#{config.id}")}
                  class="bg-gray-300 hover:bg-gray-400 text-gray-800 py-2 px-4 rounded"
                >
                  Cancel
                </button>
              </div>
            </div>
          </.modal>
        </:action>
      </.table>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, configs: Events.list_event_configs())}
  end

  def handle_event("delete-config", %{"config_id" => id}, socket) do
    config = Events.get_event_config!(id)

    case Events.delete_event_config(config) do
      :ok ->
        socket
        |> assign(configs: Events.list_event_configs())
        |> put_flash(:info, "Event config #{config.name} deleted")
        |> then(&{:noreply, &1})

      _other ->
        socket
        |> put_flash(:error, "Could not delete event config")
        |> then(&{:noreply, &1})
    end
  end
end
