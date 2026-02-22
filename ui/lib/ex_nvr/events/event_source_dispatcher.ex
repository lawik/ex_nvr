defmodule ExNVR.Events.EventSourceDispatcher do
  @moduledoc """
  GenServer that bridges PubSub detection messages to the per-device event topic.

  Started per (device, event_source_config). Subscribes to the PubSub topics
  listed in the source module's `event_definitions/0`, filters messages by
  device_id, and broadcasts matching events on `"events:<device_id>"`.
  """

  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    device = Keyword.fetch!(opts, :device)
    source_module = Keyword.fetch!(opts, :source_module)
    config = Keyword.fetch!(opts, :config)

    definitions = source_module.event_definitions()

    for {topic, _events} <- definitions do
      Phoenix.PubSub.subscribe(ExNVR.PubSub, topic)
    end

    state = %{
      device_id: device.id,
      device: device,
      source_module: source_module,
      config: config,
      definitions: definitions
    }

    {:ok, state}
  end

  @impl true
  def handle_info(msg, state) do
    device_id = extract_device_id(msg)

    if device_id == state.device_id do
      topic = topic_for_message(msg)
      evaluate_filters(topic, msg, state)
    end

    {:noreply, state}
  end

  defp evaluate_filters(nil, _msg, _state), do: :ok

  defp evaluate_filters(topic, msg, state) do
    case Map.get(state.definitions, topic) do
      nil ->
        :ok

      events ->
        for {event_name, filter_fn} <- events do
          if filter_fn.(msg, state.config, state.device) do
            Phoenix.PubSub.broadcast(
              ExNVR.PubSub,
              "events:#{state.device_id}",
              {:event, event_name}
            )
          end
        end
    end
  end

  defp extract_device_id({:detections, device_id, _dims, _dets}), do: device_id
  defp extract_device_id(_), do: nil

  defp topic_for_message({:detections, _device_id, _dims, _dets}), do: "detections"
  defp topic_for_message(_), do: nil
end
