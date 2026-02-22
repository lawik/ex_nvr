defmodule ExNVR.Events.Targets.TriggerRecording do
  @moduledoc """
  Pipeline event target that configures a `VideoBufferer` in the Membrane
  pipeline to gate recording on/off based on events.

  This target does not run as a GenServer — its config is read by the
  Main pipeline to set up the VideoBufferer element options.
  """

  @behaviour ExNVR.Events.EventTarget

  @impl true
  def label, do: "Trigger Recording"

  @impl true
  def target_type, do: :pipeline

  @impl true
  def target_config_fields do
    [
      %{
        name: :event_timeout,
        type: :integer,
        label: "Event timeout (ms)",
        required: false,
        default: 30_000,
        placeholder: "30000",
        options: nil
      },
      %{
        name: :buffer_limit_type,
        type: :select,
        label: "Buffer limit type",
        required: false,
        default: "keyframes",
        placeholder: nil,
        options: [{"Keyframes", "keyframes"}, {"Seconds", "seconds"}, {"Bytes", "bytes"}]
      },
      %{
        name: :buffer_limit_value,
        type: :integer,
        label: "Buffer limit value",
        required: false,
        default: 3,
        placeholder: "3",
        options: nil
      }
    ]
  end

  @impl true
  def validate_target_config(config) do
    config = for {k, v} <- config, into: %{}, do: {to_string(k), v}

    {:ok,
     %{
       "event_timeout" => parse_int(config["event_timeout"], 30_000),
       "buffer_limit_type" => config["buffer_limit_type"] || "keyframes",
       "buffer_limit_value" => parse_int(config["buffer_limit_value"], 3)
     }}
  end

  @doc "Convert stored config to VideoBufferer option values."
  @spec to_bufferer_opts(map()) :: Keyword.t()
  def to_bufferer_opts(config) do
    limit_type =
      case config["buffer_limit_type"] do
        "seconds" -> :seconds
        "bytes" -> :bytes
        _ -> :keyframes
      end

    [
      event_timeout: config["event_timeout"] || 30_000,
      limit: {limit_type, config["buffer_limit_value"] || 3}
    ]
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, _default) when is_integer(val), do: val

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(_, default), do: default
end
