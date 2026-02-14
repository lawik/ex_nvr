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
    prob_threshold = Keyword.get(opts, :prob_threshold, 0.5)

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
       prob_threshold: prob_threshold,
       ts: System.monotonic_time(:millisecond)
     }}
  end

  @impl true
  def handle_info({:frame, device_id, decoded}, state) do
    mat =
      decoded.data
      |> Nx.from_binary(:u8)
      |> Nx.reshape({decoded.height, decoded.width, 3})

    detections =
      state.model
      |> YOLO.detect(mat,
        prob_threshold: state.prob_threshold,
        frame_scaler: YOLO.FrameScalers.NxIdentityScaler
      )
      |> YOLO.to_detected_objects(state.model.classes)

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "detections",
      {:detections, device_id, {decoded.width, decoded.height}, detections}
    )

    ts = System.monotonic_time(:millisecond)
    diff = ts - state.ts
    fps = if diff > 0, do: Float.round(1000 / diff, 2), else: 0.0

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "inference_stats",
      {:object_detector_fps, device_id, fps}
    )

    {:noreply, %{state | ts: ts}}
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
