defmodule ExNVR.AI.CoralObjectDetector do
  @moduledoc """
  Membrane Sink that receives decoded RGB frames,
  runs YOLOv8n object detection via TFLite (optionally on a Google Coral Edge TPU),
  and broadcasts detections via PubSub.

  Supports both regular TFLite models (CPU inference) and Edge TPU-compiled
  models (Coral USB accelerator). When an Edge TPU device is available and the
  model has been compiled with `edgetpu_compiler`, inference runs on the TPU;
  otherwise it falls back to CPU.

  Build with `TFLITE_BEAM_CORAL_SUPPORT=true` for Edge TPU delegate support.
  """

  @behaviour ExNVR.AI.InferencePipeline

  use Membrane.Sink

  require Membrane.Logger

  alias Membrane.RawVideo

  @model_width 640
  @model_height 640
  @nms_iou_threshold 0.45

  def_input_pad(:input,
    accepted_format: RawVideo,
    demand_unit: :buffers,
    flow_control: :manual
  )

  def_options(
    device_id: [
      spec: binary(),
      description: "Device ID for PubSub broadcasts"
    ],
    model_path: [
      spec: binary(),
      description: "Path to the TFLite model file (.tflite)"
    ],
    classes_path: [
      spec: binary() | nil,
      default: nil,
      description: "Path to classes JSON file"
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
        interpreter: nil,
        classes: nil,
        ts: System.monotonic_time(:millisecond)
      })

    Process.set_label(:coral_object_detector)

    {[], state}
  end

  @impl true
  def handle_setup(_ctx, state) do
    classes = load_classes(state.classes_path)
    interpreter = load_interpreter(state.model_path)

    {[], %{state | interpreter: interpreter, classes: classes}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[demand: {:input, 1}], state}
  end

  @impl true
  def handle_stream_format(:input, %RawVideo{}, _ctx, state) do
    {[demand: {:input, 1}], state}
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    orig_width = buffer.metadata.orig_width
    orig_height = buffer.metadata.orig_height

    {ratio, w_pad, h_pad} =
      calculate_padding(orig_width, orig_height, @model_width, @model_height)

    inference_start = System.monotonic_time(:millisecond)

    # TFLite expects the raw binary input matching the model's input tensor
    input = Nx.from_binary(buffer.payload, :u8) |> Nx.reshape({1, @model_height, @model_width, 3})

    output_tensors = TFLiteElixir.Interpreter.predict(state.interpreter, Nx.to_binary(input))

    inference_time = System.monotonic_time(:millisecond) - inference_start

    detections =
      output_tensors
      |> postprocess_yolov8(state.classes, state.prob_threshold, ratio, w_pad, h_pad)

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "inference_stats",
      {:inference_time, state.device_id, inference_time}
    )

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "detections",
      {:detections, state.device_id, {orig_width, orig_height}, detections}
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

    {[demand: {:input, 1}], %{state | ts: ts}}
  end

  # --- Model loading ---

  defp load_interpreter(model_path) do
    interpreter = TFLiteElixir.Interpreter.new!(model_path)

    interpreter =
      if coral_available?() do
        try do
          ctx = TFLiteElixir.Coral.get_edge_tpu_context!()

          TFLiteElixir.Coral.make_edge_tpu_interpreter!(model_path, ctx)
        rescue
          e ->
            Membrane.Logger.warning(
              "Coral Edge TPU not available (#{inspect(e)}), falling back to CPU"
            )

            TFLiteElixir.Interpreter.allocate_tensors!(interpreter)
            interpreter
        end
      else
        Membrane.Logger.info("Coral support not compiled in, using CPU inference")
        TFLiteElixir.Interpreter.allocate_tensors!(interpreter)
        interpreter
      end

    interpreter
  end

  defp coral_available? do
    Code.ensure_loaded?(TFLiteElixir.Coral) and
      function_exported?(TFLiteElixir.Coral, :get_edge_tpu_context!, 0)
  end

  # --- YOLOv8 post-processing ---

  defp postprocess_yolov8(output_tensors, classes, prob_threshold, ratio, w_pad, h_pad) do
    # YOLOv8 TFLite output: [1, 84, 8400] — 4 bbox coords + 80 class scores per detection
    raw =
      case output_tensors do
        %{0 => tensor} -> tensor
        [tensor | _] -> tensor
        tensor -> tensor
      end

    # Convert to Nx tensor and squeeze batch dim
    output =
      raw
      |> then(fn t ->
        if is_struct(t, Nx.Tensor), do: t, else: Nx.from_binary(t, :f32)
      end)
      |> Nx.reshape({:auto, 8400})

    # output is [84, 8400], transpose to [8400, 84]
    output = Nx.transpose(output)

    # Extract all 8400 candidates
    n_detections = Nx.axis_size(output, 0)

    candidates =
      for i <- 0..(n_detections - 1) do
        row = output[i]
        cx = Nx.to_number(row[0])
        cy = Nx.to_number(row[1])
        w = Nx.to_number(row[2])
        h = Nx.to_number(row[3])

        scores = Nx.slice(row, [4], [Nx.axis_size(row, 0) - 4])
        class_idx = Nx.to_number(Nx.argmax(scores))
        score = Nx.to_number(scores[class_idx])

        if score >= prob_threshold do
          %{cx: cx, cy: cy, w: w, h: h, class_idx: class_idx, score: score}
        end
      end
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.score, :desc)

    # Greedy NMS
    nms(candidates, [])
    |> Enum.map(fn det ->
      class_name = Map.get(classes, det.class_idx, "class_#{det.class_idx}")

      %{
        class: class_name,
        prob: det.score,
        bbox: %{
          cx: (det.cx - w_pad) / ratio,
          cy: (det.cy - h_pad) / ratio,
          w: det.w / ratio,
          h: det.h / ratio
        },
        class_idx: det.class_idx
      }
    end)
  end

  defp nms([], kept), do: Enum.reverse(kept)

  defp nms([best | rest], kept) do
    rest = Enum.reject(rest, fn det -> iou(best, det) > @nms_iou_threshold end)
    nms(rest, [best | kept])
  end

  defp iou(a, b) do
    ax1 = a.cx - a.w / 2
    ay1 = a.cy - a.h / 2
    ax2 = a.cx + a.w / 2
    ay2 = a.cy + a.h / 2

    bx1 = b.cx - b.w / 2
    by1 = b.cy - b.h / 2
    bx2 = b.cx + b.w / 2
    by2 = b.cy + b.h / 2

    ix1 = max(ax1, bx1)
    iy1 = max(ay1, by1)
    ix2 = min(ax2, bx2)
    iy2 = min(ay2, by2)

    inter = max(0, ix2 - ix1) * max(0, iy2 - iy1)
    area_a = (ax2 - ax1) * (ay2 - ay1)
    area_b = (bx2 - bx1) * (by2 - by1)
    union = area_a + area_b - inter

    if union > 0, do: inter / union, else: 0.0
  end

  # --- Utilities ---

  defp calculate_padding(img_w, img_h, target_w, target_h) do
    width_ratio = target_w / img_w
    height_ratio = target_h / img_h
    ratio = min(width_ratio, height_ratio)

    {scaled_width, scaled_height} =
      if width_ratio < height_ratio do
        {target_w, ceil(img_h * ratio)}
      else
        {ceil(img_w * ratio), target_h}
      end

    width_padding = (target_w - scaled_width) / 2
    height_padding = (target_h - scaled_height) / 2
    {ratio, width_padding, height_padding}
  end

  defp load_classes(nil), do: default_classes()

  defp load_classes(path) do
    case File.read(path) do
      {:ok, content} ->
        content
        |> Jason.decode!()
        |> Enum.with_index()
        |> Map.new(fn {name, idx} -> {idx, name} end)

      {:error, _} ->
        Membrane.Logger.warning("Could not read classes file #{path}, using defaults")
        default_classes()
    end
  end

  defp default_classes do
    ~w(person bicycle car motorcycle airplane bus train truck boat traffic\ light
       fire\ hydrant stop\ sign parking\ meter bench bird cat dog horse sheep cow
       elephant bear zebra giraffe backpack umbrella handbag tie suitcase frisbee
       skis snowboard sports\ ball kite baseball\ bat baseball\ glove skateboard
       surfboard tennis\ racket bottle wine\ glass cup fork knife spoon bowl banana
       apple sandwich orange broccoli carrot hot\ dog pizza donut cake chair couch
       potted\ plant bed dining\ table toilet tv laptop mouse remote keyboard
       cell\ phone microwave oven toaster sink refrigerator book clock vase scissors
       teddy\ bear hair\ drier toothbrush)
    |> Enum.with_index()
    |> Map.new(fn {name, idx} -> {idx, name} end)
  end

  # --- InferencePipeline behaviour callbacks ---

  @impl ExNVR.AI.InferencePipeline
  def label, do: "Coral Object Detector"

  @impl ExNVR.AI.InferencePipeline
  def config_fields do
    [
      %{
        name: :model_path,
        type: :string,
        label: "Model path (TFLite)",
        required: true,
        placeholder: "/data/yolov8n_full_integer_quant_edgetpu.tflite"
      },
      %{
        name: :classes_path,
        type: :string,
        label: "Classes path",
        default: nil,
        required: false,
        placeholder: "/data/coco_classes.json"
      },
      %{
        name: :prob_threshold,
        type: :float,
        label: "Detection threshold",
        default: 0.25,
        required: false,
        placeholder: "0.25"
      },
      %{
        name: :only_keyframes,
        type: :boolean,
        label: "Only keyframes",
        default: true,
        required: false,
        placeholder: nil
      }
    ]
  end

  @impl ExNVR.AI.InferencePipeline
  def validate_config(config) do
    config = for {k, v} <- config, into: %{}, do: {to_string(k), v}
    model_path = config["model_path"]

    if is_nil(model_path) or model_path == "" do
      {:error, [model_path: "is required"]}
    else
      {:ok,
       %{
         "model_path" => model_path,
         "classes_path" => config["classes_path"],
         "prob_threshold" =>
           ExNVR.AI.InferencePipeline.parse_float(config["prob_threshold"], 0.25),
         "only_keyframes" => ExNVR.AI.InferencePipeline.parse_bool(config["only_keyframes"], true)
       }}
    end
  end

  @impl ExNVR.AI.InferencePipeline
  def build_spec(device_id, config, pipeline_id) do
    import Membrane.ChildrenSpec

    [
      get_child(:tee)
      |> via_out(:push_output)
      |> child({:framepicker, pipeline_id}, %ExNVR.Pipeline.Output.Framepicker{
        device_id: device_id,
        only_keyframes: ExNVR.AI.InferencePipeline.parse_bool(config["only_keyframes"], true),
        frame_width: @model_width,
        frame_height: @model_height,
        pad: true,
        out_format: :rgb24
      })
      |> via_in(:input, target_queue_size: 1, min_demand_factor: 0.5)
      |> child({:object_detector, pipeline_id}, %__MODULE__{
        device_id: device_id,
        model_path: config["model_path"],
        classes_path: config["classes_path"],
        prob_threshold: ExNVR.AI.InferencePipeline.parse_float(config["prob_threshold"], 0.25)
      })
    ]
  end
end
