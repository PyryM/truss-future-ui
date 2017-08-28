-- various utility functions

local m = {}

function m.in_rectangle(x, y, bounds)
  return x > bounds.x and x < (bounds.x + bounds.width ) 
     and y > bounds.y and y < (bounds.y + bounds.height)
end

function m.infer_bounds(options)
  if not options.bounds then
    options.bounds = {x = options.x, y = options.y,
                      width = options.width, height = options.height}
  end
end

return m
