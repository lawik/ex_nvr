defmodule ExNVR.Inference.Detection do
  @moduledoc """
  Type definitions for object detection results.
  """

  @type bbox :: %{
          cx: float(),
          cy: float(),
          w: float(),
          h: float()
        }

  @type t :: %{
          class: String.t(),
          prob: float(),
          bbox: bbox(),
          class_idx: non_neg_integer()
        }
end
