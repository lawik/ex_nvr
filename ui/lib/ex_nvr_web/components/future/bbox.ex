defmodule ExNVRWeb.Components.Future.Bbox do
  @moduledoc """
  Cyberpunk-styled bounding box components for object detection overlays.

  Each variant provides a different visual style (cyan, magenta, lime, amber, red, minimal)
  with animated corners, scanlines, and labels.

  ## Common assigns

    * `label` - Detection class name (e.g. "person", "vehicle")
    * `confidence` - Detection confidence as a float 0-1 or percentage string
    * `style` - CSS positioning style string (left, top, width, height)
    * `info` - Optional bottom data readout text
  """

  use Phoenix.Component

  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)
  attr(:info, :string, default: nil)

  def variants(%{label: "person"} = assigns) do
    cyan(assigns)
  end

  def variants(%{label: _} = assigns) do
    lime(assigns)
  end

  @doc """
  Cyan bounding box — dashed animated SVG border, pulsing corner brackets, crosshair center.
  """
  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)
  attr(:info, :string, default: nil)

  def cyan(assigns) do
    ~H"""
    <div class="absolute" style={@style}>
      <%!-- Background fill --%>
      <div class="absolute inset-0 bg-neon-cyan/[0.03] rounded-sm"></div>

      <%!-- Scanline --%>
      <div class="absolute top-0 left-0 right-0 bottom-0 pointer-events-none rounded-sm overflow-hidden">
        <div class="absolute inset-x-0  h-[30%] animate-scanline scanline-cyan"></div>
      </div>

      <%!-- Dashed animated border via SVG --%>
      <svg class="absolute inset-0 w-full h-full dash-animate pointer-events-none">
        <rect x="1" y="1" width="calc(100% - 2px)" height="calc(100% - 2px)" rx="2"
              fill="none" stroke="#00f0ff" stroke-width="1.5" stroke-opacity="0.5" />
      </svg>

      <%!-- Corner brackets --%>
      <div class="absolute -top-px -left-px w-5 h-5 border-t-2 border-l-2 border-neon-cyan animate-cornerPulse drop-shadow-[0_0_6px_#00f0ff]"></div>
      <div class="absolute -top-px -right-px w-5 h-5 border-t-2 border-r-2 border-neon-cyan animate-cornerPulse drop-shadow-[0_0_6px_#00f0ff]" style="animation-delay:0.4s"></div>
      <div class="absolute -bottom-px -left-px w-5 h-5 border-b-2 border-l-2 border-neon-cyan animate-cornerPulse drop-shadow-[0_0_6px_#00f0ff]" style="animation-delay:0.8s"></div>
      <div class="absolute -bottom-px -right-px w-5 h-5 border-b-2 border-r-2 border-neon-cyan animate-cornerPulse drop-shadow-[0_0_6px_#00f0ff]" style="animation-delay:1.2s"></div>

      <%!-- Label --%>
      <div class="absolute -top-7 left-0 flex items-center gap-2">
        <span class="bg-neon-cyan/90 text-black font-orbitron text-[10px] font-bold tracking-widest px-2 py-0.5 uppercase">{@label}</span>
        <span class="text-neon-cyan/70 text-[10px] tracking-wider animate-flicker">{@confidence}</span>
      </div>

      <%!-- Crosshair center --%>
      <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-6 h-6 animate-targetLock">
        <div class="absolute top-0 left-1/2 -translate-x-1/2 w-px h-2 bg-neon-cyan/50"></div>
        <div class="absolute bottom-0 left-1/2 -translate-x-1/2 w-px h-2 bg-neon-cyan/50"></div>
        <div class="absolute left-0 top-1/2 -translate-y-1/2 h-px w-2 bg-neon-cyan/50"></div>
        <div class="absolute right-0 top-1/2 -translate-y-1/2 h-px w-2 bg-neon-cyan/50"></div>
      </div>

      <%!-- Data readout --%>
      <div :if={@info} class="absolute -bottom-6 left-0 text-[9px] text-neon-cyan/40 tracking-widest font-mono">
        {@info}
      </div>
    </div>
    """
  end

  @doc """
  Magenta bounding box — double border, thick L-shape corners, mid-edge ticks.
  """
  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)
  attr(:info, :string, default: nil)

  def magenta(assigns) do
    ~H"""
    <div class="absolute" style={@style}>
      <div class="absolute inset-0 bg-neon-magenta/[0.03]"></div>
      <div class="absolute inset-x-0 h-[30%] animate-scanline scanline-magenta pointer-events-none" style="animation-duration:3s"></div>

      <%!-- Double border --%>
      <div class="absolute inset-0 border border-neon-magenta/30 shadow-[0_0_12px_rgba(255,0,228,0.15),inset_0_0_12px_rgba(255,0,228,0.05)]"></div>
      <div class="absolute inset-1 border border-neon-magenta/10"></div>

      <%!-- Thick L-shape corners --%>
      <div class="absolute -top-0.5 -left-0.5 w-8 h-8 border-t-[3px] border-l-[3px] border-neon-magenta animate-cornerPulse drop-shadow-[0_0_8px_#ff00e4]"></div>
      <div class="absolute -top-0.5 -right-0.5 w-8 h-8 border-t-[3px] border-r-[3px] border-neon-magenta animate-cornerPulse drop-shadow-[0_0_8px_#ff00e4]" style="animation-delay:0.5s"></div>
      <div class="absolute -bottom-0.5 -left-0.5 w-8 h-8 border-b-[3px] border-l-[3px] border-neon-magenta animate-cornerPulse drop-shadow-[0_0_8px_#ff00e4]" style="animation-delay:1s"></div>
      <div class="absolute -bottom-0.5 -right-0.5 w-8 h-8 border-b-[3px] border-r-[3px] border-neon-magenta animate-cornerPulse drop-shadow-[0_0_8px_#ff00e4]" style="animation-delay:1.5s"></div>

      <%!-- Mid-edge ticks --%>
      <div class="absolute top-0 left-1/2 -translate-x-1/2 w-4 h-px bg-neon-magenta/60"></div>
      <div class="absolute bottom-0 left-1/2 -translate-x-1/2 w-4 h-px bg-neon-magenta/60"></div>
      <div class="absolute left-0 top-1/2 -translate-y-1/2 h-4 w-px bg-neon-magenta/60"></div>
      <div class="absolute right-0 top-1/2 -translate-y-1/2 h-4 w-px bg-neon-magenta/60"></div>

      <%!-- Label --%>
      <div class="absolute -top-7 left-0 flex items-center gap-2">
        <span class="bg-neon-magenta/90 text-black font-orbitron text-[10px] font-bold tracking-widest px-2 py-0.5 uppercase">{@label}</span>
        <span class="text-neon-magenta/70 text-[10px] tracking-wider animate-flicker">{@confidence}</span>
      </div>

      <div :if={@info} class="absolute -bottom-6 left-0 text-[9px] text-neon-magenta/40 tracking-widest font-mono">
        {@info}
      </div>
    </div>
    """
  end

  @doc """
  Lime bounding box — glitching border, dotted inner border, corner diamonds, center reticle.
  """
  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)
  attr(:info, :string, default: nil)

  def lime(assigns) do
    ~H"""
    <div class="absolute" style={@style}>
      <div class="absolute inset-0 bg-neon-lime/[0.03] rounded-sm"></div>
      <div class="absolute inset-x-0 h-[30%] animate-scanline scanline-lime pointer-events-none" style="animation-duration:1.8s"></div>

      <%!-- Glitching border --%>
      <div class="absolute inset-0 border border-neon-lime/40 animate-glitchX shadow-[0_0_10px_rgba(57,255,20,0.15)]"></div>

      <%!-- Dotted inner border --%>
      <div class="absolute inset-2 border border-dashed border-neon-lime/15"></div>

      <%!-- Corner diamonds --%>
      <div class="absolute -top-1 -left-1 w-2 h-2 bg-neon-lime rotate-45 animate-cornerPulse drop-shadow-[0_0_6px_#39ff14]"></div>
      <div class="absolute -top-1 -right-1 w-2 h-2 bg-neon-lime rotate-45 animate-cornerPulse drop-shadow-[0_0_6px_#39ff14]" style="animation-delay:0.3s"></div>
      <div class="absolute -bottom-1 -left-1 w-2 h-2 bg-neon-lime rotate-45 animate-cornerPulse drop-shadow-[0_0_6px_#39ff14]" style="animation-delay:0.6s"></div>
      <div class="absolute -bottom-1 -right-1 w-2 h-2 bg-neon-lime rotate-45 animate-cornerPulse drop-shadow-[0_0_6px_#39ff14]" style="animation-delay:0.9s"></div>

      <%!-- Inner corner L brackets --%>
      <div class="absolute top-1 left-1 w-4 h-4 border-t border-l border-neon-lime/60"></div>
      <div class="absolute top-1 right-1 w-4 h-4 border-t border-r border-neon-lime/60"></div>
      <div class="absolute bottom-1 left-1 w-4 h-4 border-b border-l border-neon-lime/60"></div>
      <div class="absolute bottom-1 right-1 w-4 h-4 border-b border-r border-neon-lime/60"></div>

      <%!-- Label --%>
      <div class="absolute -top-7 left-0 flex items-center gap-2">
        <span class="border border-neon-lime text-neon-lime font-orbitron text-[10px] font-bold tracking-widest px-2 py-0.5 uppercase bg-neon-lime/10">{@label}</span>
        <span class="text-neon-lime/70 text-[10px] tracking-wider animate-flicker">{@confidence}</span>
      </div>

      <%!-- Center reticle --%>
      <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-8 h-8 border border-neon-lime/20 rounded-full animate-targetLock"></div>
      <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-3 h-3 border border-neon-lime/40 rounded-full"></div>

      <div :if={@info} class="absolute -bottom-6 left-0 text-[9px] text-neon-lime/40 tracking-widest font-mono">
        {@info}
      </div>
    </div>
    """
  end

  @doc """
  Amber bounding box — thick outer border, filled corner blocks, warning stripes.
  """
  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)
  attr(:info, :string, default: nil)

  def amber(assigns) do
    ~H"""
    <div class="absolute" style={@style}>
      <div class="absolute inset-0 bg-neon-amber/[0.04]"></div>
      <div class="absolute inset-x-0 h-[30%] animate-scanline scanline-amber pointer-events-none" style="animation-duration:2s"></div>

      <%!-- Thick outer + thin inner border --%>
      <div class="absolute inset-0 border-2 border-neon-amber/50 shadow-[0_0_16px_rgba(255,174,0,0.2),inset_0_0_16px_rgba(255,174,0,0.05)] animate-flicker"></div>
      <div class="absolute inset-1.5 border border-neon-amber/15"></div>

      <%!-- Corner blocks (filled squares) --%>
      <div class="absolute -top-1 -left-1 w-3 h-3 bg-neon-amber animate-cornerPulse drop-shadow-[0_0_8px_#ffae00]"></div>
      <div class="absolute -top-1 -right-1 w-3 h-3 bg-neon-amber animate-cornerPulse drop-shadow-[0_0_8px_#ffae00]" style="animation-delay:0.5s"></div>
      <div class="absolute -bottom-1 -left-1 w-3 h-3 bg-neon-amber animate-cornerPulse drop-shadow-[0_0_8px_#ffae00]" style="animation-delay:1s"></div>
      <div class="absolute -bottom-1 -right-1 w-3 h-3 bg-neon-amber animate-cornerPulse drop-shadow-[0_0_8px_#ffae00]" style="animation-delay:1.5s"></div>

      <%!-- Warning stripes --%>
      <div class="absolute top-0 left-4 right-4 h-px bg-gradient-to-r from-transparent via-neon-amber/40 to-transparent"></div>
      <div class="absolute bottom-0 left-4 right-4 h-px bg-gradient-to-r from-transparent via-neon-amber/40 to-transparent"></div>

      <%!-- Label --%>
      <div class="absolute -top-7 left-0 flex items-center gap-2">
        <span class="bg-neon-amber text-black font-orbitron text-[10px] font-black tracking-widest px-2 py-0.5 uppercase animate-flicker">{@label}</span>
        <span class="text-neon-amber/70 text-[10px] tracking-wider">{@confidence}</span>
      </div>

      <div :if={@info} class="absolute -bottom-6 left-0 text-[9px] text-neon-amber/40 tracking-widest font-mono">
        {@info}
      </div>
    </div>
    """
  end

  @doc """
  Red bounding box — triple border, aggressive glitching, thick glowing corners, crosshair with dot.
  """
  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)
  attr(:info, :string, default: nil)

  def red(assigns) do
    ~H"""
    <div class="absolute" style={@style}>
      <div class="absolute inset-0 bg-neon-red/[0.05]"></div>
      <div class="absolute inset-x-0 h-[30%] animate-scanline scanline-red pointer-events-none" style="animation-duration:1.5s"></div>

      <%!-- Triple border --%>
      <div class="absolute inset-0 border-2 border-neon-red/70 animate-glitchX shadow-[0_0_20px_rgba(255,32,64,0.3),inset_0_0_20px_rgba(255,32,64,0.08)]"></div>
      <div class="absolute inset-1 border border-neon-red/25"></div>
      <div class="absolute inset-2 border border-dashed border-neon-red/10"></div>

      <%!-- Thick glowing corner L-shapes --%>
      <div class="absolute -top-0.5 -left-0.5 w-7 h-7 border-t-[3px] border-l-[3px] border-neon-red animate-cornerPulse drop-shadow-[0_0_10px_#ff2040]" style="animation-duration:0.8s"></div>
      <div class="absolute -top-0.5 -right-0.5 w-7 h-7 border-t-[3px] border-r-[3px] border-neon-red animate-cornerPulse drop-shadow-[0_0_10px_#ff2040]" style="animation-delay:0.2s;animation-duration:0.8s"></div>
      <div class="absolute -bottom-0.5 -left-0.5 w-7 h-7 border-b-[3px] border-l-[3px] border-neon-red animate-cornerPulse drop-shadow-[0_0_10px_#ff2040]" style="animation-delay:0.4s;animation-duration:0.8s"></div>
      <div class="absolute -bottom-0.5 -right-0.5 w-7 h-7 border-b-[3px] border-r-[3px] border-neon-red animate-cornerPulse drop-shadow-[0_0_10px_#ff2040]" style="animation-delay:0.6s;animation-duration:0.8s"></div>

      <%!-- Center crosshair with dot --%>
      <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 animate-targetLock">
        <div class="w-10 h-10 border border-neon-red/30 rounded-full"></div>
        <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-1 h-1 bg-neon-red rounded-full drop-shadow-[0_0_4px_#ff2040]"></div>
        <div class="absolute top-0 left-1/2 -translate-x-1/2 w-px h-3 bg-neon-red/50"></div>
        <div class="absolute bottom-0 left-1/2 -translate-x-1/2 w-px h-3 bg-neon-red/50"></div>
        <div class="absolute left-0 top-1/2 -translate-y-1/2 h-px w-3 bg-neon-red/50"></div>
        <div class="absolute right-0 top-1/2 -translate-y-1/2 h-px w-3 bg-neon-red/50"></div>
      </div>

      <%!-- Label --%>
      <div class="absolute -top-7 left-0 flex items-center gap-2">
        <span class="bg-neon-red text-black font-orbitron text-[10px] font-black tracking-widest px-2 py-0.5 uppercase animate-glitchX">{@label}</span>
        <span class="text-neon-red/80 text-[10px] tracking-wider animate-flicker" style="animation-duration:2s">{@confidence}</span>
      </div>

      <div :if={@info} class="absolute -bottom-6 left-0 text-[9px] text-neon-red/40 tracking-widest font-mono animate-flicker" style="animation-duration:3s">
        {@info}
      </div>
    </div>
    """
  end

  @doc """
  Minimal cyan bounding box — corners only, scanline, monospace label.
  """
  attr(:label, :string, required: true)
  attr(:confidence, :string, default: "")
  attr(:style, :string, required: true)
  attr(:info, :string, default: nil)

  def minimal(assigns) do
    ~H"""
    <div class="absolute" style={@style}>
      <div class="absolute inset-0 bg-neon-cyan/[0.02]"></div>

      <%!-- Just corners --%>
      <div class="absolute top-0 left-0 w-6 h-6 border-t border-l border-neon-cyan/80 animate-cornerPulse drop-shadow-[0_0_4px_#00f0ff]"></div>
      <div class="absolute top-0 right-0 w-6 h-6 border-t border-r border-neon-cyan/80 animate-cornerPulse drop-shadow-[0_0_4px_#00f0ff]" style="animation-delay:0.5s"></div>
      <div class="absolute bottom-0 left-0 w-6 h-6 border-b border-l border-neon-cyan/80 animate-cornerPulse drop-shadow-[0_0_4px_#00f0ff]" style="animation-delay:1s"></div>
      <div class="absolute bottom-0 right-0 w-6 h-6 border-b border-r border-neon-cyan/80 animate-cornerPulse drop-shadow-[0_0_4px_#00f0ff]" style="animation-delay:1.5s"></div>

      <%!-- Scanline --%>
      <div class="absolute inset-x-0 h-[25%] animate-scanline scanline-cyan pointer-events-none" style="animation-duration:3.5s"></div>

      <%!-- Minimal label --%>
      <div class="absolute -top-6 left-0">
        <span class="text-neon-cyan font-mono text-[10px] tracking-widest opacity-70 animate-flicker">{@label} // {@confidence}</span>
      </div>

      <div :if={@info} class="absolute -bottom-5 right-0 text-[9px] text-neon-cyan/30 tracking-widest font-mono">
        {@info}
      </div>
    </div>
    """
  end
end
