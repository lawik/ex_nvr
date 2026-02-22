This is an NVR.

We have support for object detection. And we support setting record modes so we don't always record. I'd like use to implement the on-event recording.

To perform good event-recording we need to keep a running buffer of some amount of time so we get footage of what happened before the event was detected. This usually means holding a circular buffer. Importantly we are dealing with video and starting on non-keyframe footage is useless. The module ExNVR.Elements.CVSBufferer has the right idea but it only deals with a single slice of keyframe + interframes.

Make a copy of CVSBufferer and call it VideoBufferer, limit: {:bytes, non_neg_integer()}, {:keyframes, non_neg_integer()}, {:seconds, non_neg_integer()}. It should also take an event config with a topic and a list of events to listen for. Then it should subscribe using Phoenix.PubSub. If it receives any of the events it should start forwarding frames until it has not seen event activity for `event_timeout` milliseconds at which point it goes back to buffering.

When this option is on. It would set up the usual recording setup. But have the bufferer before it so typically the recorder would be starved until an event hits when the full buffer gets passed and then we open the filter in the bufferer to get continuous recording until the events pass and we stop forwarding again.

We need to figure out if we can ensure the recorder makes a segment of this due to the quiet period in-between. Maybe an option or variant for the storage output.

In the UI we need a menu for Event sources. In there various pieces of the system could potentially offer events. For now it is the Yolo and Hailo object detectors. And they can provide detections. The system provides options that make sense. The user doesn't have to enter these details. Put functions on the detector for getting the topics and event message shapes. Probably an event source provides:

YoloObjectDetector:
%{
  "detections" => %{
    "objects_detected" => YoloObjectDetector.objects_detected_event?/3, # takes detections event, event config, device
  }
}

Typical config for the yolo-based detectors would be which classes to react to. But keep it simple, select among the classes that detector can load. The threshold is already set byt the inference.

This would let a pipeline expose multiple events. And offer multiple filters. Much like with inference the event config is largely controlled by the event source and the event target that you select.

EventTarget:

Another behavior.

- `trigger recording` would be one and it would offer config for event timeout, and the buffer retention limits.
- `developer log` would log to the system log, nothing useful for users aside from being able to set something mostly harmless.
- `grid overlay` enables/disables the display of the bboxes on the grid_live view.

These should also be modules. Much like how Inference works they may need to be injected in the processing pipeline (like the buffering for the recording) but they may only need a little GenServer under a DynamicSupervisor like the developer log would.

You then switch these on per device instead of the current inference. So the Device <-> Events <-> Inference OR other source. No other sources in this implementation right now.


