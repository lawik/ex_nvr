defmodule ExNVR.Repo.Migrations.CreateInferencePipelines do
  use Ecto.Migration

  def change do
    create table("inference_pipelines", primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :config, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("inference_pipelines", [:name])

    create table("devices_inference_pipelines", primary_key: false) do
      add :device_id, references("devices", type: :binary_id, on_delete: :delete_all), null: false

      add :inference_pipeline_id,
          references("inference_pipelines", type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("devices_inference_pipelines", [:device_id, :inference_pipeline_id])
    create index("devices_inference_pipelines", [:inference_pipeline_id])
  end
end
