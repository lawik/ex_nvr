defmodule ExNVR.Repo.Migrations.DropDevicesInferencePipelines do
  use Ecto.Migration

  def change do
    drop_if_exists index("devices_inference_pipelines", [:device_id, :inference_pipeline_id])
    drop_if_exists index("devices_inference_pipelines", [:inference_pipeline_id])
    drop_if_exists table("devices_inference_pipelines")
  end
end
