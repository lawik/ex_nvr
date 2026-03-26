import { Socket } from "phoenix"

function formatJoinError(error) {
  switch (error) {
    case "unsupported_codec": return "Unsupported Codec"
    case "offline": return "Camera Offline"
    case "stream_unavailable": return "Unavailable Stream"
    default: return "Unknown Error"
  }
}

const WebRtcPlayer = {
  mounted() {
    const el = this.el
    const video = el.querySelector("video")
    const deviceId = el.dataset.device
    const stream = el.dataset.stream
    const token = el.dataset.token

    const pc = new RTCPeerConnection({
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
    })

    const socket = new Socket("/socket", { params: { token } })
    const channel = socket.channel(`device:${deviceId}`, { stream })

    this.pc = pc
    this.socket = socket
    this.channel = channel

    channel
      .join()
      .receive("ok", () => {})
      .receive("error", (reason) => {
        console.warn("WebRTC join failed:", formatJoinError(reason))
        channel.leave()
      })

    channel.on("offer", ({ data }) => {
      pc.setRemoteDescription(JSON.parse(data))
      pc.createAnswer().then((answer) => {
        pc.setLocalDescription(answer)
        channel.push("answer", JSON.stringify(answer))
      })
    })

    channel.on("ice_candidate", ({ data }) => {
      pc.addIceCandidate(JSON.parse(data))
    })

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        channel.push("ice_candidate", JSON.stringify(event.candidate))
      }
    }

    pc.ontrack = (track) => {
      video.srcObject = track.streams[0]
    }

    video.addEventListener("loadeddata", () => {
      video.classList.remove("hidden")
      this.pushEvent("webrtc_active", { device_id: deviceId })
    })

    pc.onconnectionstatechange = () => {
      if (pc.connectionState === "disconnected" || pc.connectionState === "failed") {
        this.pushEvent("webrtc_inactive", { device_id: deviceId })
        pc.close()
      }
    }

    socket.connect()
  },

  destroyed() {
    if (this.pc) this.pc.close()
    if (this.channel) this.channel.leave()
    if (this.socket) this.socket.disconnect()
  }
}

export default WebRtcPlayer
