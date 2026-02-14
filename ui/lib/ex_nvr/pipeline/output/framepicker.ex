defmodule ExNVR.Pipeline.Output.Framepicker do
  @moduledoc """
  Extract frames from stream. The element will only decode keyframes.
  """

  use Membrane.Sink

  require ExNVR.Utils
  require Membrane.Logger

  import ExNVR.MediaUtils, only: [to_annexb: 1]

  alias ExNVR.AV.{Decoder, VideoProcessor}
  alias Membrane.{Buffer, H264, H265}

  def_input_pad(:input,
    accepted_format:
      any_of(
        %H264{alignment: :au},
        %H265{alignment: :au}
      )
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
      default: 1280,
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
        last_buffer_pts: nil
      })

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

      decoder = Decoder.new(codec, out_height: out_height, out_width: state.frame_width)

      {[], %{state | frame_height: out_height, decoder: decoder}}
    else
      {[], state}
    end
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) when ExNVR.Utils.keyframe(buffer) do
    last_pts = state.last_buffer_pts || Buffer.get_dts_or_pts(buffer)

    do_decode(buffer, state)
  end

  @impl true
  def handle_buffer(:input, _buffer, _ctx, state), do: {[], state}

  defp do_decode(buffer, state) do
    with [decoded] <- Decoder.decode(state.decoder, to_annexb(buffer.payload)),
         jpeg_image <- VideoProcessor.encode_to_jpeg(decoded) do
      Membrane.Logger.info("Frame for #{state.device_id}")

      if state.device_id do
        Phoenix.PubSub.broadcast(
          ExNVR.PubSub,
          "frames",
          {:frame, state.device_id, jpeg_image}
        )
      end

      {[], state}
    else
      error ->
        Membrane.Logger.error("Failed to pick frame: #{inspect(error)}")
        {[], state}
    end
  end
end
