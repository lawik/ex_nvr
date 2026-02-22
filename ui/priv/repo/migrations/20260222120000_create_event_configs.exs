defmodule ExNVR.Repo.Migrations.CreateEventConfigs do
  use Ecto.Migration

  def change do
    create table("event_configs", primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("event_configs", [:name])

    create table("event_source_configs", primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :event_config_id,
          references("event_configs", type: :binary_id, on_delete: :delete_all),
          null: false

      add :source_type, :string, null: false

      add :inference_pipeline_id,
          references("inference_pipelines", type: :binary_id, on_delete: :nilify_all)

      add :config, :map, default: %{}, null: false
      add :enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index("event_source_configs", [:event_config_id])

    create table("event_target_configs", primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :event_config_id,
          references("event_configs", type: :binary_id, on_delete: :delete_all),
          null: false

      add :target_type, :string, null: false
      add :config, :map, default: %{}, null: false
      add :enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index("event_target_configs", [:event_config_id])

    create table("devices_event_configs", primary_key: false) do
      add :device_id, references("devices", type: :binary_id, on_delete: :delete_all), null: false

      add :event_config_id,
          references("event_configs", type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("devices_event_configs", [:device_id, :event_config_id])
    create index("devices_event_configs", [:event_config_id])
  end
end
