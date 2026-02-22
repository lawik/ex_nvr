defmodule ExNVR.Events.Targets.GridOverlay do
  @moduledoc """
  Standalone event target that acts as a flag for whether bounding box
  overlays should be shown on the grid live view.

  The grid_live view already subscribes to the "detections" PubSub topic.
  This target simply indicates the user wants detection overlays enabled
  for this device — the grid_live checks whether a grid_overlay target
  is configured.
  """

  @behaviour ExNVR.Events.EventTarget

  @impl true
  def label, do: "Grid Overlay"

  @impl true
  def target_type, do: :standalone

  @impl true
  def target_config_fields, do: []

  @impl true
  def validate_target_config(_config), do: {:ok, %{}}

  # No GenServer needed — this target acts as a configuration flag.
  # The grid_live queries event_target_configs to check if this target
  # is enabled for a given device.
end
