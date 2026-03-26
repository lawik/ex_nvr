defmodule ExNVRWeb.Components.Vision.Bbox do
  @moduledoc """
  Bounding box components for object detection overlays.

  Five visual styles available:
    * `corner_brackets` — L-shaped corner marks with subtle fill
    * `dashed_glow` — Dashed border with pulsing glow
    * `svg_draw_in` — SVG polyline corners with blinking center dot
    * `gradient_border` — Animated gradient border
    * `frosted_glass` — Glassmorphism with backdrop blur

  ## Common assigns
    * `label` - Detection class name (e.g. "person", "vehicle")
    * `confidence` - Detection confidence as a float or string
    * `style` - CSS positioning style string
  """

  use Phoenix.Component

  @styles ~w(corner_brackets dashed_glow svg_draw_in gradient_border frosted_glass)a

  def styles, do: @styles

  def style_label(:corner_brackets), do: "Corner Brackets"
  def style_label(:dashed_glow), do: "Dashed Glow"
  def style_label(:svg_draw_in), do: "SVG Draw-In"
  def style_label(:gradient_border), do: "Gradient Border"
  def style_label(:frosted_glass), do: "Frosted Glass"

  attr(:style_name, :atom, required: true)
  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)

  def bbox(%{style_name: :corner_brackets} = assigns), do: corner_brackets(assigns)
  def bbox(%{style_name: :dashed_glow} = assigns), do: dashed_glow(assigns)
  def bbox(%{style_name: :svg_draw_in} = assigns), do: svg_draw_in(assigns)
  def bbox(%{style_name: :gradient_border} = assigns), do: gradient_border(assigns)
  def bbox(%{style_name: :frosted_glass} = assigns), do: frosted_glass(assigns)
  def bbox(assigns), do: corner_brackets(assigns)

  # ── Style 1: Corner Brackets ──

  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)

  def corner_brackets(assigns) do
    ~H"""
    <div class="bbox-corners" style={@style}>
      <div class="bbox-corners-fill"></div>
      <span class="bbox-corners-tr"></span>
      <span class="bbox-corners-bl"></span>
      <span class="bbox-corners-br"></span>
      <div class="bbox-corners-tag">{@label} · {@confidence}</div>
    </div>
    """
  end

  # ── Style 2: Dashed Glow ──

  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)

  def dashed_glow(assigns) do
    ~H"""
    <div class="bbox-dashed" style={@style}>
      <div class="bbox-dashed-tag">{@label} · {@confidence}</div>
    </div>
    """
  end

  # ── Style 3: SVG Draw-In ──

  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)

  def svg_draw_in(assigns) do
    ~H"""
    <div class="bbox-svg-wrap" style={@style}>
      <svg viewBox="0 0 200 120" class="bbox-svg-inner">
        <polyline class="bbox-svg-corner" points="0,20 0,0 20,0" />
        <polyline class="bbox-svg-corner" points="180,0 200,0 200,20" style="animation-delay:0.1s" />
        <polyline
          class="bbox-svg-corner"
          points="200,100 200,120 180,120"
          style="animation-delay:0.2s"
        />
        <polyline
          class="bbox-svg-corner"
          points="20,120 0,120 0,100"
          style="animation-delay:0.3s"
        />
        <circle class="bbox-svg-dot" cx="100" cy="60" r="3" />
      </svg>
      <div class="bbox-svg-tag">
        {@label} <span class="bbox-svg-conf">{@confidence}</span>
      </div>
    </div>
    """
  end

  # ── Style 4: Gradient Border ──

  attr(:label, :string, default: "")
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)

  def gradient_border(assigns) do
    ~H"""
    <div class="bbox-gradient-wrap" style={@style}>
      <div class="bbox-gradient"></div>
      <div class="bbox-gradient-tag">{@label} · {@confidence}</div>
    </div>
    """
  end

  # ── Style 5: Frosted Glass ──

  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)

  def frosted_glass(assigns) do
    ~H"""
    <div class="bbox-frost" style={@style}>
      <div class="bbox-frost-tag">
        <span class="bbox-frost-status"></span> {@label} · {@confidence}
      </div>
    </div>
    """
  end
end
