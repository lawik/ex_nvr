defmodule ExNVR.Pipeline.Output.Framepicker do
  @moduledoc """
  Extract frames from stream with backpressure support.

  Stores only the latest eligible raw buffer. When the downstream element
  (e.g. an object detector) sends demand, the most recent buffer is
  decoded and forwarded. This avoids wasting CPU on decoding frames
  that will be replaced before inference gets to them.
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
    frame_height: [
      spec: non_neg_integer() | nil,
      default: nil,
      description: "The height of the generated frame. When nil, matches frame_width."
    ],
    pad: [
      spec: boolean(),
      default: false,
      description: "When true, pad the frame to fit the target dimensions (letterbox)."
    ],
    out_format: [
      spec: :rgb24 | :bgr24 | nil,
      default: :rgb24,
      description: "Output pixel format for the decoded frame."
    ],
    device_id: [
      spec: binary() | nil,
      default: nil,
      description: "Device ID used for broadcasting frames via PubSub"
    ],
    only_keyframes: [
      spec: boolean(),
      default: true,
      description: "When true, only decode keyframes. When false, decode every frame."
    ]
  )

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        decoder: nil,
        orig_width: nil,
        orig_height: nil,
        pending_buffer: nil,
        demand: 0
      })
      |> Map.update!(:frame_height, fn h -> h || options.frame_width end)
      |> Map.put(:ts, System.monotonic_time(:millisecond))

    Process.set_label(:framepicker)

    {[], state}
  end

  @impl true
  def handle_stream_format(:input, format, ctx, state) do
    old_stream_format = ctx.pads.input.stream_format

    if is_nil(old_stream_format) or old_stream_format != format do
      codec = if is_struct(format, H264), do: :h264, else: :hevc

      decoder =
        Decoder.new(codec,
          out_width: state.frame_width,
          out_height: state.frame_height,
          out_format: state.out_format,
          pad: state.pad
        )

      raw_video_format = %RawVideo{
        width: state.frame_width,
        height: state.frame_height,
        framerate: nil,
        pixel_format: :RGB,
        aligned: true
      }

      {[stream_format: {:output, raw_video_format}],
       %{state | decoder: decoder, orig_width: format.width, orig_height: format.height}}
    else
      {[], state}
    end
  end

  def handle_stream_format(any, format, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, %{} = state) when ExNVR.Utils.keyframe(buffer) do
    maybe_send(%{state | pending_buffer: buffer})
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, %{only_keyframes: false} = state) do
    maybe_send(%{state | pending_buffer: buffer})
  end

  @impl true
  def handle_buffer(:input, _buffer, _ctx, state), do: {[], state}

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    maybe_send(%{state | demand: state.demand + size})
  end

  defp maybe_send(%{pending_buffer: buffer, demand: demand} = state)
       when buffer != nil and demand > 0 do
    decode_and_send(buffer, %{state | pending_buffer: nil})
  end

  defp maybe_send(%{demand: demand} = state) do
    {[], state}
  end

  defp decode_and_send(buffer, %{demand: demand} = state) do
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

      frame = %Buffer{
        payload: decoded.data,
        metadata: %{
          grabbed_at: ts,
          orig_width: state.orig_width,
          orig_height: state.orig_height
        }
      }

      {[buffer: {:output, frame}], %{state | ts: ts, demand: demand - 1}}
    else
      error ->
        Membrane.Logger.warning("Failed to pick frame: #{inspect(error)}")
        {[], state}
    end
  end
end
