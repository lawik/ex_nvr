defmodule ExNVR.Inference do
  @moduledoc """
  Context for managing inference pipeline configurations.
  """

  import Ecto.Query

  alias ExNVR.Inference.{DevicePipeline, Pipeline}
  alias ExNVR.Repo

  # --- Pipeline CRUD ---

  @spec create_pipeline(map()) :: {:ok, Pipeline.t()} | {:error, Ecto.Changeset.t()}
  def create_pipeline(params) do
    params
    |> Pipeline.create_changeset()
    |> Repo.insert()
  end

  @spec update_pipeline(Pipeline.t(), map()) :: {:ok, Pipeline.t()} | {:error, Ecto.Changeset.t()}
  def update_pipeline(%Pipeline{} = pipeline, params) do
    pipeline
    |> Pipeline.update_changeset(params)
    |> Repo.update()
  end

  @spec get_pipeline(binary()) :: Pipeline.t() | nil
  def get_pipeline(id), do: Repo.get(Pipeline, id)

  @spec get_pipeline!(binary()) :: Pipeline.t()
  def get_pipeline!(id), do: Repo.get!(Pipeline, id)

  @spec list_pipelines() :: [Pipeline.t()]
  def list_pipelines do
    Pipeline
    |> order_by([p], p.inserted_at)
    |> Repo.all()
  end

  @spec delete_pipeline(Pipeline.t()) :: :ok | {:error, Ecto.Changeset.t()}
  def delete_pipeline(%Pipeline{} = pipeline) do
    case Repo.delete(pipeline) do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec change_pipeline_creation(Pipeline.t(), map()) :: Ecto.Changeset.t()
  def change_pipeline_creation(%Pipeline{} = pipeline \\ %Pipeline{}, attrs \\ %{}) do
    Pipeline.create_changeset(pipeline, attrs)
  end

  @spec change_pipeline_update(Pipeline.t(), map()) :: Ecto.Changeset.t()
  def change_pipeline_update(%Pipeline{} = pipeline, attrs \\ %{}) do
    Pipeline.update_changeset(pipeline, attrs)
  end

  # --- Device association ---

  @spec pipelines_for_device(binary()) :: [Pipeline.t()]
  def pipelines_for_device(device_id) do
    from(p in Pipeline,
      join: dp in DevicePipeline,
      on: dp.inference_pipeline_id == p.id,
      where: dp.device_id == ^device_id
    )
    |> Repo.all()
  end

  @spec set_device_pipelines(binary(), [binary()]) :: :ok
  def set_device_pipelines(device_id, pipeline_ids) do
    Repo.transaction(fn ->
      from(dp in DevicePipeline, where: dp.device_id == ^device_id)
      |> Repo.delete_all()

      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      entries =
        Enum.map(pipeline_ids, fn pid ->
          %{
            device_id: device_id,
            inference_pipeline_id: pid,
            inserted_at: now,
            updated_at: now
          }
        end)

      if entries != [] do
        Repo.insert_all(DevicePipeline, entries)
      end
    end)

    :ok
  end

  @spec pipeline_options() :: [{String.t(), binary()}]
  def pipeline_options do
    list_pipelines()
    |> Enum.map(fn p -> {p.name, p.id} end)
  end
end
