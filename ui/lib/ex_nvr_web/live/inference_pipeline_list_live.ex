defmodule ExNVRWeb.InferencePipelineListLive do
  @moduledoc false

  use ExNVRWeb, :live_view

  alias ExNVR.Inference

  def render(assigns) do
    ~H"""
    <div class="grow e-m-8">
      <div class="ml-4 sm:ml-0">
        <.link href={~p"/inference-pipelines/new"}>
          <.button><.icon name="hero-plus-solid" class="h-4 w-4" />Add Inference Pipeline</.button>
        </.link>
      </div>

      <.table id="inference-pipelines" rows={@pipelines}>
        <:col :let={pipeline} label="Name">{pipeline.name}</:col>
        <:col :let={pipeline} label="Type">{pipeline.type}</:col>
        <:action :let={pipeline}>
          <.three_dot
            id={"dropdownMenuIconButton_#{pipeline.id}"}
            dropdown_id={"dropdownDots_#{pipeline.id}"}
          />

          <div
            id={"dropdownDots_#{pipeline.id}"}
            class="z-10 hidden text-left bg-white divide-y divide-gray-100 rounded-lg shadow w-44 dark:bg-gray-700 dark:divide-gray-600"
          >
            <ul
              class="py-2 text-sm text-gray-700 dark:text-gray-200"
              aria-labelledby={"dropdownMenuIconButton_#{pipeline.id}"}
            >
              <li>
                <.link
                  href={~p"/inference-pipelines/#{pipeline.id}"}
                  class="block px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white"
                >
                  Update
                </.link>
              </li>
              <li>
                <.link
                  phx-click={show_modal("delete-pipeline-modal-#{pipeline.id}")}
                  class="block px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white"
                >
                  Delete
                </.link>
              </li>
            </ul>
          </div>
        </:action>
        <:action :let={pipeline}>
          <.modal id={"delete-pipeline-modal-#{pipeline.id}"}>
            <div class="bg-white dark:bg-gray-800 m-8 rounded">
              <h2 class="text-xl text-white font-bold mb-4">
                Are you sure you want to delete this inference pipeline?
              </h2>
              <div class="mt-4">
                <button
                  phx-click="delete-pipeline"
                  phx-value-pipeline_id={pipeline.id}
                  class="bg-red-500 hover:bg-red-600 text-white py-2 px-4 rounded mr-4"
                >
                  Confirm
                </button>
                <button
                  phx-click={hide_modal("delete-pipeline-modal-#{pipeline.id}")}
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
    {:ok, assign(socket, pipelines: Inference.list_pipelines())}
  end

  def handle_event("delete-pipeline", %{"pipeline_id" => id}, socket) do
    pipeline = Inference.get_pipeline!(id)

    case Inference.delete_pipeline(pipeline) do
      :ok ->
        socket
        |> assign(pipelines: Inference.list_pipelines())
        |> put_flash(:info, "Pipeline #{pipeline.name} deleted")
        |> then(&{:noreply, &1})

      _other ->
        socket
        |> put_flash(:error, "Could not delete pipeline")
        |> redirect(to: ~p"/inference-pipelines")
        |> then(&{:noreply, &1})
    end
  end
end
