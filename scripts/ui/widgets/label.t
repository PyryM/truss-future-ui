-- ui/widgets/label.t
--
-- labels and frames

local infer_bounds = require("ui/utils.t").infer_bounds

local m = {}

function m.draw_label(proc, props, t, dt)
  local nvg = proc.root.nvg_context
  local font_size = props.font_size or proc.root.style.font_size or 14
  local bounds = props.bounds
  local colors = props.colors or proc.root.style.colors
  local font_name = props.font_name or proc.root.style.font_name or "sans"
  if props.border then
    nvg:BeginPath()
    nvg:RoundedRect(bounds.x, bounds.y, bounds.width, bounds.height, 3)
    if props.border == "fill" then
      nvg:FillColor(colors.background)
      nvg:Fill()
    else
      nvg:StrokeColor(colors.background)
      nvg:StrokeWidth(2.0)
      nvg:Stroke()
    end
  end

  local text = props.text or "Label"
  nvg:FontFace(font_name)
  nvg:TextAlign(nvg.ALIGN_MIDDLE)
  nvg:FontSize(font_size)
  nvg:FillColor(colors.font)
  nvg:Text(bounds.x + 5, bounds.y + bounds.height / 2, text, nil)
end

function m.draw_frame(proc, props, t, dt)
  local nvg = proc.root.nvg_context
  local bounds = props.bounds
  local colors = props.colors or proc.root.style.colors
  nvg:BeginPath()
  nvg:RoundedRect(bounds.x, bounds.y, bounds.width, bounds.height, 3)
  if props.fill then
    nvg:FillColor(colors.background)
    nvg:Fill()
  else
    nvg:StrokeColor(colors.background)
    nvg:StrokeWidth(2.0)
    nvg:Stroke()
  end
end

function m.label(proc, options)
  infer_bounds(options)
  proc.props = options
  proc:persist(true)
  local draw = options.draw or m.draw_label
  proc.tick = function(self, t, dt)
    draw(self, options, t, dt)
  end
end

function m.frame(proc, options)
  infer_bounds(options)
  proc.props = options
  proc:persist(true)
  local draw = options.draw or m.draw_frame
  proc.tick = function(self, t, dt)
    draw(self, options, t, dt)
  end
end

return m