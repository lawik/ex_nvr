defmodule ExNVR.Repo.Migrations.AddInferenceConfigToDevice do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :inference_config, :map
    end
  end
end
