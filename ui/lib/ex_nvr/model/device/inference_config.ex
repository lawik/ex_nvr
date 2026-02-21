defmodule ExNVR.Model.Device.InferenceConfig do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          enabled: boolean(),
          pipeline: atom(),
          model_path: binary(),
          classes_path: binary(),
          only_keyframes: boolean()
        }

  @primary_key false
  embedded_schema do
    field :enabled, :boolean, default: false
    field :pipeline, Ecto.Enum,
      values: [:yolo_object_detector, :hailo_object_detector],
      default: :yolo_object_detector
    field :model_path, :string
    field :classes_path, :string
    field :only_keyframes, :boolean, default: true
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params) do
    changeset = cast(struct, params, __MODULE__.__schema__(:fields))
    enabled = get_field(changeset, :enabled)
    validate_config(changeset, enabled)
  end

  defp validate_config(changeset, true) do
    inference_config = Application.get_env(:ex_nvr, :inference, [])

    changeset
    |> maybe_set_default(:model_path, Keyword.get(inference_config, :model_path))
    |> maybe_set_default(:classes_path, Keyword.get(inference_config, :classes_path))
    |> validate_required([:pipeline, :model_path])
  end

  defp validate_config(changeset, _enabled) do
    changeset
    |> put_change(:pipeline, :yolo_object_detector)
    |> put_change(:model_path, nil)
    |> put_change(:classes_path, nil)
    |> put_change(:only_keyframes, true)
  end

  defp maybe_set_default(changeset, field, default) do
    if get_field(changeset, field) in [nil, ""] and not is_nil(default) do
      put_change(changeset, field, default)
    else
      changeset
    end
  end
end
