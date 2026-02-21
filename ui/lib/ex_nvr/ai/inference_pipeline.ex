defmodule ExNVR.AI.InferencePipeline do
  @moduledoc """
  Behaviour for inference pipeline implementations.

  Each implementation declares its config fields (for form rendering),
  validates a config map, and builds a Membrane pipeline spec fragment.
  """

  @type config_field :: %{
          name: atom(),
          type: :string | :float | :boolean,
          label: String.t(),
          default: any(),
          required: boolean(),
          placeholder: String.t() | nil
        }

  @doc "Returns the human-readable label for this pipeline type."
  @callback label() :: String.t()

  @doc "Returns a list of config field definitions for rendering in the form UI."
  @callback config_fields() :: [config_field()]

  @doc """
  Validates the config map. Returns `{:ok, validated_config}` or `{:error, errors}`.
  Errors should be a keyword list of `{field, message}` tuples.
  """
  @callback validate_config(config :: map()) :: {:ok, map()} | {:error, Keyword.t()}

  @doc """
  Builds the Membrane pipeline spec fragment for this inference pipeline.

  Returns a list of Membrane spec link segments starting from `get_child(:tee)`.
  The `pipeline_id` is used for unique child naming when multiple pipelines
  are attached to the same device.
  """
  @callback build_spec(device_id :: binary(), config :: map(), pipeline_id :: binary()) :: list()

  @doc "Parses a value as float, returning default if parsing fails."
  @spec parse_float(any(), float()) :: float()
  def parse_float(nil, default), do: default
  def parse_float(v, _default) when is_float(v), do: v
  def parse_float(v, _default) when is_integer(v), do: v / 1

  def parse_float(v, default) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> default
    end
  end

  def parse_float(_, default), do: default

  @doc "Parses a value as boolean, returning default if parsing fails."
  @spec parse_bool(any(), boolean()) :: boolean()
  def parse_bool(nil, default), do: default
  def parse_bool(v, _) when is_boolean(v), do: v
  def parse_bool("true", _), do: true
  def parse_bool("false", _), do: false
  def parse_bool(_, default), do: default
end
