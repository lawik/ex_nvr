defmodule ExNVRWeb.EventConfigLive do
  @moduledoc false

  use ExNVRWeb, :live_view

  alias ExNVR.{Events, Inference}
  alias ExNVR.Events.{EventConfig, EventSources, EventTargets}

  def render(assigns) do
    ~H"""
    <div class="grow mx-auto max-w-5xl e-my-6">
      <div class="px-6 lg:px-8 bg-gray-300 dark:bg-gray-800">
        <h3
          :if={is_nil(@config.id)}
          class="mb-4 text-xl text-center font-medium text-black dark:text-white"
        >
          Create a new event config
        </h3>
        <h3
          :if={@config.id}
          class="mb-4 text-xl text-center font-medium text-black dark:text-white"
        >
          Update event config
        </h3>
        <div class="max-w-lg mx-auto">
          <.simple_form
            id="event_config_form"
            for={@config_form}
            class="space-y-6"
            phx-change="validate"
            phx-submit="save_config"
          >
            <.input
              field={@config_form[:name]}
              id="config_name"
              type="text"
              label="Name"
              required
            />
            <:actions>
              <.button :if={is_nil(@config.id)} class="w-full" phx-disable-with="Creating...">
                Create
              </.button>
              <.button :if={@config.id} class="w-full" phx-disable-with="Updating...">
                Update
              </.button>
            </:actions>
          </.simple_form>
        </div>

        <%!-- Sources and Targets only shown after config is persisted --%>
        <div :if={@config.id}>
          <%!-- Event Sources --%>
          <div class="mb-8">
            <div class="relative flex py-5 items-center">
              <span class="flex-shrink mr-4 text-black dark:text-white font-medium">
                Event Sources
              </span>
              <div class="flex-grow border-t border-gray-400"></div>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div>
                <div :if={@source_configs == []} class="text-gray-500 italic">
                  No sources created yet.
                </div>
                <div
                  :for={sc <- @source_configs}
                  class="border border-gray-400 dark:border-gray-600 rounded-lg p-4 mb-4"
                >
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-black dark:text-white font-medium">{sc.source_type}</span>
                    <button
                      phx-click="delete_source"
                      phx-value-id={sc.id}
                      data-confirm="Are you sure?"
                      class="text-red-500 hover:text-red-700 text-sm"
                    >
                      Delete
                    </button>
                  </div>
                  <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">
                    <div :for={{key, val} <- sc.config} class="flex gap-2">
                      <span class="font-medium text-gray-700 dark:text-gray-300">{format_key(key)}:</span>
                      <span>{format_value(val)}</span>
                    </div>
                  </div>
                </div>
              </div>

              <div class="border border-gray-400 dark:border-gray-600 rounded-lg p-4 h-fit">
                <h4 class="text-black dark:text-white font-medium mb-3">Add Event Source</h4>
                <form phx-submit="add_source" class="space-y-4">
                  <div>
                    <label class="block text-sm text-gray-700 dark:text-gray-300 mb-1">
                      Source Type
                    </label>
                    <select
                      name="source_type"
                      class="w-full rounded-lg bg-white dark:bg-gray-700 text-black dark:text-white border-gray-300 dark:border-gray-600"
                    >
                      <option :for={{label, value} <- EventSources.type_options()} value={value}>
                        {label}
                      </option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-sm text-gray-700 dark:text-gray-300 mb-1">
                      Inference Pipeline
                    </label>
                    <select
                      name="inference_pipeline_id"
                      class="w-full rounded-lg bg-white dark:bg-gray-700 text-black dark:text-white border-gray-300 dark:border-gray-600"
                    >
                      <option value="">None</option>
                      <option :for={p <- @inference_pipelines} value={p.id}>
                        {p.name} ({p.type})
                      </option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-sm text-gray-700 dark:text-gray-300 mb-1">
                      Classes (comma-separated, leave empty for all)
                    </label>
                    <input
                      type="text"
                      name="classes"
                      placeholder="person, car, dog"
                      class="w-full rounded-lg bg-white dark:bg-gray-700 text-black dark:text-white border-gray-300 dark:border-gray-600"
                    />
                  </div>
                  <.button type="submit" class="w-full">Add Source</.button>
                </form>
              </div>
            </div>
          </div>

          <%!-- Event Targets --%>
          <div class="mb-8">
            <div class="relative flex py-5 items-center">
              <span class="flex-shrink mr-4 text-black dark:text-white font-medium">
                Event Targets
              </span>
              <div class="flex-grow border-t border-gray-400"></div>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div>
                <div :if={@target_configs == []} class="text-gray-500 italic">
                  No targets created yet.
                </div>
                <div
                  :for={tc <- @target_configs}
                  class="border border-gray-400 dark:border-gray-600 rounded-lg p-4 mb-4"
                >
                  <div class="flex justify-between items-center mb-2">
                    <span class="text-black dark:text-white font-medium">{tc.target_type}</span>
                    <button
                      phx-click="delete_target"
                      phx-value-id={tc.id}
                      data-confirm="Are you sure?"
                      class="text-red-500 hover:text-red-700 text-sm"
                    >
                      Delete
                    </button>
                  </div>
                  <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">
                    <div :for={{key, val} <- tc.config} class="flex gap-2">
                      <span class="font-medium text-gray-700 dark:text-gray-300">{format_key(key)}:</span>
                      <span>{format_value(val)}</span>
                    </div>
                  </div>
                </div>
              </div>

              <div class="border border-gray-400 dark:border-gray-600 rounded-lg p-4 h-fit">
                <h4 class="text-black dark:text-white font-medium mb-3">Add Event Target</h4>
                <form phx-submit="add_target" phx-change="change_target_type" class="space-y-4">
                  <div>
                    <label class="block text-sm text-gray-700 dark:text-gray-300 mb-1">
                      Target Type
                    </label>
                    <select
                      name="target_type"
                      class="w-full rounded-lg bg-white dark:bg-gray-700 text-black dark:text-white border-gray-300 dark:border-gray-600"
                    >
                      <option
                        :for={{label, value} <- EventTargets.type_options()}
                        value={value}
                        selected={value == @selected_target_type}
                      >
                        {label}
                      </option>
                    </select>
                  </div>
                  <div :for={field <- @target_fields}>
                    <label class="block text-sm text-gray-700 dark:text-gray-300 mb-1">
                      {field.label}
                    </label>
                    <select
                      :if={field.type == :select}
                      name={Atom.to_string(field.name)}
                      class="w-full rounded-lg bg-white dark:bg-gray-700 text-black dark:text-white border-gray-300 dark:border-gray-600"
                    >
                      <option :for={{opt_label, opt_value} <- field.options} value={opt_value}>
                        {opt_label}
                      </option>
                    </select>
                    <input
                      :if={field.type == :integer}
                      type="number"
                      name={Atom.to_string(field.name)}
                      value={field.default}
                      placeholder={field.placeholder}
                      class="w-full rounded-lg bg-white dark:bg-gray-700 text-black dark:text-white border-gray-300 dark:border-gray-600"
                    />
                    <input
                      :if={field.type == :string}
                      type="text"
                      name={Atom.to_string(field.name)}
                      value={field[:default]}
                      placeholder={field[:placeholder]}
                      class="w-full rounded-lg bg-white dark:bg-gray-700 text-black dark:text-white border-gray-300 dark:border-gray-600"
                    />
                  </div>
                  <.button type="submit" class="w-full">Add Target</.button>
                </form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"id" => "new"}, _session, socket) do
    config = %EventConfig{}
    changeset = Events.change_event_config_creation(config)
    {default_target_type, default_target_fields} = default_target_type_and_fields()

    {:ok,
     assign(socket,
       config: config,
       config_form: to_form(changeset),
       source_configs: [],
       target_configs: [],
       inference_pipelines: Inference.list_pipelines(),
       selected_target_type: default_target_type,
       target_fields: default_target_fields
     )}
  end

  def mount(%{"id" => id}, _session, socket) do
    config = Events.get_event_config!(id)
    changeset = Events.change_event_config_update(config)
    {default_target_type, default_target_fields} = default_target_type_and_fields()

    {:ok,
     assign(socket,
       config: config,
       config_form: to_form(changeset),
       source_configs: config.event_source_configs,
       target_configs: config.event_target_configs,
       inference_pipelines: Inference.list_pipelines(),
       selected_target_type: default_target_type,
       target_fields: default_target_fields
     )}
  end

  def handle_event("validate", %{"event_config" => params}, socket) do
    config = socket.assigns.config

    changeset =
      if config.id,
        do: Events.change_event_config_update(config, params),
        else: Events.change_event_config_creation(config, params)

    {:noreply, assign(socket, config_form: to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("save_config", %{"event_config" => params}, socket) do
    config = socket.assigns.config

    if config.id,
      do: do_update(socket, config, params),
      else: do_create(socket, params)
  end

  def handle_event("add_source", params, socket) do
    config = socket.assigns.config
    classes = params["classes"] || ""

    classes_list =
      classes
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    source_params = %{
      event_config_id: config.id,
      source_type: params["source_type"],
      inference_pipeline_id:
        if(params["inference_pipeline_id"] == "", do: nil, else: params["inference_pipeline_id"]),
      config: %{"classes" => classes_list},
      enabled: true
    }

    case Events.create_event_source_config(source_params) do
      {:ok, _} ->
        updated = Events.get_event_config!(config.id)

        {:noreply,
         socket
         |> assign(
           config: updated,
           source_configs: updated.event_source_configs
         )
         |> put_flash(:info, "Event source added")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add event source")}
    end
  end

  def handle_event("change_target_type", %{"target_type" => target_type}, socket) do
    fields = fields_for_target_type(target_type)
    {:noreply, assign(socket, selected_target_type: target_type, target_fields: fields)}
  end

  def handle_event("add_target", params, socket) do
    config = socket.assigns.config
    target_type = params["target_type"]
    fields = fields_for_target_type(target_type)

    target_config =
      Enum.into(fields, %{}, fn field ->
        key = Atom.to_string(field.name)
        {key, params[key]}
      end)

    target_params = %{
      event_config_id: config.id,
      target_type: target_type,
      config: target_config,
      enabled: true
    }

    case Events.create_event_target_config(target_params) do
      {:ok, _} ->
        updated = Events.get_event_config!(config.id)

        {:noreply,
         socket
         |> assign(
           config: updated,
           target_configs: updated.event_target_configs
         )
         |> put_flash(:info, "Event target added")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add event target")}
    end
  end

  def handle_event("delete_source", %{"id" => id}, socket) do
    config = socket.assigns.config
    source = Events.get_event_source_config!(id)
    {:ok, _} = Events.delete_event_source_config(source)
    updated = Events.get_event_config!(config.id)

    {:noreply,
     socket
     |> assign(config: updated, source_configs: updated.event_source_configs)
     |> put_flash(:info, "Event source deleted")}
  end

  def handle_event("delete_target", %{"id" => id}, socket) do
    config = socket.assigns.config
    target = Events.get_event_target_config!(id)
    {:ok, _} = Events.delete_event_target_config(target)
    updated = Events.get_event_config!(config.id)

    {:noreply,
     socket
     |> assign(config: updated, target_configs: updated.event_target_configs)
     |> put_flash(:info, "Event target deleted")}
  end

  defp do_create(socket, params) do
    case Events.create_event_config(params) do
      {:ok, config} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event config created")
         |> redirect(to: ~p"/event-configs/#{config.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, config_form: to_form(changeset))}
    end
  end

  defp do_update(socket, config, params) do
    case Events.update_event_config(config, params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event config updated")
         |> redirect(to: ~p"/event-configs")}

      {:error, changeset} ->
        {:noreply, assign(socket, config_form: to_form(changeset))}
    end
  end

  defp default_target_type_and_fields do
    case EventTargets.type_options() do
      [{_label, type} | _] -> {type, fields_for_target_type(type)}
      [] -> {nil, []}
    end
  end

  defp fields_for_target_type(target_type) do
    case EventTargets.module_for(target_type) do
      nil -> []
      module -> module.target_config_fields()
    end
  end

  defp format_key(key) when is_atom(key), do: format_key(Atom.to_string(key))

  defp format_key(key) when is_binary(key) do
    key
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_value(val) when is_list(val), do: Enum.join(val, ", ")
  defp format_value(val) when is_boolean(val), do: to_string(val)
  defp format_value(val), do: to_string(val)
end
