-- ui/widgets/button
--
-- a button

local m = {}

local in_rectangle = require("ui/utils.t").in_rectangle
local infer_bounds = require("ui/utils.t").infer_bounds

local button_normal_state, button_hover_state, button_down_state
button_normal_state = function(proc, cb, props)
  props.state = "normal"
  local etype, evt = cb:wait_result_type({"mousemove"})
  if in_rectangle(evt.x, evt.y, props.bounds) then
    return button_hover_state, false
  end
end

button_hover_state = function(proc, cb, props)
  props.state = "hover"
  local etype, evt = cb:wait_result_type({"mousemove", "mousedown"})
  local in_bounds = in_rectangle(evt.x, evt.y, props.bounds)
  if not in_bounds then return button_normal_state end
  if etype == "mousedown" then -- and evt.button == "left"
    return button_down_state, false
  end
end

button_down_state = function(proc, cb, props)
  props.state = "held"
  local etype, evt = cb:wait_result_type({"mouseup"})
  if in_rectangle(evt.x, evt.y, props.bounds) then
    proc:emit("click", evt)
    return button_hover_state, true
  end
  return button_normal_state, false
end

local function draw_button(proc, props, t, dt)
  local nvg = proc.root.nvg_context
  local text = props.text or "Button"
  local font_size = props.font_size or proc.root.style.font_size or 14
  local tw = #text * font_size * 0.55
  local th = font_size
  local bounds = props.bounds
  local colors = props.colors or proc.root.style.colors
  local font_name = props.font_name or proc.root.style.font_name or "sans"
  nvg:BeginPath()
  nvg:RoundedRect(bounds.x, bounds.y, bounds.width, bounds.height, 3)
  if props.state ~= "normal" then
    if props.state == "held" then
      nvg:FillColor(colors.highlight)
    else
      nvg:FillColor(colors.background)
    end
    nvg:Fill()
  else
    nvg:StrokeColor(colors.background)
    nvg:StrokeWidth(2.0)
    nvg:Stroke()
  end

  nvg:FontFace(font_name)
  nvg:TextAlign(nvg.ALIGN_MIDDLE)
  nvg:FontSize(font_size)
  nvg:FillColor(colors.font)
  nvg:Text(bounds.x + 5, bounds.y + bounds.height / 2, text, nil)
end

function m.button(proc, options)
  infer_bounds(options)
  proc.props = options

  -- setup
  local state = button_normal_state
  local cb = proc:callback()
  proc.root.input:on("mousemove", cb, cb.call)
  proc.root.input:on("mousedown", cb, cb.call)
  proc.root.input:on("mouseup", cb, cb.call)
  local draw = options.draw or draw_button
  proc.tick = function(self, t, dt)
    draw(self, options, t, dt)
  end

  -- main loop
  while true do
    local newstate, clicked = state(proc, cb, options)
    state = newstate or state
  end
end

local function draw_checkbox(proc, props, t, dt)
  local nvg = proc.root.nvg_context
  local bounds = props.bounds
  local colors = props.colors or proc.root.style.colors
  nvg:BeginPath()
  nvg:RoundedRect(bounds.x, bounds.y, bounds.width, bounds.height, 3)
  if props.state ~= "normal" then
    if props.state == "held" then
      nvg:FillColor(colors.highlight)
    else
      nvg:FillColor(colors.background)
    end
    nvg:Fill()
  else
    nvg:StrokeColor(colors.background)
    nvg:StrokeWidth(2.0)
    nvg:Stroke()
  end

  if props.checked then
    local cx = bounds.x + bounds.width / 2
    local cy = bounds.y + bounds.height / 2
    local r = math.min(bounds.width, bounds.height) / 3.0
    nvg:BeginPath()
    nvg:Circle(cx, cy, r)
    nvg:FillColor(colors.background)
    nvg:Fill()
  end
end

function m.checkbox(proc, options)
  infer_bounds(options)
  proc.props = options

  -- setup
  local state = button_normal_state
  local cb = proc:callback()
  proc.root.input:on("mousemove", cb, cb.call)
  proc.root.input:on("mousedown", cb, cb.call)
  proc.root.input:on("mouseup", cb, cb.call)
  local draw = options.draw or draw_checkbox
  proc.tick = function(self, t, dt)
    draw(self, options, t, dt)
  end

  -- main loop
  while true do
    local newstate, clicked = state(proc, cb, options)
    state = newstate or state
    if clicked then options.checked = not options.checked end
  end
end

-- a 'brutalist' button
function m.brut_button(proc, options)
  infer_bounds(options)
  proc.props = options

  -- setup
  local cb = proc:callback()
  proc.root.input:on("mousemove", cb, cb.call)
  proc.root.input:on("mousedown", cb, cb.call)
  local draw = options.draw or draw_button
  proc.tick = function(self, t, dt)
    draw(self, options, t, dt)
  end

  -- main loop
  local in_region = false
  while true do
    local etype, evt = cb:wait_result()
    if etype == "mousemove" then
      in_region = in_rectangle(evt.x, evt.y, options.bounds)
      if in_region then options.state = "hover" else options.state = "normal" end
    elseif etype == "mousedown" then
      if in_region then 
        options.state = "held"
        proc:emit("click", evt)
        for i = 1,5 do proc:wait_frame() end
        options.state = "hover"
      end
    end
  end
end

return m