defmodule ExNVRWeb.GridLive do
  use ExNVRWeb, :live_view

  alias Ecto.Changeset
  alias ExNVR.Devices
  alias ExNVR.Model.Device
  alias ExNVR.Recordings
  alias ExNVRWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~H"""
    <div class="grid grid-rows-2 grid-cols-2 gap-4">
      <div :for={device <- @devices} class="relative">
        <video id={"player-#{device.id}"} class="webRtcPlayer" data-device={device.id} data-stream={:high} controls muted autoplay />
        <div :if={detections = @detections[device.id]} class="absolute bottom-0 left-0 right-0 bg-black/70 text-white text-xs p-2 max-h-24 overflow-y-auto">
          <div :for={det <- detections} class="flex justify-between">
            <span><%= det.class %></span>
            <span><%= Float.round(det.prob * 100, 1) %>%</span>
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

  def mount(_params, _session, socket) do
    Recordings.subscribe_to_recording_events()

    socket
    |> assign(detections: %{})
    |> then(&{:ok, &1})
  end

  def handle_params(params, _uri, socket) do
    devices = Devices.list()

    if connected?(socket) do
      Enum.each(devices, fn device ->
        Phoenix.PubSub.subscribe(ExNVR.PubSub, "detections:#{device.id}")
      end)
    end

    device =
      Enum.find(devices, List.first(devices), &(&1.id == params["device_id"]))

    token = Phoenix.Token.sign(socket, "user socket", socket.assigns.current_user.id)

    socket
    |> assign(devices: devices)
    |> assign(current_device: device)
    |> assign(user_token: token)
    |> then(&{:noreply, &1})
  end

  def handle_info({:detections, device_id, detections}, socket) do
    detections_map = Map.put(socket.assigns.detections, device_id, detections)
    {:noreply, assign(socket, detections: detections_map)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}
end
