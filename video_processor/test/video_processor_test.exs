defmodule ExNVR.AV.VideoProcessorTest do
  use ExUnit.Case, async: true

  alias ExNVR.AV.VideoProcessor

  describe "new_converter/1" do
    test "new converter" do
      assert converter =
               VideoProcessor.new_converter(
                 in_width: 640,
                 in_height: 480,
                 in_format: :yuv420p,
                 out_width: 320,
                 out_height: 240,
                 out_format: :rgb24,
                 pad?: false
               )

      assert is_reference(converter)
    end
  end

  describe "convert/2" do
    setup do
      %{
        data: File.read!("test/fixtures/encoder/frame_360x240.yuv"),
        options: [
          in_width: 360,
          in_height: 240,
          in_format: :yuv420p,
          out_width: 180,
          out_height: 120,
          out_format: :rgb24,
          pad?: false
        ]
      }
    end

    test "convert a frame", %{data: data, options: options} do
      converter = VideoProcessor.new_converter(options)

      converted_data = VideoProcessor.convert(converter, data)
      assert is_binary(converted_data)
      assert byte_size(converted_data) == 180 * 120 * 3
    end

    test "convert and pad a frame", %{data: data, options: options} do
      converter =
        VideoProcessor.new_converter(Keyword.merge(options, pad?: true, out_height: 180))

      Enum.each(1..10, fn _idx ->
        converted_data = VideoProcessor.convert(converter, data)
        assert is_binary(converted_data)
        assert byte_size(converted_data) == 180 * 180 * 3
      end)
    end

    test "pad centers the content and fills the left and right columns with black" do
      width = 16
      height = 16
      out_width = 32

      red_pixel = <<255, 0, 0>>
      data = :binary.copy(red_pixel, width * height)

      converter =
        VideoProcessor.new_converter(
          in_width: width,
          in_height: height,
          in_format: :rgb24,
          out_width: out_width,
          out_height: height,
          out_format: :rgb24,
          pad?: true
        )

      converted_data = VideoProcessor.convert(converter, data)
      assert byte_size(converted_data) == out_width * height * 3

      left = div(out_width - width, 2)
      black = :binary.copy(<<0, 0, 0>>, left)
      content = :binary.copy(red_pixel, width)

      for row <- rows(converted_data, out_width) do
        assert binary_part(row, 0, left * 3) == black
        assert binary_part(row, left * 3, width * 3) == content
        assert binary_part(row, (left + width) * 3, left * 3) == black
      end
    end

    test "pad centers the content and fills the top and bottom rows with black" do
      width = 16
      height = 8
      out_height = 16

      red_pixel = <<255, 0, 0>>
      data = :binary.copy(red_pixel, width * height)

      converter =
        VideoProcessor.new_converter(
          in_width: width,
          in_height: height,
          in_format: :rgb24,
          out_width: width,
          out_height: out_height,
          out_format: :rgb24,
          pad?: true
        )

      converted_data = VideoProcessor.convert(converter, data)
      assert byte_size(converted_data) == width * out_height * 3

      top = div(out_height - height, 2)
      black_row = :binary.copy(<<0, 0, 0>>, width)
      red_row = :binary.copy(red_pixel, width)

      {top_rows, rest} = converted_data |> rows(width) |> Enum.split(top)
      {content_rows, bottom_rows} = Enum.split(rest, height)

      assert top_rows == List.duplicate(black_row, top)
      assert content_rows == List.duplicate(red_row, height)
      assert bottom_rows == List.duplicate(black_row, out_height - height - top)
    end
  end

  defp rows(data, width) do
    row_size = width * 3
    for <<row::binary-size(row_size) <- data>>, do: row
  end
end
