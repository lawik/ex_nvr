defmodule ExNVR.Events.EventConfig do
  @moduledoc """
  Schema for a named, reusable event configuration.

  Each event config groups event sources (what triggers events) and event
  targets (what reacts to events). Event configs are assigned to devices
  via a join table, similar to inference pipelines.
  """

  use Ecto.Schema

  alias Ecto.Changeset
  alias ExNVR.Events.{EventSourceConfig, EventTargetConfig}

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "event_configs" do
    field :name, :string

    has_many :event_source_configs, EventSourceConfig
    has_many :event_target_configs, EventTargetConfig

    many_to_many :devices, ExNVR.Model.Device,
      join_through: "devices_event_configs",
      join_keys: [event_config_id: :id, device_id: :id],
      on_replace: :delete

    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(event_config \\ %__MODULE__{}, params) do
    event_config
    |> Changeset.cast(params, [:name])
    |> Changeset.validate_required([:name])
    |> Changeset.unique_constraint(:name)
  end

  def update_changeset(event_config, params) do
    event_config
    |> Changeset.cast(params, [:name])
    |> Changeset.validate_required([:name])
    |> Changeset.unique_constraint(:name)
  end
end
