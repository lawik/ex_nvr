defmodule ExNVR.AI.YoloObjectDetector do
  @moduledoc """
  Membrane Sink that receives decoded RGB frames,
  runs YOLO object detection via ONNX Runtime, and broadcasts detections via PubSub.
  """

  @behaviour ExNVR.AI.InferencePipeline
  @behaviour ExNVR.Events.EventSource

  use Membrane.Sink

  require Membrane.Logger

  alias Membrane.RawVideo

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
      description: "Path to the YOLO model file"
    ],
    classes_path: [
      spec: binary() | nil,
      default: nil,
      description: "Path to classes file"
    ],
    prob_threshold: [
      spec: float(),
      default: 0.5,
      description: "Detection probability threshold"
    ]
  )

  @model_width 640
  @model_height 640

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        model: nil,
        ts: System.monotonic_time(:millisecond)
      })

    Process.set_label(:yolo_object_detector)

    {[], state}
  end

  @impl true
  def handle_setup(_ctx, state) do
    eps = Application.get_env(:ex_nvr, :inference)[:onnx_execution_providers] || []

    load_opts =
      [model_path: state.model_path, eps: eps]
      |> then(fn o ->
        if state.classes_path, do: Keyword.put(o, :classes_path, state.classes_path), else: o
      end)

    model = YOLO.load(load_opts)

    {[], %{state | model: model}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[demand: {:input, 1}], state}
  end

  @impl true
  def handle_stream_format(:input, format, _ctx, state) do
    {[demand: {:input, 1}], state}
  end

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

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    orig_width = buffer.metadata.orig_width
    orig_height = buffer.metadata.orig_height

    {ratio, w_pad, h_pad} =
      calculate_padding(orig_width, orig_height, @model_width, @model_height)

    inference_start = System.monotonic_time(:millisecond)

    mat =
      buffer.payload
      |> Nx.from_binary(:u8)
      |> Nx.reshape({@model_height, @model_width, 3})

    detections =
      state.model
      |> YOLO.detect(mat,
        prob_threshold: state.prob_threshold,
        frame_scaler: YOLO.FrameScalers.NxIdentityScaler
      )
      |> YOLO.to_detected_objects(state.model.classes)
      |> Enum.map(fn det ->
        bbox = det.bbox

        %{
          det
          | bbox: %{
              cx: (bbox.cx - w_pad) / ratio,
              cy: (bbox.cy - h_pad) / ratio,
              w: bbox.w / ratio,
              h: bbox.h / ratio
            }
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

  # --- InferencePipeline behaviour callbacks ---

  @impl ExNVR.AI.InferencePipeline
  def label, do: "YOLO Object Detector"

  @impl ExNVR.AI.InferencePipeline
  def config_fields do
    inference_defaults = Application.get_env(:ex_nvr, :inference, [])

    [
      %{
        name: :model_path,
        type: :string,
        label: "Model path",
        default: Keyword.get(inference_defaults, :model_path),
        required: true,
        placeholder: "./yolo11n.onnx"
      },
      %{
        name: :classes_path,
        type: :string,
        label: "Classes path",
        default: Keyword.get(inference_defaults, :classes_path),
        required: false,
        placeholder: "./coco_classes.json"
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

  # --- EventSource behaviour callbacks ---

  @impl ExNVR.Events.EventSource
  def event_definitions do
    %{"detections" => %{"objects_detected" => &objects_detected?/3}}
  end

  @impl ExNVR.Events.EventSource
  def event_config_fields do
    [
      %{
        name: :classes,
        type: :multi_select,
        label: "Trigger on classes",
        required: false,
        default: [],
        placeholder: nil,
        options: available_classes() |> Enum.map(&{&1, &1})
      }
    ]
  end

  @impl ExNVR.Events.EventSource
  def validate_event_config(config) do
    config = for {k, v} <- config, into: %{}, do: {to_string(k), v}
    classes = config["classes"] || []

    classes =
      cond do
        is_list(classes) -> classes
        is_binary(classes) -> String.split(classes, ",", trim: true) |> Enum.map(&String.trim/1)
        true -> []
      end

    {:ok, %{"classes" => classes}}
  end

  @doc "Returns the list of available detection classes."
  @spec available_classes() :: [String.t()]
  def available_classes do
    ~w(person bicycle car motorcycle airplane bus train truck boat traffic\ light
       fire\ hydrant stop\ sign parking\ meter bench bird cat dog horse sheep cow
       elephant bear zebra giraffe backpack umbrella handbag tie suitcase frisbee
       skis snowboard sports\ ball kite baseball\ bat baseball\ glove skateboard
       surfboard tennis\ racket bottle wine\ glass cup fork knife spoon bowl banana
       apple sandwich orange broccoli carrot hot\ dog pizza donut cake chair couch
       potted\ plant bed dining\ table toilet tv laptop mouse remote keyboard
       cell\ phone microwave oven toaster sink refrigerator book clock vase scissors
       teddy\ bear hair\ drier toothbrush)
  end

  defp objects_detected?({:detections, device_id, _dims, detections}, config, %{id: device_id}) do
    classes = config["classes"] || []

    if classes == [] do
      detections != []
    else
      Enum.any?(detections, fn det -> det.class in classes end)
    end
  end

  defp objects_detected?(_msg, _config, _device), do: false

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
