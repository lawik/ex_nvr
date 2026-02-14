defmodule ExNVRWeb.GridLive do
  use ExNVRWeb, :live_view

  alias Ecto.Changeset
  alias ExNVR.Devices
  alias ExNVR.Model.Device
  alias ExNVR.Recordings
  alias ExNVRWeb.Components.Future.Bbox
  alias ExNVRWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~H"""
    <div class="grid grid-rows-2 grid-cols-2 gap-4">
      <div :for={device <- @devices} class="relative">
        <div class="relative">
            <video id={"player-#{device.id}"} class="webRtcPlayer z-1" data-device={device.id} data-stream={:high} controls muted autoplay />
            <div class="absolute top-0 left-0 right-0 bottom-0 w-full h-full z-100">
            <%= with size <- @size[device.id], detections <- @detections[device.id] || [] do %>
                <Bbox.variants :for={det <- detections} label={det.class} confidence={Float.round(det.prob, 2)} style={"position: absolute; " <> box_style(size, det)} />
            <% end %>
            </div>
        </div>
        <div class="text-sm font-mono text-black">
            <span :if={fps = @fps[device.id]}>Framepicker: {fps} fps</span>
            <span :if={dfps = @detector_fps[device.id]}>Detector: {dfps} fps</span>
        </div>
        <div :if={detections = @detections[device.id]} class="">
            <div>{inspect(@size[device.id])}</div>
            <div :for={det <- detections} class="flex justify-between">
            <pre>{ debug_detections(det) }</pre>
            </div>
        </div>
      </div>
      <script>
        window.token = "<%= @user_token %>"
      </script>
      <script defer phx-track-static type="module" src={static_path(@socket, "/assets/webrtc.js")} />
    </div>
    """
  end

  defp box_class(%{class: class}) do
    case class do
      "person" -> "border border-green-500 rounded-sm bg-green-500 opacity-50"
      "blue" -> "border border-sky-500 rounded-sm bg-sky-500 opacity-50"
      _ -> "border border-purple-500 rounded-sm bg-purple-500 opacity-50"
    end
  end

  defp label_class(%{class: class}) do
    ""
  end

  defp box_style(%{w: w, h: h}, %{bbox: bbox} = det) do
    left = max(round(bbox.cx - bbox.w / 2), 1)
    top = max(round(bbox.cy - bbox.h / 2), 1)

    """
    left: #{clamper(100 / (w / left))}%;
    top: #{clamper(100 / (h / top))}%;
    width: #{clamper(100 / (w / bbox.w))}%;
    height: #{clamper(100 / (h / bbox.h))}%;
    """
  end

  defp clamper(percent) do
    cond do
      percent > 100 -> 100
      percent < 0 -> 0
      percent -> percent
    end
  end

  defp debug_detections(det) do
    det
    |> Enum.map(fn {key, value} -> "#{key}: #{inspect(value, pretty: true)}" end)
    |> Enum.join("\n")
  end

  def mount(_params, _session, socket) do
    Recordings.subscribe_to_recording_events()

    socket
    |> assign(detections: %{})
    |> assign(size: %{})
    |> assign(fps: %{})
    |> assign(detector_fps: %{})
    |> then(&{:ok, &1})
  end

  def handle_params(params, _uri, socket) do
    devices = Devices.list()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(ExNVR.PubSub, "detections")
      Phoenix.PubSub.subscribe(ExNVR.PubSub, "inference_stats")
    end

    devices = Enum.filter(devices, fn d -> d.state in [:recording, :streaming] end)

    token = Phoenix.Token.sign(socket, "user socket", socket.assigns.current_user.id)

    socket
    |> assign(devices: devices)
    |> assign(user_token: token)
    |> then(&{:noreply, &1})
  end

  def handle_info({:framepicker_fps, device_id, fps}, socket) do
    {:noreply, assign(socket, fps: Map.put(socket.assigns.fps, device_id, fps))}
  end

  def handle_info({:object_detector_fps, device_id, fps}, socket) do
    {:noreply, assign(socket, detector_fps: Map.put(socket.assigns.detector_fps, device_id, fps))}
  end

  def handle_info({:detections, device_id, {w, h}, detections}, socket) do
    detections_map = Map.put(socket.assigns.detections, device_id, detections)

    {:noreply,
     assign(socket,
       detections: detections_map,
       size: Map.put(socket.assigns.size, device_id, %{w: w, h: h})
     )}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}
end
