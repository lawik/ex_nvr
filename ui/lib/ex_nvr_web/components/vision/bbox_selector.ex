defmodule ExNVRWeb.Components.Vision.BboxSelector do
  @moduledoc """
  Visual preview selector for bounding box styles.
  Renders a grid of preview cards, each showing what the style looks like.
  Uses JS to toggle selection state client-side.
  """

  use Phoenix.Component

  alias ExNVRWeb.Components.Vision.Bbox

  attr(:name, :string, required: true)
  attr(:selected, :string, default: "corner_brackets")

  def preview_selector(assigns) do
    assigns = assign(assigns, :styles, Bbox.styles())

    ~H"""
    <div id="bbox-selector" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3" phx-hook="BboxSelector">
      <label
        :for={style <- @styles}
        data-style={to_string(style)}
        class={[
          "bbox-option cursor-pointer rounded-lg border p-2 transition-all",
          if(to_string(style) == @selected,
            do: "border-blue-500 ring-1 ring-blue-500/20 selected",
            else: "border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-500"
          )
        ]}
      >
        <input
          type="radio"
          name={@name}
          value={to_string(style)}
          checked={to_string(style) == @selected}
          class="sr-only"
        />
        <div class="relative w-full aspect-video bg-[#16161a] rounded p-6 pt-8 overflow-hidden">
          <.preview_bbox style_name={style} />
        </div>
        <div class="mt-1.5 text-center text-xs font-medium text-gray-700 dark:text-gray-100 tracking-wide">
          {Bbox.style_label(style)}
        </div>
      </label>
    </div>
    """
  end

  attr(:style_name, :atom, required: true)

  defp preview_bbox(%{style_name: :corner_brackets} = assigns) do
    ~H"""
    <div class="bbox-corners" style="position:absolute;top:30%;left:20%;width:60%;height:45%;--c:#00e5cc">
      <div class="bbox-corners-fill"></div>
      <span class="bbox-corners-tr"></span>
      <span class="bbox-corners-bl"></span>
      <span class="bbox-corners-br"></span>
      <div class="bbox-corners-tag">person · 0.97</div>
    </div>
    """
  end

  defp preview_bbox(%{style_name: :dashed_glow} = assigns) do
    ~H"""
    <div class="bbox-dashed" style="position:absolute;top:22%;left:18%;width:64%;height:48%">
      <div class="bbox-dashed-tag">car · 0.96</div>
    </div>
    """
  end

  defp preview_bbox(%{style_name: :svg_draw_in} = assigns) do
    ~H"""
    <div class="bbox-svg-wrap" style="position:absolute;top:20%;left:18%;width:64%;height:52%">
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
      <div class="bbox-svg-tag">dog <span class="bbox-svg-conf">94%</span></div>
    </div>
    """
  end

  defp preview_bbox(%{style_name: :gradient_border} = assigns) do
    ~H"""
    <div class="bbox-gradient-wrap" style="position:absolute;top:20%;left:18%;width:64%;height:52%">
      <div class="bbox-gradient"></div>
      <div class="bbox-gradient-tag">truck · 0.93</div>
    </div>
    """
  end

  defp preview_bbox(%{style_name: :frosted_glass} = assigns) do
    ~H"""
    <div
      class="bbox-frost"
      style="position:absolute;top:22%;left:18%;width:64%;height:48%"
    >
      <div class="bbox-frost-tag">
        <span class="bbox-frost-status"></span> face · 0.99
      </div>
    </div>
    """
  end
end
