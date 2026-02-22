defmodule ExNVR.Events.Targets.DeveloperLog do
  @moduledoc """
  Standalone event target that logs events via Logger.

  Useful for debugging event source configurations.
  """

  @behaviour ExNVR.Events.EventTarget

  use GenServer

  require Logger

  @impl ExNVR.Events.EventTarget
  def label, do: "Developer Log"

  @impl ExNVR.Events.EventTarget
  def target_type, do: :standalone

  @impl ExNVR.Events.EventTarget
  def target_config_fields, do: []

  @impl ExNVR.Events.EventTarget
  def validate_target_config(_config), do: {:ok, %{}}

  # --- GenServer ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    device_id = Keyword.fetch!(opts, :device_id)
    Phoenix.PubSub.subscribe(ExNVR.PubSub, "events:#{device_id}")
    {:ok, %{device_id: device_id}}
  end

  @impl GenServer
  def handle_info({:event, event_name}, state) do
    Logger.info("[EventTarget:DeveloperLog] device=#{state.device_id} event=#{event_name}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_msg, state), do: {:noreply, state}
end
