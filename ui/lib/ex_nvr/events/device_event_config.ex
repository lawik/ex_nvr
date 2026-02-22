defmodule ExNVR.Events.DeviceEventConfig do
  @moduledoc """
  Join schema for the many-to-many between devices and event configs.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  schema "devices_event_configs" do
    belongs_to :device, ExNVR.Model.Device, type: :binary_id
    belongs_to :event_config, ExNVR.Events.EventConfig, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:device_id, :event_config_id])
    |> validate_required([:device_id, :event_config_id])
    |> unique_constraint([:device_id, :event_config_id])
  end
end
