-- examples/future_ui.t
--
-- a future ui example

local app = require("app/app.t")
local geometry = require("geometry")
local pbr = require("shaders/pbr.t")
local graphics = require("graphics")
local orbitcam = require("gui/orbitcam.t")
local grid = require("graphics/grid.t")
local proc = require("ui/proc.t")
local button = require("ui/widgets/button.t")

local style = {
  colors = {},
  font_size = 24,
  font_name = "sans"
}

function nanovg_setup(stage, ctx)
  style.colors.background = ctx:RGBAf(0.0, 0.0, 0.0, 0.5) -- semi-transparent black
  style.colors.font = ctx:RGBf(1.0, 1.0, 1.0)     -- white
  style.colors.foreground = style.colors.font
  style.colors.highlight = ctx:RGBAf(0.6, 0.0, 0.0, 0.5)
  ctx:load_font("font/VeraMono.ttf", "sans")
end

local proc_root = nil

function nanovg_render(stage, ctx)
  if proc_root then
    proc_root.nvg_context = ctx
    proc_root:_tick(0.0, 1.0/60.0)
  end
end

function init()
  myapp = app.App{title = "futureui example", width = 1280, height = 720,
                  msaa = true, stats = false, clear_color = 0x404080ff,
                  nvg_setup = nanovg_setup, nvg_render = nanovg_render}

  myapp.camera:add_component(orbitcam.OrbitControl({min_rad = 1, max_rad = 4}))

  local geo = geometry.icosphere_geo(1.0, 4)
  local mat = pbr.FacetedPBRMaterial({0.2, 0.03, 0.01, 1.0}, {0.001, 0.001, 0.001}, 0.7)
  mymesh = myapp.scene:create_child(graphics.Mesh, "mymesh", geo, mat)
  mygrid = myapp.scene:create_child(grid.Grid, {thickness = 0.02, 
                                                color = {0.5, 0.5, 0.5}})
  mygrid.position:set(0.0, -1.0, 0.0)
  mygrid.quaternion:euler({x = math.pi / 2.0, y = 0.0, z = 0.0})
  mygrid:update_matrix()

  proc_root = proc.Proc()
  proc_root.style = style
  proc_root.input = myapp.ECS.systems.input
  local button1 = proc_root:spawn_child(button.button, 
                                      {x = 50, y = 50, text = "button", 
                                       width = 150, height = 50})
  button1:on("click", proc_root, function(self, etype, evt)
    print("Button was clicked! " .. evt.x .. ", " .. evt.y)
  end)
  local button2 = proc_root:spawn_child(button.brut_button, 
                                       {x = 50, y = 110, text = "brut_button", 
                                       width = 150, height = 50})
  local ntimes = 0
  button2:on("click", proc_root, function(self, etype, evt)
    print("Button2 was clicked! " .. evt.x .. ", " .. evt.y)
    ntimes = ntimes + 1
    button2.props.text = "Clicked " .. ntimes
  end)

  local checkbox = proc_root:spawn_child(button.checkbox, 
                                        {x = 50, y = 170,
                                         width = 20, height = 20})
end

function update()
  myapp:update()
end
