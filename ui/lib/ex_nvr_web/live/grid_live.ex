defmodule ExNVRWeb.GridLive do
  use ExNVRWeb, :live_view

  alias ExNVR.Devices
  alias ExNVR.Triggers.Targets.GridBboxes
  alias ExNVRWeb.Components.Vision.Bbox

  def render(assigns) do
    ~H"""
    <div class="bg-black pt-12 grid grid-rows-1 grid-cols-2 gap-2 items-start min-h-screen w-full">
      <div :for={device <- @devices} class="relative">
        <div class="relative">
          <div
            phx-hook="WebRtcPlayer"
            phx-update="ignore"
            id={"player-wrap-#{device.id}"}
            data-device={device.id}
            data-stream={:high}
            data-token={@user_token}
          >
            <video class="w-full z-1 hidden" controls muted autoplay />
          </div>
          <div
            :if={device.id in @active}
            class="absolute top-0 left-0 right-0 bottom-0 w-full h-full z-100"
          >
            <%= with size <- @size[device.id], detections <- @detections[device.id] || [], style <- @style[device.id] || :corner_brackets do %>
              <Bbox.bbox
                :for={det <- detections}
                style_name={style}
                label={det.class}
                confidence={Float.round(det.prob, 2)}
                style={"position: absolute; " <> box_style(size, det)}
              />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp box_style(%{w: w, h: h}, %{bbox: bbox}) do
    left = max(round(bbox.cx - bbox.w / 2), 1)
    top = max(round(bbox.cy - bbox.h / 2), 1)

    l = clamper(100 / (w / left))
    t = clamper(100 / (h / top))

    """
    left: #{l}%;
    top: #{t}%;
    width: #{total_clamp(100 / (w / bbox.w), l)}%;
    height: #{total_clamp(100 / (h / bbox.h), t)}%;
    """
  end

  defp clamper(percent) do
    cond do
      percent >= 99.5 -> 99.5
      percent <= 0.5 -> 0.5
      percent -> percent
    end
  end

  defp total_clamp(percent, added) do
    max = 99.5
    min = 0.5

    cond do
      percent + added >= max -> max - added
      percent + added <= min -> min - added
      percent -> percent
    end
  end

  def mount(_params, _session, socket) do
    socket
    |> assign(detections: %{})
    |> assign(size: %{})
    |> assign(style: %{})
    |> assign(active: MapSet.new())
    |> then(&{:ok, &1})
  end

  def handle_params(_params, _uri, socket) do
    devices = Devices.list()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(ExNVR.PubSub, GridBboxes.topic())
    end

    devices = Enum.filter(devices, fn d -> d.state in [:recording, :streaming] end)

    token = Phoenix.Token.sign(socket, "user socket", socket.assigns.current_user.id)

    socket
    |> assign(devices: devices)
    |> assign(user_token: token)
    |> then(&{:noreply, &1})
  end

  def handle_info({:grid_detections, device_id, {w, h}, detections, style}, socket) do
    {:noreply,
     assign(socket,
       detections: Map.put(socket.assigns.detections, device_id, detections),
       size: Map.put(socket.assigns.size, device_id, %{w: w, h: h}),
       style: Map.put(socket.assigns.style, device_id, style)
     )}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  def handle_event("webrtc_active", %{"device_id" => device_id}, socket) do
    {:noreply, assign(socket, active: MapSet.put(socket.assigns.active, device_id))}
  end

  def handle_event("webrtc_inactive", %{"device_id" => device_id}, socket) do
    {:noreply, assign(socket, active: MapSet.delete(socket.assigns.active, device_id))}
  end
end
