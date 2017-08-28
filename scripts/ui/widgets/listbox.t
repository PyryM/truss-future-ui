-- ui/widgets/listbox.t
--
-- a typical 'listbox' of text options

-- props.value
-- props.value_text

local m = {}

local in_rectangle = require("ui/utils.t").in_rectangle

local function draw_listbox(proc, props, t, dt)
  local nvg = proc.root.nvg_context
  local font_size = props.font_size or proc.root.style.font_size or 14
  local bounds = props.bounds
  local colors = props.colors or proc.root.style.colors
  local font_name = props.font_name or proc.root.style.font_name or "sans"
  nvg:BeginPath()
  nvg:RoundedRect(bounds.x, bounds.y, bounds.width, bounds.height, 3)
  nvg:StrokeColor(colors.background)
  nvg:StrokeWidth(2.0)
  nvg:Stroke()

  nvg:FontFace(font_name)
  nvg:TextAlign(nvg.ALIGN_MIDDLE)
  nvg:FontSize(font_size)

  local item_height = props.bounds.height / props.num_items
  local y = props.bounds.y + item_height / 2.0
  for i = 1, props.num_items do
    local idx = i + props.page_offset
    local text = (props.items[idx] or {})[1]
    if not text then break end
    if idx == props.selection_index then
      nvg:FillColor(colors.font)
    elseif idx == props.hover_index then
      nvg:FillColor(colors.hover)
    else
      nvg:FillColor(colors.background)
    end
    nvg:Text(bounds.x + 5, y, text, nil)
    y = y + item_height
  end
end

-- 
function m.listbox(proc, options)
  if not options.bounds then
    options.bounds = {x = options.x, y = options.y,
                      width = options.width, height = options.height}
  end
  proc.props = options
  options.selection_index = 1
  options.page_offset = 0

  -- setup
  local cb = proc:callback()
  proc.root.input:on("mousemove", cb, cb.call)
  proc.root.input:on("mousedown", cb, cb.call)
  local draw = options.draw or draw_listbox
  proc.tick = function(self, t, dt)
    draw(self, options, t, dt)
  end

  -- main loop
  local in_region = false
  while true do
    local etype, evt = cb:wait_result()
    in_region = in_rectangle(evt.x, evt.y, options.bounds)
    if in_region then
      -- figure out which option is selected
      local rely = evt.y - options.bounds.y
      local item_height = options.bounds.height / options.num_items
      options.hover_index =   math.floor(rely / item_height) 
                            + options.page_offset + 1
    else 
      options.hover_index = nil
    end
    if etype == "mousedown" and in_region then
      print("Clicked?")
      if options.hover_index <= #(options.items) then
        options.selection_index = options.hover_index
        print("Now " .. options.selection_index)
        options.value_text = options.items[options.selection_index][1]
        options.value = options.items[options.selection_index][2]
        proc:emit("change", {value = options.value})
      end
    end
  end
end

return m