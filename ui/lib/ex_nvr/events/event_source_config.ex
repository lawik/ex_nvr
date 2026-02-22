defmodule ExNVR.Events.EventSourceConfig do
  @moduledoc """
  Ecto schema for persisted event source configurations.

  Each record ties an event config to an event source type (e.g. `yolo_object_detector`)
  and optionally to a specific inference pipeline. The `config` map holds
  source-specific settings like which detection classes to react to.
  """

  use Ecto.Schema

  alias Ecto.Changeset
  alias ExNVR.Events.EventSources

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "event_source_configs" do
    field :source_type, :string
    field :config, :map, default: %{}
    field :enabled, :boolean, default: true

    belongs_to :event_config, ExNVR.Events.EventConfig, type: :binary_id
    belongs_to :inference_pipeline, ExNVR.Inference.Pipeline, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> Changeset.cast(params, [
      :event_config_id,
      :source_type,
      :inference_pipeline_id,
      :config,
      :enabled
    ])
    |> Changeset.validate_required([:event_config_id, :source_type])
    |> validate_config()
  end

  defp validate_config(changeset) do
    source_type = Changeset.get_field(changeset, :source_type)
    config = Changeset.get_field(changeset, :config) || %{}

    case EventSources.module_for(source_type) do
      nil ->
        Changeset.add_error(changeset, :source_type, "unknown event source type")

      module ->
        case module.validate_event_config(config) do
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
