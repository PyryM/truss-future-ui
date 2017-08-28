-- various utility functions

local m = {}

function m.in_rectangle(x, y, bounds)
  return x > bounds.x and x < (bounds.x + bounds.width ) 
     and y > bounds.y and y < (bounds.y + bounds.height)
end

return m
