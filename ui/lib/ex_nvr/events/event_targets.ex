defmodule ExNVR.Events.EventTargets do
  @moduledoc """
  Compile-time registry of available event target implementations.
  """

  alias ExNVR.Events.Targets

  @targets [
    {Targets.TriggerRecording, :trigger_recording},
    {Targets.DeveloperLog, :developer_log},
    {Targets.GridOverlay, :grid_overlay}
  ]

  @spec list() :: [{module(), atom()}]
  def list, do: @targets

  @spec type_options() :: [{String.t(), String.t()}]
  def type_options do
    Enum.map(@targets, fn {mod, key} -> {mod.label(), Atom.to_string(key)} end)
  end

  @spec module_for(atom() | String.t()) :: module() | nil
  def module_for(key) when is_binary(key) do
    module_for(String.to_existing_atom(key))
  rescue
    ArgumentError -> nil
  end

  def module_for(key) when is_atom(key) do
    case Enum.find(@targets, fn {_mod, k} -> k == key end) do
      {mod, _} -> mod
      nil -> nil
    end
  end
end
