defmodule ExNVR.Events do
  @moduledoc false

  import Ecto.Query

  alias ExNVR.Events.{DeviceEventConfig, Event, EventConfig, EventSourceConfig, EventTargetConfig, LPR}
  alias ExNVR.Inference.Pipeline, as: InferencePipeline
  alias ExNVR.Model.Device
  alias ExNVR.Repo

  @type flop_result :: {:ok, {[map()], Flop.Meta.t()}} | {:error, Flop.Meta.t()}

  @spec create_event(map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def create_event(params) do
    do_create_event(nil, params)
  end

  @spec create_event(Device.t(), map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def create_event(device, params) do
    do_create_event(device.id, params)
  end

  @spec create_lpr_event(Device.t(), map(), binary() | nil) ::
          {:ok, LPR.t()} | {:error, Ecto.Changeset.t()}
  def create_lpr_event(device, params, plate_picture) do
    insertion_result =
      params
      |> Map.put(:device_id, device.id)
      |> LPR.changeset()
      |> Repo.insert(on_conflict: :nothing)

    with {:ok, %{id: id} = event} when not is_nil(id) <- insertion_result do
      if plate_picture do
        device
        |> Device.lpr_thumbnails_dir()
        |> tap(&File.mkdir/1)
        |> Path.join(LPR.plate_name(event))
        |> File.write(plate_picture)
      end

      {:ok, event}
    end
  end

  @spec list_events(map()) :: flop_result()
  def list_events(%Flop{} = flop) do
    Event |> preload([:device]) |> ExNVR.Flop.validate_and_run(flop)
  end

  @spec list_events(map()) :: flop_result()
  def list_events(params) do
    Event
    |> preload([:device])
    |> Event.filter(params)
    |> ExNVR.Flop.validate_and_run(params, for: Event)
  end

  @spec list_lpr_events(map(), Keyword.t()) :: flop_result()
  def list_lpr_events(params, opts \\ []) do
    LPR
    |> preload([:device])
    |> ExNVR.Flop.validate_and_run(params, for: LPR)
    |> case do
      {:ok, {data, meta}} ->
        {:ok, {maybe_include_lpr_thumbnails(opts[:include_plate_image], data), meta}}

      other ->
        other
    end
  end

  @spec get_event(integer()) :: Event.t() | nil
  def get_event(id) do
    Repo.get(Event, id)
    |> Repo.preload(:device)
  end

  @spec last_lpr_event_timestamp(Device.t()) :: DateTime.t() | nil
  def last_lpr_event_timestamp(device) do
    LPR
    |> select([e], e.capture_time)
    |> where([e], e.device_id == ^device.id)
    |> order_by(desc: :capture_time)
    |> limit(1)
    |> Repo.one()
  end

  @spec lpr_event_thumbnail(LPR.t()) :: binary() | nil
  def lpr_event_thumbnail(lpr_event) do
    Device.lpr_thumbnails_dir(lpr_event.device)
    |> Path.join(LPR.plate_name(lpr_event))
    |> File.read()
    |> case do
      {:ok, image} -> Base.encode64(image)
      _other -> nil
    end
  end

  defp do_create_event(device_id, params) do
    %Event{device_id: device_id}
    |> Event.changeset(params)
    |> Repo.insert()
  end

  defp maybe_include_lpr_thumbnails(true, entries) do
    Enum.map(entries, fn entry ->
      plate_image = lpr_event_thumbnail(entry)
      Map.put(entry, :plate_image, plate_image)
    end)
  end

  defp maybe_include_lpr_thumbnails(_other, entries), do: entries

  # --- Event Config CRUD ---

  @spec list_event_configs() :: [EventConfig.t()]
  def list_event_configs do
    EventConfig
    |> order_by([c], c.inserted_at)
    |> Repo.all()
    |> Repo.preload([:event_source_configs, :event_target_configs])
  end

  @spec get_event_config!(binary()) :: EventConfig.t()
  def get_event_config!(id) do
    Repo.get!(EventConfig, id)
    |> Repo.preload([:event_source_configs, :event_target_configs])
  end

  @spec create_event_config(map()) :: {:ok, EventConfig.t()} | {:error, Ecto.Changeset.t()}
  def create_event_config(params) do
    EventConfig.create_changeset(params) |> Repo.insert()
  end

  @spec update_event_config(EventConfig.t(), map()) ::
          {:ok, EventConfig.t()} | {:error, Ecto.Changeset.t()}
  def update_event_config(config, params) do
    EventConfig.update_changeset(config, params) |> Repo.update()
  end

  @spec delete_event_config(EventConfig.t()) :: :ok | {:error, Ecto.Changeset.t()}
  def delete_event_config(config) do
    case Repo.delete(config) do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec change_event_config_creation(EventConfig.t(), map()) :: Ecto.Changeset.t()
  def change_event_config_creation(config \\ %EventConfig{}, attrs \\ %{}) do
    EventConfig.create_changeset(config, attrs)
  end

  @spec change_event_config_update(EventConfig.t(), map()) :: Ecto.Changeset.t()
  def change_event_config_update(config, attrs \\ %{}) do
    EventConfig.update_changeset(config, attrs)
  end

  # --- Event Source Config CRUD ---

  @spec get_event_source_config!(binary()) :: EventSourceConfig.t()
  def get_event_source_config!(id), do: Repo.get!(EventSourceConfig, id)

  @spec create_event_source_config(map()) ::
          {:ok, EventSourceConfig.t()} | {:error, Ecto.Changeset.t()}
  def create_event_source_config(params) do
    EventSourceConfig.changeset(params) |> Repo.insert()
  end

  @spec delete_event_source_config(EventSourceConfig.t()) ::
          {:ok, EventSourceConfig.t()} | {:error, Ecto.Changeset.t()}
  def delete_event_source_config(config), do: Repo.delete(config)

  # --- Event Target Config CRUD ---

  @spec get_event_target_config!(binary()) :: EventTargetConfig.t()
  def get_event_target_config!(id), do: Repo.get!(EventTargetConfig, id)

  @spec create_event_target_config(map()) ::
          {:ok, EventTargetConfig.t()} | {:error, Ecto.Changeset.t()}
  def create_event_target_config(params) do
    EventTargetConfig.changeset(params) |> Repo.insert()
  end

  @spec delete_event_target_config(EventTargetConfig.t()) ::
          {:ok, EventTargetConfig.t()} | {:error, Ecto.Changeset.t()}
  def delete_event_target_config(config), do: Repo.delete(config)

  # --- Device association ---

  @spec event_configs_for_device(binary()) :: [EventConfig.t()]
  def event_configs_for_device(device_id) do
    from(ec in EventConfig,
      join: dec in DeviceEventConfig,
      on: dec.event_config_id == ec.id,
      where: dec.device_id == ^device_id
    )
    |> Repo.all()
    |> Repo.preload([:event_source_configs, :event_target_configs])
  end

  @spec set_device_event_configs(binary(), [binary()]) :: :ok
  def set_device_event_configs(device_id, config_ids) do
    Repo.transaction(fn ->
      from(dec in DeviceEventConfig, where: dec.device_id == ^device_id)
      |> Repo.delete_all()

      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      entries =
        Enum.map(config_ids, fn cid ->
          %{device_id: device_id, event_config_id: cid, inserted_at: now, updated_at: now}
        end)

      if entries != [] do
        Repo.insert_all(DeviceEventConfig, entries)
      end
    end)

    :ok
  end

  @doc """
  Returns the first enabled trigger_recording target config found across all
  event configs assigned to a device.
  """
  @spec trigger_recording_config(binary()) :: EventTargetConfig.t() | nil
  def trigger_recording_config(device_id) do
    from(tc in EventTargetConfig,
      join: ec in EventConfig,
      on: tc.event_config_id == ec.id,
      join: dec in DeviceEventConfig,
      on: dec.event_config_id == ec.id,
      where:
        dec.device_id == ^device_id and
          tc.target_type == "trigger_recording" and
          tc.enabled == true,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Returns all enabled event source configs across all event configs assigned to a device.
  """
  @spec enabled_event_source_configs_for_device(binary()) :: [EventSourceConfig.t()]
  def enabled_event_source_configs_for_device(device_id) do
    from(sc in EventSourceConfig,
      join: ec in EventConfig,
      on: sc.event_config_id == ec.id,
      join: dec in DeviceEventConfig,
      on: dec.event_config_id == ec.id,
      where: dec.device_id == ^device_id and sc.enabled == true
    )
    |> Repo.all()
  end

  @doc """
  Returns the distinct inference pipelines referenced by enabled event source configs
  across all event configs assigned to a device.
  """
  @spec inference_pipelines_for_device(binary()) :: [InferencePipeline.t()]
  def inference_pipelines_for_device(device_id) do
    from(p in InferencePipeline,
      join: sc in EventSourceConfig,
      on: sc.inference_pipeline_id == p.id,
      join: ec in EventConfig,
      on: sc.event_config_id == ec.id,
      join: dec in DeviceEventConfig,
      on: dec.event_config_id == ec.id,
      where: dec.device_id == ^device_id and sc.enabled == true,
      distinct: true
    )
    |> Repo.all()
  end
end
