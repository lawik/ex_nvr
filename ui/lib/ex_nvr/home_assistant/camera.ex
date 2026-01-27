defmodule ExNVR.HomeAssistant.Camera do
  use Homex.Entity.Camera, name: "camera-1", image_encoding: "b64", update_interval: 5_000

  def handle_message({:thumbnail, img}, entity) do
    entity |> put_private(:thumbnail, img)
  end

  def handle_timer(%{private: %{thumbnail: img}} = entity) do
    binary = img.path |> File.read!() |> Base.encode64()

    entity
    |> set_image(binary)
    |> set_attributes(%{width: img.width, height: img.height})
  end

  def handle_timer(entity) do
    entity
  end
end
