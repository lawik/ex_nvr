defmodule ExNVR.Pipeline.Output.Framepicker do
  @moduledoc """
  Extract frames from stream. The element will only decode keyframes.

  Holds on to the latest decoded frame and only forwards it when the
  downstream element (ObjectDetector) signals demand. This ensures the
  detector always receives the most recent frame rather than working
  through a stale queue.
  """

  use Membrane.Filter

  require ExNVR.Utils
  require Membrane.Logger

  import ExNVR.MediaUtils, only: [to_annexb: 1]

  alias ExNVR.AV.Decoder
  alias Membrane.{Buffer, H264, H265, RawVideo}

  def_input_pad(:input,
    accepted_format:
      any_of(
        %H264{alignment: :au},
        %H265{alignment: :au}
      )
  )

  def_output_pad(:output,
    accepted_format: RawVideo,
    flow_control: :manual
  )

  def_options(
    interval: [
      spec: integer(),
      default: 10,
      description: """
      The rate of frames generation.
      Defaults to one frame per 10 seconds.
      """
    ],
    frame_width: [
      spec: non_neg_integer(),
      default: 640,
      description: "The width of the generated frame"
    ],
    device_id: [
      spec: binary() | nil,
      default: nil,
      description: "Device ID used for broadcasting frames via PubSub"
    ]
  )

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        frame_height: nil,
        decoder: nil,
        last_buffer_pts: nil,
        latest_frame: nil,
        demand: 0
      })
      |> Map.put(:ts, System.monotonic_time(:millisecond))

    Process.set_label(:framepicker)

    {[], state}
  end

  @impl true
  def handle_stream_format(:input, format, ctx, state) do
    old_stream_format = ctx.pads.input.stream_format

    if is_nil(old_stream_format) or old_stream_format != format do
      codec = if is_struct(format, H264), do: :h264, else: :hevc

      out_height = div(state.frame_width * format.height, format.width)
      out_height = out_height - rem(out_height, 2)
      # out_height = 640

      decoder =
        Decoder.new(codec,
          out_height: out_height,
          out_width: state.frame_width,
          out_format: :rgb24
        )

      raw_video_format = %RawVideo{
        width: state.frame_width,
        height: out_height,
        framerate: nil,
        pixel_format: :RGB,
        aligned: true
      }

      {[stream_format: {:output, raw_video_format}],
       %{state | frame_height: out_height, decoder: decoder}}
    else
      {[], state}
    end
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) when ExNVR.Utils.keyframe(buffer) do
    do_decode(buffer, state)
  end

  @impl true
  def handle_buffer(:input, _buffer, _ctx, state), do: {[], state}

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    state = %{state | demand: state.demand + size}
    maybe_send_frame(state)
  end

  defp do_decode(buffer, state) do
    with [decoded] <- Decoder.decode(state.decoder, to_annexb(buffer.payload)) do
      ts = System.monotonic_time(:millisecond)
      diff = ts - state.ts
      fps = if diff > 0, do: Float.round(1000 / diff, 2), else: 0.0

      if state.device_id do
        Phoenix.PubSub.broadcast(
          ExNVR.PubSub,
          "inference_stats",
          {:framepicker_fps, state.device_id, fps}
        )
      end

      state = %{
        state
        | latest_frame: %Buffer{payload: decoded.data, metadata: %{grabbed_at: ts}},
          ts: ts
      }

      maybe_send_frame(state)
    else
      error ->
        Membrane.Logger.error("Failed to pick frame: #{inspect(error)}")
        {[], state}
    end
  end

  defp maybe_send_frame(%{latest_frame: frame, demand: demand} = state)
       when frame != nil and demand > 0 do
    {[buffer: {:output, frame}], %{state | latest_frame: nil, demand: demand - 1}}
  end

  defp maybe_send_frame(state), do: {[], state}
end
