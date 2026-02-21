defmodule ExNVR.Inference.DevicePipeline do
  @moduledoc """
  Join schema for the many-to-many between devices and inference pipelines.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  schema "devices_inference_pipelines" do
    belongs_to :device, ExNVR.Model.Device, type: :binary_id
    belongs_to :inference_pipeline, ExNVR.Inference.Pipeline, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:device_id, :inference_pipeline_id])
    |> validate_required([:device_id, :inference_pipeline_id])
    |> unique_constraint([:device_id, :inference_pipeline_id])
  end
end
