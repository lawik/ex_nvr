defmodule ExNVR.AI.ObjectDetector do
  @moduledoc """
  GenServer that subscribes to frames from a device's pipeline,
  runs YOLO object detection, and broadcasts detections via PubSub.

  Each detection is a map with keys: `class`, `prob`, `bbox` (as `{cx, cy, w, h}`).
  """

  use GenServer

  require Logger

  def start_link(opts) do
    device_id = Keyword.fetch!(opts, :device_id)
    GenServer.start_link(__MODULE__, opts, name: via(device_id))
  end

  defp via(device_id), do: {:global, {__MODULE__, device_id}}

  @impl true
  def init(opts) do
    model_path = Keyword.fetch!(opts, :model_path)
    classes_path = Keyword.get(opts, :classes_path)
    prob_threshold = Keyword.get(opts, :prob_threshold, 0.25)

    Phoenix.PubSub.subscribe(ExNVR.PubSub, "frames")

    load_opts =
      [model_path: model_path]
      |> then(fn o ->
        if classes_path, do: Keyword.put(o, :classes_path, classes_path), else: o
      end)

    model = YOLO.load(load_opts)

    {:ok,
     %{
       model: model,
       prob_threshold: prob_threshold
     }}
  end

  @impl true
  def handle_info({:frame, device_id, jpeg_binary}, state) do
    IO.inspect(device_id, label: "device_id")
    %{shape: {w, h, _}} = mat = Evision.imdecode(jpeg_binary, Evision.Constant.cv_IMREAD_COLOR())
    %{shape: {w, h, _}} = mat = Evision.resize(mat, {640, 640})

    detections =
      state.model
      |> YOLO.detect(mat, prob_threshold: state.prob_threshold)
      |> IO.inspect(label: "detections")
      |> YOLO.to_detected_objects(state.model.classes)

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "detections",
      {:detections, device_id, {w, h}, detections}
    )

    {:noreply, state}
  end

  def fake do
    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "detections",
      {:detections, "fake",
       [
         %{
           class: "person",
           prob: 0.57,
           bbox: %{h: 126, w: 70, cx: 700, cy: 570},
           class_idx: 0
         },
         %{
           class: "bicycle",
           prob: 0.61,
           bbox: %{h: 102, w: 71, cx: 726, cy: 738},
           class_idx: 1
         },
         %{class: "car", prob: 0.62, bbox: %{h: 87, w: 102, cx: 1039, cy: 268}, class_idx: 2}
       ]}
    )
  end
end
