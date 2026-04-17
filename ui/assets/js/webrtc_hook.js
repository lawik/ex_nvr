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
    const log = (...args) => console.log(`[WebRTC ${deviceId}/${stream}]`, ...args)

    log("mounted, initializing RTCPeerConnection")

    const pc = new RTCPeerConnection({
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
    })

    const socket = new Socket("/socket", { params: { token } })
    const channel = socket.channel(`device:${deviceId}`, { stream })

    this.pc = pc
    this.socket = socket
    this.channel = channel

    log("joining channel")
    channel
      .join()
      .receive("ok", () => log("channel joined"))
      .receive("error", (reason) => {
        console.warn(`[WebRTC ${deviceId}/${stream}] join failed:`, formatJoinError(reason), reason)
        channel.leave()
      })
      .receive("timeout", () => log("channel join timeout"))

    channel.on("offer", ({ data }) => {
      log("received offer")
      pc.setRemoteDescription(JSON.parse(data))
        .then(() => log("remote description set"))
        .catch((e) => console.warn(`[WebRTC ${deviceId}/${stream}] setRemoteDescription failed:`, e))
      pc.createAnswer().then((answer) => {
        log("created answer")
        pc.setLocalDescription(answer)
          .then(() => log("local description set"))
          .catch((e) => console.warn(`[WebRTC ${deviceId}/${stream}] setLocalDescription failed:`, e))
        channel.push("answer", JSON.stringify(answer))
        log("sent answer")
      })
    })

    channel.on("ice_candidate", ({ data }) => {
      log("received remote ICE candidate")
      pc.addIceCandidate(JSON.parse(data))
        .catch((e) => console.warn(`[WebRTC ${deviceId}/${stream}] addIceCandidate failed:`, e))
    })

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        log("local ICE candidate gathered")
        channel.push("ice_candidate", JSON.stringify(event.candidate))
      } else {
        log("ICE gathering complete")
      }
    }

    pc.oniceconnectionstatechange = () => {
      log("ICE connection state:", pc.iceConnectionState)
    }

    pc.onicegatheringstatechange = () => {
      log("ICE gathering state:", pc.iceGatheringState)
    }

    pc.onsignalingstatechange = () => {
      log("signaling state:", pc.signalingState)
    }

    pc.ontrack = (track) => {
      log("track received:", track.track?.kind, "streams:", track.streams.length)
      video.srcObject = track.streams[0]
    }

    video.addEventListener("loadeddata", () => {
      log("video loadeddata fired, marking active")
      video.classList.remove("hidden")
      this.pushEvent("webrtc_active", { device_id: deviceId })
    })

    video.addEventListener("playing", () => log("video playing"))
    video.addEventListener("stalled", () => log("video stalled"))
    video.addEventListener("waiting", () => log("video waiting for data"))
    video.addEventListener("error", (e) => console.warn(`[WebRTC ${deviceId}/${stream}] video error:`, e))

    pc.onconnectionstatechange = () => {
      log("connection state:", pc.connectionState)
      if (pc.connectionState === "disconnected" || pc.connectionState === "failed") {
        this.pushEvent("webrtc_inactive", { device_id: deviceId })
        pc.close()
      }
    }

    log("connecting socket")
    socket.connect()
  },

  destroyed() {
    const deviceId = this.el?.dataset?.device
    const stream = this.el?.dataset?.stream
    console.log(`[WebRTC ${deviceId}/${stream}] destroyed, tearing down`)
    if (this.pc) this.pc.close()
    if (this.channel) this.channel.leave()
    if (this.socket) this.socket.disconnect()
  }
}

export default WebRtcPlayer
