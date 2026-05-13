defmodule ExNVR.Triggers.Targets.GridBboxes do
  @moduledoc """
  Trigger target that broadcasts detections for the grid live view to render
  as bounding box overlays.
  """

  @behaviour ExNVR.Triggers.TriggerTarget

  @topic "grid_bboxes"
  @styles ~w(corner_brackets dashed_glow svg_draw_in gradient_border frosted_glass)

  def topic, do: @topic

  @impl true
  def label, do: "Grid Bounding Boxes"

  @impl true
  def config_fields do
    [
      %{
        name: :style,
        type: :custom,
        component: &ExNVRWeb.Components.Vision.BboxSelector.preview_selector/1,
        label: "Style",
        required: false,
        default: "corner_brackets",
        placeholder: nil,
        options: nil
      }
    ]
  end

  @impl true
  def validate_config(config) do
    config = for {k, v} <- config, into: %{}, do: {to_string(k), v}
    style = config["style"] || "corner_brackets"

    if style in @styles do
      {:ok, %{"style" => style}}
    else
      {:error, [style: "must be one of: #{Enum.join(@styles, ", ")}"]}
    end
  end

  @impl true
  def execute({:detections, device_id, dims, detections, _gone}, config, _opts) do
    style = String.to_existing_atom(config["style"] || "corner_brackets")

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      @topic,
      {:grid_detections, device_id, dims, detections, style}
    )

    :ok
  end

  def execute(_trigger, _config, _opts), do: :ok
end
