defmodule ExNVRWeb.GridLive do
  use ExNVRWeb, :live_view

  alias ExNVR.Devices
  alias ExNVR.Recordings
  alias ExNVRWeb.Components.Future.Bbox

  def render(assigns) do
    ~H"""
    <div class="bg-black pt-12 grid grid-rows-1 grid-cols-2 gap-2 min-h-screen w-full">
      <div :for={device <- @devices} class="relative">
        <div class="relative">
            <video phx-update="ignore" id={"player-#{device.id}"} class="webRtcPlayer w-full z-1 hidden" data-device={device.id} data-stream={:high} controls muted autoplay />
            <div class="absolute top-0 left-0 right-0 bottom-0 w-full h-full z-100">
            <%= with size <- @size[device.id], detections <- @detections[device.id] || [] do %>
                <Bbox.variants :for={det <- detections} label={det.class} confidence={Float.round(det.prob, 2)} style={"position: absolute; " <> box_style(size, det)} log={det_log(det, @size[device.id], @fps[device.id], @detector_fps[device.id], @inference_time[device.id], @latency[device.id])} />
                <pre class="text-white bg-black">{ @inference_time[device.id] }ms</pre>
            <% end %>
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

  defp box_style(%{w: w, h: h}, %{bbox: bbox}) do
    left = max(round(bbox.cx - bbox.w / 2), 1)
    top = max(round(bbox.cy - bbox.h / 2), 1)
    IO.inspect({left, top}, label: "box pos")

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

  defp det_log(det, size, fps, detector_fps, inference_time, latency) do
    bbox = det.bbox
    hex_id = det.class_idx |> Integer.to_string(16) |> String.pad_leading(4, "0")
    conf = Float.round(det.prob * 100, 1)

    lines = [
      "OBJ 0x#{hex_id} cls=#{det.class} conf=#{conf}%",
      "POS cx:#{bbox.cx} cy:#{bbox.cy} w:#{bbox.w} h:#{bbox.h}"
    ]

    lines = if size, do: lines ++ ["SRC #{size.w}x#{size.h} buf_active"], else: lines
    lines = if fps, do: lines ++ ["FRMK #{fps}fps pipe_ok"], else: lines
    lines = if detector_fps, do: lines ++ ["YOLO #{detector_fps}fps model_run"], else: lines
    lines = if inference_time, do: lines ++ ["INFER t=#{inference_time}ms gpu_exec"], else: lines
    lines = if latency, do: lines ++ ["LATNC delta=#{latency}ms e2e"], else: lines

    lines
  end

  def mount(_params, _session, socket) do
    Recordings.subscribe_to_recording_events()

    socket
    |> assign(detections: %{})
    |> assign(size: %{})
    |> assign(fps: %{})
    |> assign(detector_fps: %{})
    |> assign(latency: %{})
    |> assign(inference_time: %{})
    |> then(&{:ok, &1})
  end

  def handle_params(_params, _uri, socket) do
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

  def handle_info({:inference_latency, device_id, latency_ms}, socket) do
    {:noreply, assign(socket, latency: Map.put(socket.assigns.latency, device_id, latency_ms))}
  end

  def handle_info({:inference_time, device_id, ms}, socket) do
    {:noreply,
     assign(socket, inference_time: Map.put(socket.assigns.inference_time, device_id, ms))}
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
