defmodule ExNVR.Inference.Pipeline do
  @moduledoc """
  Schema for a named, reusable inference pipeline configuration.

  Each pipeline has a type (matching an implementation module) and a config
  map that is validated by the implementation module's `validate_config/1`.
  """

  use Ecto.Schema

  alias Ecto.Changeset

  @type t :: %__MODULE__{
          id: binary() | nil,
          name: String.t(),
          type: atom(),
          config: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @available_types (if Code.ensure_loaded?(Hailo) do
                      [:yolo_object_detector, :hailo_object_detector]
                    else
                      [:yolo_object_detector]
                    end)

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "inference_pipelines" do
    field :name, :string
    field :type, Ecto.Enum, values: @available_types
    field :config, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(pipeline \\ %__MODULE__{}, params) do
    pipeline
    |> Changeset.cast(params, [:name, :type, :config])
    |> Changeset.validate_required([:name, :type])
    |> Changeset.unique_constraint(:name)
    |> validate_config_with_implementation()
  end

  def update_changeset(pipeline, params) do
    pipeline
    |> Changeset.cast(params, [:name, :config])
    |> Changeset.validate_required([:name])
    |> validate_config_with_implementation()
  end

  defp validate_config_with_implementation(changeset) do
    type = Changeset.get_field(changeset, :type)
    config = Changeset.get_field(changeset, :config) || %{}

    case ExNVR.Inference.InferencePipelines.module_for(type) do
      nil ->
        Changeset.add_error(changeset, :type, "unknown pipeline type")

      module ->
        case module.validate_config(config) do
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
