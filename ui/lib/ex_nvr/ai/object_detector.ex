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

  @pad_value 114

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        model: nil,
        ts: System.monotonic_time(:millisecond),
        width: nil,
        height: nil,
        classes: nil
      })

    Process.set_label(:object_detector)

    {[], state}
  end

  @impl true
  def handle_setup(_ctx, state) do
    load_opts =
      [model_path: state.model_path, eps: [:cuda]]
      |> then(fn o ->
        if state.classes_path, do: Keyword.put(o, :classes_path, state.classes_path), else: o
      end)

    {:ok, hailo_model} = NxHailo.Hailo.load("#{priv}/yolov8m.hef")
    # model = YOLO.load(load_opts)

    classes =
      File.read!(state.classes_path)
      |> Jason.decode!()
      |> Enum.with_index()
      |> Map.new(fn {v, k} -> {k, v} end)


    {[], %{state | model: hailo_model, classes: classes}}
  end

  @impl true
  def handle_stream_format(:input, %RawVideo{} = format, _ctx, state) do
    {[], %{state | width: format.width, height: format.height}}
  end

  defp calculate_padding(img_w, img_h, target_w, target_h) do
    width_ratio = target_w / img_w
    height_ratio = target_h / img_h
    ratio = min(width_ratio, height_ratio)

    {scaled_width, scaled_height} =
      if width_ratio < height_ratio do
        # landscape, width = model input size
        {target_w, ceil(img_h * ratio)}
      else
        # portrait or squared, height = model input size
        {ceil(img_w * ratio), target_h}
      end

    # we are going to add padding to match the model input shape
    width_padding = (target_w - scaled_width) / 2
    height_padding = (target_h - scaled_height) / 2
    {ratio, width_padding, height_padding}
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    width = state.width
    height = state.height
    input_shape = {height, width}

    {ratio, w_pad, h_pad} = calculate_padding(state.width, state.height, 640, 640)

    [%{name: name, shape: model_shape}] = state.model.pipeline.input_vstream_infos
    [%{name: output_key}] = state.model.pipeline.output_vstream_infos


    inference_start = System.monotonic_time(:millisecond)

    input_tensor =
      buffer.payload
      |> Nx.from_binary(:u8)
      |> Nx.reshape({height, width, 3})
      |> Nx.pad(@pad_value, [
        {floor(h_pad), ceil(h_pad), 0},
        {floor(w_pad), ceil(w_pad), 0},
        {0, 0, 0}
      ])

    {:ok, raw_detected_objects} =
      NxHailo.Hailo.infer(
        state.model,
        %{name => input_tensor},
        NxHailo.Parsers.YoloV8,
        classes: state.classes,
        key: output_key
      )


    detections =
      raw_detected_objects
      # filtering
      |> Enum.reject(& &1.score < 0.5)
      |> NxHailo.Parsers.YoloV8.postprocess(input_shape)

      # OUTPUT is a list of NxHailo.Parsers.YoloV8.DetectedObject
      # %NxHailo.Parsers.YoloV8.DetectedObject{
      #   ymin: remap_coordinate(object.ymin, max_dim, padding_h, input_height),
      #   ymax: remap_coordinate(object.ymax, max_dim, padding_h, input_height),
      #   xmin: remap_coordinate(object.xmin, max_dim, padding_w, input_width),
      #   xmax: remap_coordinate(object.xmax, max_dim, padding_w, input_width),
      #   score: object.score,
      #   class_name: object.class_name,
      #   class_id: object.class_id
      # }




      |> Enum.map(fn %NxHailo.Parsers.YoloV8.DetectedObject{}=det ->
        width = det.xmax - det.xmin
        height = det.ymax - det.ymin

        %{
          bbox: %{
            cx: round(det.xmin + width/2),
            cy: round(det.ymin + height/2),
            w: width,
            h: height
          },
          score: det.score,
          class_name: det.class_name,
          class_idx: det.class_id
        }
      end)

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
