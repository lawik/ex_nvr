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
      <video :for={device <- @devices} id={"player-#{device.id}"} class="webRtcPlayer" data-device={device.id} data-stream={:high} controls muted autoplay />
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
    |> then(&{:ok, &1})
  end

  def handle_params(params, _uri, socket) do
    devices = Devices.list()

    device =
      Enum.find(devices, List.first(devices), &(&1.id == params["device_id"]))

    token = Phoenix.Token.sign(socket, "user socket", socket.assigns.current_user.id)

    socket
    |> assign(devices: devices)
    |> assign(current_device: device)
    |> assign(user_token: token)
    |> then(&{:noreply, &1})
  end
end
