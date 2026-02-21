if Code.ensure_loaded?(Hailo) do
  defmodule ExNVR.AI.HailoObjectDetector do
    @moduledoc """
    Membrane Sink that receives decoded RGB frames,
    runs YOLO object detection via a Hailo AI accelerator, and broadcasts
    detections via PubSub.

    This detector requires a Hailo-8 accelerator (e.g. on Raspberry Pi 4/5
    with the Hailo M.2 module). On first startup it will download a
    pre-compiled YOLOv8s HEF model to the configured model path if the file
    does not already exist.

    Only compiled on Nerves targets with Hailo support (rpi4, rpi5, giraffe).
    """

    @behaviour ExNVR.AI.InferencePipeline

    use Membrane.Sink

    require Membrane.Logger

    alias Membrane.RawVideo

    @default_model_url "https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v2.17.0/hailo8/yolov8n.hef"
    @default_model_path "/data/yolov8n.hef"
    @model_width 640
    @model_height 640

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
        spec: binary() | nil,
        default: nil,
        description: "Path to the Hailo HEF model file. Defaults to #{@default_model_path}"
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
          model: nil,
          classes: nil,
          ts: System.monotonic_time(:millisecond)
        })

      state = %{state | model_path: state.model_path || @default_model_path}

      Process.set_label(:hailo_object_detector)

      {[], state}
    end

    @impl true
    def handle_setup(_ctx, state) do
      ensure_model_downloaded!(state.model_path)
      classes = load_classes(state.classes_path)

      {:ok, model} = Hailo.load(state.model_path)

      {[], %{state | model: model, classes: classes}}
    end

    @impl true
    def handle_playing(_ctx, state) do
      {[demand: {:input, 1}], state}
    end

    @impl true
    def handle_stream_format(:input, %RawVideo{} = _format, _ctx, state) do
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

      input_tensor =
        buffer.payload
        |> Nx.from_binary(:u8)
        |> Nx.reshape({@model_height, @model_width, 3})

      {:ok, [input_info | _]} = Hailo.API.get_input_vstream_infos(state.model.pipeline)
      input_name = input_info.name

      inference_start = System.monotonic_time(:millisecond)

      {:ok, output_map} =
        Hailo.infer(
          state.model,
          %{input_name => input_tensor},
          Hailo.Parsers.YoloV8,
          classes: state.classes,
          key: get_output_key(state.model)
        )

      inference_time = System.monotonic_time(:millisecond) - inference_start

      postprocessed = Hailo.Parsers.YoloV8.postprocess(output_map, {@model_height, @model_width})

      detections =
        postprocessed
        |> Enum.filter(fn det -> det.score >= state.prob_threshold end)
        |> Enum.map(fn det ->
          w = det.xmax - det.xmin
          h = det.ymax - det.ymin
          cx = det.xmin + w / 2
          cy = det.ymin + h / 2

          %{
            class: det.class_name || "class_#{det.class_id}",
            prob: det.score,
            bbox: %{
              cx: (cx - w_pad) / ratio,
              cy: (cy - h_pad) / ratio,
              w: w / ratio,
              h: h / ratio
            },
            class_idx: det.class_id
          }
        end)

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

    defp ensure_model_downloaded!(model_path) do
      unless File.exists?(model_path) do
        Membrane.Logger.info("Hailo model not found at #{model_path}, downloading...")

        dir = Path.dirname(model_path)
        File.mkdir_p!(dir)

        {:ok, _} =
          Application.ensure_all_started(:req)

        response = Req.get!(@default_model_url, into: File.stream!(model_path))

        if response.status == 200 do
          Membrane.Logger.info("Hailo model downloaded to #{model_path}")
        else
          File.rm(model_path)
          raise "Failed to download Hailo model: HTTP #{response.status}"
        end
      end
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

    defp get_output_key(model) do
      case Hailo.API.get_output_vstream_infos(model.pipeline) do
        {:ok, [info | _]} -> info.name
        _ -> raise "Could not determine output vstream name from Hailo model"
      end
    end

    # --- InferencePipeline behaviour callbacks ---

    @impl ExNVR.AI.InferencePipeline
    def label, do: "Hailo Object Detector"

    @impl ExNVR.AI.InferencePipeline
    def config_fields do
      [
        %{
          name: :model_path,
          type: :string,
          label: "Model path (HEF)",
          required: true,
          placeholder: "/data/yolov8n.hef"
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
          default: 0.5,
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

      {:ok,
       %{
         "model_path" => config["model_path"],
         "classes_path" => config["classes_path"],
         "prob_threshold" =>
           ExNVR.AI.InferencePipeline.parse_float(config["prob_threshold"], 0.25),
         "only_keyframes" => ExNVR.AI.InferencePipeline.parse_bool(config["only_keyframes"], true)
       }}
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
end
