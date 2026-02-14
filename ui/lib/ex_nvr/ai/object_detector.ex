defmodule ExNVR.AI.ObjectDetector do
  @moduledoc """
  Membrane Sink that receives decoded RGB frames,
  runs YOLO object detection, and broadcasts detections via PubSub.
  """

  use Membrane.Sink

  require Membrane.Logger

  alias Membrane.RawVideo

  def_input_pad(:input,
    accepted_format: RawVideo
  )

  def_options(
    device_id: [
      spec: binary(),
      description: "Device ID for PubSub broadcasts"
    ],
    model_path: [
      spec: binary(),
      description: "Path to the YOLO model file"
    ],
    classes_path: [
      spec: binary() | nil,
      default: nil,
      description: "Path to classes file"
    ],
    prob_threshold: [
      spec: float(),
      default: 0.25,
      description: "Detection probability threshold"
    ]
  )

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        model: nil,
        ts: System.monotonic_time(:millisecond),
        width: nil,
        height: nil
      })

    Process.set_label(:object_detector)

    {[], state}
  end

  @impl true
  def handle_setup(_ctx, state) do
    load_opts =
      [model_path: state.model_path, eps: [:cpu]]
      |> then(fn o ->
        if state.classes_path, do: Keyword.put(o, :classes_path, state.classes_path), else: o
      end)

    model = YOLO.load(load_opts)

    {[], %{state | model: model}}
  end

  @impl true
  def handle_stream_format(:input, %RawVideo{} = format, _ctx, state) do
    {[], %{state | width: format.width, height: format.height}}
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    width = state.width
    height = state.height

    inference_start = System.monotonic_time(:millisecond)

    mat =
      buffer.payload
      |> Nx.from_binary(:u8)
      |> Nx.reshape({height, width, 3})

    detections =
      state.model
      |> YOLO.detect(mat,
        prob_threshold: state.prob_threshold,
        frame_scaler: YOLO.FrameScalers.NxIdentityScaler
      )
      |> YOLO.to_detected_objects(state.model.classes)

    inference_time = System.monotonic_time(:millisecond) - inference_start

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "inference_stats",
      {:inference_time, state.device_id, inference_time}
    )

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "detections",
      {:detections, state.device_id, {width, height}, detections}
    )

    ts = System.monotonic_time(:millisecond)
    diff = ts - state.ts
    fps = if diff > 0, do: Float.round(1000 / diff, 2), else: 0.0

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "inference_stats",
      {:object_detector_fps, state.device_id, fps}
    )

    latency_ms = ts - buffer.metadata.grabbed_at

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "inference_stats",
      {:inference_latency, state.device_id, latency_ms}
    )

    {[], %{state | ts: ts}}
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
