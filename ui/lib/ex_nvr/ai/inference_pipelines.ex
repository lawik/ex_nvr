defmodule ExNVR.AI.InferencePipelines do
  @moduledoc """
  Returns the list of available inference pipeline implementations determined at
  compile-time based on the Mix target.

  On host (development): only the YOLO/ONNX-based detector is available.
  On rpi4/rpi5 Nerves targets: both YOLO and Hailo detectors are available.
  """

  @pipelines (if Code.ensure_loaded?(Hailo) do
                [
                  {ExNVR.AI.YoloObjectDetector, :yolo_object_detector},
                  {ExNVR.AI.HailoObjectDetector, :hailo_object_detector},
                  {ExNVR.AI.CoralObjectDetector, :coral_object_detector}
                ]
              else
                [
                  {ExNVR.AI.YoloObjectDetector, :yolo_object_detector},
                  {ExNVR.AI.CoralObjectDetector, :coral_object_detector}
                ]
              end)

  @doc """
  Returns the list of available inference pipelines as `{module, key}` tuples.
  """
  @spec list() :: [{module(), atom()}]
  def list, do: @pipelines

  @doc """
  Returns `{label, value}` tuples suitable for use in a Phoenix form select input.
  Labels are derived from each module's `label/0` callback.
  """
  @spec type_options() :: [{String.t(), String.t()}]
  def type_options do
    Enum.map(@pipelines, fn {mod, key} -> {mod.label(), Atom.to_string(key)} end)
  end

  @doc """
  Returns the module for the given pipeline key atom.
  """
  @spec module_for(atom()) :: module() | nil
  def module_for(key) do
    case Enum.find(@pipelines, fn {_mod, k} -> k == key end) do
      {mod, _} -> mod
      nil -> nil
    end
  end

  @doc """
  Returns the config field definitions for a given pipeline type.
  """
  @spec config_fields_for(atom()) :: [ExNVR.AI.InferencePipeline.config_field()]
  def config_fields_for(key) do
    case module_for(key) do
      nil -> []
      mod -> mod.config_fields()
    end
  end
end
