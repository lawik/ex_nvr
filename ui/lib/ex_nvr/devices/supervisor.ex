defmodule ExNVR.Devices.Supervisor do
  @moduledoc false

  use Supervisor

  alias ExNVR.Model.Device
  alias ExNVR.Pipelines.Main

  @spec start(Device.t()) :: DynamicSupervisor.on_start_child()
  def start(device) do
    spec = %{
      id: __MODULE__,
      start: {Supervisor, :start_link, [__MODULE__, device, [name: supervisor_name(device)]]},
      restart: :transient
    }

    DynamicSupervisor.start_child(ExNVR.PipelineSupervisor, spec)
  end

  @impl true
  def init(device) do
    params = [device: device]

    children = [
      {ExNVR.DiskMonitor, params},
      {Main, params},
      {ExNVR.BIF.GeneratorServer, params},
      {ExNVR.Devices.SnapshotUploader, params}
    ]

    children =
      if device.settings.enable_lpr && Device.http_url(device) do
        children ++ [{ExNVR.Devices.LPREventPuller, params}]
      else
        children
      end

    children =
      case :os.type() do
        {:unix, _name} -> children ++ [{ExNVR.UnixSocketServer, params}]
        _other -> children
      end

    children =
      case Application.get_env(:ex_nvr, :object_detector) do
        nil ->
          children

        detector_config ->
          detector_opts = [
            device_id: device.id,
            model_path: Keyword.fetch!(detector_config, :model_path),
            classes_path: Keyword.get(detector_config, :classes_path),
            prob_threshold: Keyword.get(detector_config, :prob_threshold, 0.25)
          ]

          children ++ [{ExNVR.AI.ObjectDetector, detector_opts}]
      end

    Supervisor.init(children, strategy: :rest_for_one, max_restarts: 10_000)
  end

  @spec stop(Device.t()) :: :ok
  def stop(device) do
    device
    |> supervisor_name()
    |> Process.whereis()
    |> case do
      nil ->
        :ok

      pid ->
        # We terminate the pipeline first to allow it to do cleanup.
        # Without this, the pipeline is killed directly.
        terminate_pipeline(device)
        Supervisor.stop(pid)
    end
  end

  @spec restart(Device.t()) :: DynamicSupervisor.on_start_child()
  def restart(device) do
    stop(device)
    start(device)
  end

  defp terminate_pipeline(device) do
    device
    |> ExNVR.Utils.pipeline_name()
    |> Process.whereis()
    |> Membrane.Pipeline.terminate(force?: true, timeout: :timer.seconds(10))
  end

  defp supervisor_name(device), do: :"#{device.id}"
end
