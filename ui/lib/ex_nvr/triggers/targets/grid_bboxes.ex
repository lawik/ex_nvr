defmodule ExNVR.Triggers.Targets.GridBboxes do
  @moduledoc """
  Trigger target that broadcasts detections for the grid live view to render
  as bounding box overlays.
  """

  @behaviour ExNVR.Triggers.TriggerTarget

  @topic "grid_bboxes"

  def topic, do: @topic

  @impl true
  def label, do: "Grid Bounding Boxes"

  @impl true
  def config_fields, do: []

  @impl true
  def validate_config(_config), do: {:ok, %{}}

  @impl true
  def execute({:detections, device_id, dims, detections}, _config, _opts) do
    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      @topic,
      {:grid_detections, device_id, dims, detections}
    )

    :ok
  end

  def execute(_trigger, _config, _opts), do: :ok
end
