defmodule ExNVR.Events.EventSource do
  @moduledoc """
  Behaviour for modules that can produce events from PubSub messages.

  An event source subscribes to one or more PubSub topics (e.g. "detections")
  and converts matching messages into high-level events (e.g. "objects_detected")
  that are broadcast on the per-device "events:<device_id>" topic.
  """

  @type config_field :: %{
          name: atom(),
          type: :string | :float | :boolean | :integer | :multi_select,
          label: String.t(),
          required: boolean(),
          default: any(),
          placeholder: String.t() | nil,
          options: [{String.t(), String.t()}] | nil
        }

  @type filter_fun :: (term(), map(), map() -> boolean())

  @doc """
  Returns a map of PubSub topic -> %{event_name => filter_function}.

  The filter function receives `(message, config, device)` and returns
  true if the message should trigger the named event.
  """
  @callback event_definitions() :: %{String.t() => %{String.t() => filter_fun()}}

  @doc "Config fields shown in the UI for this event source type."
  @callback event_config_fields() :: [config_field()]

  @doc "Validate and normalize event source config from user input."
  @callback validate_event_config(map()) :: {:ok, map()} | {:error, Keyword.t()}
end
