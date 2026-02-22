defmodule ExNVR.Inference do
  @moduledoc """
  Context for managing inference pipeline configurations.
  """

  import Ecto.Query

  alias ExNVR.Inference.Pipeline
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

  @spec pipeline_options() :: [{String.t(), binary()}]
  def pipeline_options do
    list_pipelines()
    |> Enum.map(fn p -> {p.name, p.id} end)
  end
end
