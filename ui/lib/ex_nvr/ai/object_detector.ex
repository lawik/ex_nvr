defmodule ExNVR.AI.ObjectDetector do
  @moduledoc """
  GenServer that subscribes to thumbnail images from a device's pipeline,
  runs YOLO object detection, and broadcasts detections via PubSub.

  ## PubSub Topics

    * Subscribes to: `"thumbnails:<device_id>"` — receives `{:thumbnail, jpeg_binary}`
    * Broadcasts on: `"detections:<device_id>"` — sends `{:detections, device_id, detections}`

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
    device_id = Keyword.fetch!(opts, :device_id)
    model_path = Keyword.fetch!(opts, :model_path)
    classes_path = Keyword.get(opts, :classes_path)
    prob_threshold = Keyword.get(opts, :prob_threshold, 0.25)

    Phoenix.PubSub.subscribe(ExNVR.PubSub, "thumbnails:#{device_id}")

    load_opts =
      [model_path: model_path]
      |> then(fn o -> if classes_path, do: Keyword.put(o, :classes_path, classes_path), else: o end)

    model = YOLO.load(load_opts)

    {:ok,
     %{
       device_id: device_id,
       model: model,
       prob_threshold: prob_threshold
     }}
  end

  @impl true
  def handle_info({:thumbnail, jpeg_binary}, state) do
    mat = Evision.imdecode(jpeg_binary, Evision.Constant.cv_IMREAD_COLOR())

    detections =
      state.model
      |> YOLO.detect(mat, prob_threshold: state.prob_threshold)
      |> YOLO.to_detected_objects(state.model.classes)

    Phoenix.PubSub.broadcast(
      ExNVR.PubSub,
      "detections:#{state.device_id}",
      {:detections, state.device_id, detections}
    )

    {:noreply, state}
  end
end
