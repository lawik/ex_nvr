defmodule ExNVR.Events.EventTargetConfig do
  @moduledoc """
  Ecto schema for persisted event target configurations.

  Each record ties an event config to an event target type (e.g. `trigger_recording`)
  with a `config` map holding target-specific settings.
  """

  use Ecto.Schema

  alias Ecto.Changeset
  alias ExNVR.Events.EventTargets

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "event_target_configs" do
    field :target_type, :string
    field :config, :map, default: %{}
    field :enabled, :boolean, default: true

    belongs_to :event_config, ExNVR.Events.EventConfig, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> Changeset.cast(params, [:event_config_id, :target_type, :config, :enabled])
    |> Changeset.validate_required([:event_config_id, :target_type])
    |> validate_config()
  end

  defp validate_config(changeset) do
    target_type = Changeset.get_field(changeset, :target_type)
    config = Changeset.get_field(changeset, :config) || %{}

    case EventTargets.module_for(target_type) do
      nil ->
        Changeset.add_error(changeset, :target_type, "unknown event target type")

      module ->
        case module.validate_target_config(config) do
          {:ok, validated} ->
            Changeset.put_change(changeset, :config, validated)

          {:error, errors} ->
            Enum.reduce(errors, changeset, fn {field, msg}, cs ->
              Changeset.add_error(cs, :config, "#{field}: #{msg}")
            end)
        end
    end
  end
end
