defmodule ExNVR.Triggers.Sources.ObjectDetection do
  @moduledoc """
  Trigger source that fires when object detection inference produces matching results.

  The source config references an inference pipeline and optionally filters on
  detected class names.
  """

  @behaviour ExNVR.Triggers.TriggerSource

  @impl true
  def label, do: "Object Detection"

  @impl true
  def config_fields do
    pipeline_options =
      ExNVR.Inference.list_pipelines()
      |> Enum.map(fn p -> {p.name, p.id} end)

    [
      %{
        name: :inference_pipeline_id,
        type: :select,
        label: "Inference Pipeline",
        required: true,
        default: nil,
        placeholder: nil,
        options: pipeline_options
      },
      %{
        name: :classes,
        type: :string,
        label: "Trigger on classes (comma-separated, blank = any)",
        required: false,
        default: nil,
        placeholder: "person, car, dog",
        options: nil
      }
    ]
  end

  @impl true
  def validate_config(config) do
    config = for {k, v} <- config, into: %{}, do: {to_string(k), v}
    pipeline_id = config["inference_pipeline_id"]

    if is_nil(pipeline_id) or pipeline_id == "" do
      {:error, [inference_pipeline_id: "is required"]}
    else
      classes = parse_classes(config["classes"])

      {:ok,
       %{
         "inference_pipeline_id" => pipeline_id,
         "classes" => classes
       }}
    end
  end

  @impl true
  def matches?(source_config, {:detections, _device_id, _dims, detections, gone}) do
    wanted = source_config["classes"]

    cond do
      wanted in [nil, []] -> detections != [] or MapSet.size(gone) > 0
      classes_match?(wanted, detections) -> true
      gone_match?(wanted, gone) -> true
      true -> false
    end
  end

  def matches?(_source_config, _message), do: false

  @impl true
  def filter_message(source_config, {:detections, device_id, dims, detections, gone}) do
    wanted = source_config["classes"]
    filtered = filter_classes(wanted, detections)
    filtered_gone = filter_gone(wanted, gone)

    if filtered == [] and MapSet.size(filtered_gone) == 0 do
      nil
    else
      {:detections, device_id, dims, filtered, filtered_gone}
    end
  end

  def filter_message(_source_config, message), do: message

  defp filter_classes([], detections), do: detections
  defp filter_classes(nil, detections), do: detections

  defp filter_classes(wanted, detections) when is_list(wanted) do
    Enum.filter(detections, &(&1.class in wanted))
  end

  defp filter_gone([], gone), do: gone
  defp filter_gone(nil, gone), do: gone

  defp filter_gone(wanted, gone) when is_list(wanted) do
    gone |> Enum.filter(&(&1 in wanted)) |> MapSet.new()
  end

  defp classes_match?([], _detections), do: true
  defp classes_match?(nil, _detections), do: true

  defp classes_match?(wanted, detections) when is_list(wanted) do
    Enum.any?(detections, &(&1.class in wanted))
  end

  defp gone_match?(wanted, gone) when is_list(wanted) do
    Enum.any?(wanted, &MapSet.member?(gone, &1))
  end

  defp parse_classes(nil), do: []
  defp parse_classes(""), do: []
  defp parse_classes(classes) when is_list(classes), do: classes

  defp parse_classes(classes) when is_binary(classes) do
    classes |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
  end
end
