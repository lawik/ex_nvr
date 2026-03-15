defmodule ExNVRWeb.InferencePipelineLive do
  @moduledoc false

  use ExNVRWeb, :live_view

  alias ExNVR.Inference
  alias ExNVR.Inference.Pipeline

  def render(assigns) do
    ~H"""
    <div class="grow max-w-2xl mx-auto e-py-10">
      <div class="px-6 lg:px-8 bg-gray-300 dark:bg-gray-800">
        <h3
          :if={@pipeline.id == nil}
          class="mb-4 text-xl text-center font-medium text-gray-900 dark:text-white"
        >
          Create a new inference pipeline
        </h3>
        <h3
          :if={@pipeline.id != nil}
          class="mb-4 text-xl text-center font-medium text-gray-900 dark:text-white"
        >
          Update an inference pipeline
        </h3>
        <.simple_form
          id="pipeline_form"
          for={@pipeline_form}
          class="space-y-6"
          phx-change="validate"
          phx-submit="save_pipeline"
        >
          <.input
            field={@pipeline_form[:name]}
            id="pipeline_name"
            type="text"
            label="Name"
            required
          />
          <.input
            field={@pipeline_form[:type]}
            id="pipeline_type"
            type="select"
            options={ExNVR.Inference.InferencePipelines.type_options()}
            label="Type"
            disabled={@pipeline.id != nil}
          />

          <div class="relative flex py-5 items-center">
            <span class="flex-shrink mr-4 text-black dark:text-white">
              Pipeline Config
            </span>
            <div class="flex-grow border-t border-gray-400"></div>
          </div>

          <div :for={field <- @config_fields} class="mb-4">
            <.input
              :if={field.type == :boolean}
              name={"pipeline[config][#{field.name}]"}
              id={"config_#{field.name}"}
              type="checkbox"
              label={field.label}
              checked={config_bool_value(@config_values, field)}
              value="true"
            />
            <.input
              :if={field.type == :string}
              name={"pipeline[config][#{field.name}]"}
              id={"config_#{field.name}"}
              type="text"
              label={field.label}
              value={config_value(@config_values, field)}
              placeholder={field.placeholder}
              required={field.required}
            />
            <.input
              :if={field.type == :float}
              name={"pipeline[config][#{field.name}]"}
              id={"config_#{field.name}"}
              type="number"
              step="0.01"
              label={field.label}
              value={config_value(@config_values, field)}
              placeholder={field.placeholder}
            />
          </div>

          <:actions>
            <.button :if={is_nil(@pipeline.id)} class="w-full" phx-disable-with="Creating...">
              Create
            </.button>

            <.button :if={@pipeline.id} class="w-full" phx-disable-with="Updating...">
              Update
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(%{"id" => "new"}, _session, socket) do
    pipeline = %Pipeline{}
    changeset = Inference.change_pipeline_creation(pipeline)
    default_type = :yolo_object_detector

    {:ok,
     assign(socket,
       pipeline: pipeline,
       pipeline_form: to_form(changeset),
       selected_type: default_type,
       config_fields: ExNVR.Inference.InferencePipelines.config_fields_for(default_type),
       config_values: %{}
     )}
  end

  def mount(%{"id" => id}, _session, socket) do
    pipeline = Inference.get_pipeline!(id)
    changeset = Inference.change_pipeline_update(pipeline)

    {:ok,
     assign(socket,
       pipeline: pipeline,
       pipeline_form: to_form(changeset),
       selected_type: pipeline.type,
       config_fields: ExNVR.Inference.InferencePipelines.config_fields_for(pipeline.type),
       config_values: pipeline.config || %{}
     )}
  end

  def handle_event("validate", %{"pipeline" => params}, socket) do
    type_atom =
      case params["type"] do
        nil -> socket.assigns.selected_type
        t when is_binary(t) -> String.to_existing_atom(t)
        t when is_atom(t) -> t
      end

    config_fields = ExNVR.Inference.InferencePipelines.config_fields_for(type_atom)
    config_values = params["config"] || %{}

    pipeline = socket.assigns.pipeline

    changeset =
      if pipeline.id,
        do: Inference.change_pipeline_update(pipeline, params),
        else: Inference.change_pipeline_creation(pipeline, params)

    {:noreply,
     assign(socket,
       pipeline_form: to_form(Map.put(changeset, :action, :validate)),
       selected_type: type_atom,
       config_fields: config_fields,
       config_values: config_values
     )}
  end

  def handle_event("save_pipeline", %{"pipeline" => params}, socket) do
    pipeline = socket.assigns.pipeline

    if pipeline.id,
      do: do_update(socket, pipeline, params),
      else: do_create(socket, params)
  end

  defp do_create(socket, params) do
    case Inference.create_pipeline(params) do
      {:ok, _pipeline} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pipeline created successfully")
         |> redirect(to: ~p"/inference-pipelines")}

      {:error, changeset} ->
        {:noreply, assign(socket, pipeline_form: to_form(changeset))}
    end
  end

  defp do_update(socket, pipeline, params) do
    case Inference.update_pipeline(pipeline, params) do
      {:ok, _pipeline} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pipeline updated successfully")
         |> redirect(to: ~p"/inference-pipelines")}

      {:error, changeset} ->
        {:noreply, assign(socket, pipeline_form: to_form(changeset))}
    end
  end

  defp config_value(config_values, field) do
    key = Atom.to_string(field.name)

    case Map.get(config_values, key) do
      nil -> field.default
      value -> value
    end
  end

  defp config_bool_value(config_values, field) do
    key = Atom.to_string(field.name)

    case Map.get(config_values, key) do
      nil -> field.default == true
      val -> ExNVR.Inference.InferencePipeline.parse_bool(val, field.default == true)
    end
  end
end
