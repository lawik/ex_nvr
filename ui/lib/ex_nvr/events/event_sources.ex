defmodule ExNVR.Events.EventSources do
  @moduledoc """
  Compile-time registry of available event source implementations.
  Mirrors the pattern used by `ExNVR.AI.InferencePipelines`.
  """

  @sources (if Code.ensure_loaded?(Hailo) do
              [
                {ExNVR.AI.YoloObjectDetector, :yolo_object_detector},
                {ExNVR.AI.HailoObjectDetector, :hailo_object_detector}
              ]
            else
              [
                {ExNVR.AI.YoloObjectDetector, :yolo_object_detector}
              ]
            end)

  @spec list() :: [{module(), atom()}]
  def list, do: @sources

  @spec type_options() :: [{String.t(), String.t()}]
  def type_options do
    Enum.map(@sources, fn {mod, key} -> {mod.label(), Atom.to_string(key)} end)
  end

  @spec module_for(atom() | String.t()) :: module() | nil
  def module_for(key) when is_binary(key) do
    module_for(String.to_existing_atom(key))
  rescue
    ArgumentError -> nil
  end

  def module_for(key) when is_atom(key) do
    case Enum.find(@sources, fn {_mod, k} -> k == key end) do
      {mod, _} -> mod
      nil -> nil
    end
  end
end
