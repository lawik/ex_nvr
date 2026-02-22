defmodule ExNVR.Events.EventTarget do
  @moduledoc """
  Behaviour for modules that react to events on the per-device event topic.

  Targets come in two flavours:

  * `:pipeline` — Injects elements into the Membrane pipeline
    (e.g. `TriggerRecording` configures a `VideoBufferer`).
  * `:standalone` — Runs as an independent GenServer
    (e.g. `DeveloperLog` logs events, `GridOverlay` toggles bbox display).
  """

  @type config_field :: %{
          name: atom(),
          type: :string | :float | :boolean | :integer | :select,
          label: String.t(),
          required: boolean(),
          default: any(),
          placeholder: String.t() | nil,
          options: [{String.t(), String.t()}] | nil
        }

  @callback label() :: String.t()
  @callback target_config_fields() :: [config_field()]
  @callback validate_target_config(map()) :: {:ok, map()} | {:error, Keyword.t()}
  @callback target_type() :: :pipeline | :standalone
end
