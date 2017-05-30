-- ui/proc.t
--
-- a UI 'process' (co-routine)

local class = require("class")
local queue = require("util/queue.t")
local m = {}

local Proc = class("Proc")
m.Proc = Proc

-- start a process from a function, parented to another process
-- Warning! Prefer using proc:spawn_child() over directly calling constructor!
function Proc:init(parent, f, arg)
  if parent then
    self._root = parent._root
    self._parent = parent
    parent:_add_child(self)
  else -- assume this is meant to be the root
    self._root = self
  end
  self._events = queue.Queue()
  self._timeout = nil  -- no timeout to begin with
  self._listeners = {} -- weak-keyed table of listeners
  setmetatable(self._listeners, {__mode = "k"})

  if f then
    self._co = coroutine.create(f)
    local happy, errmsg = coroutine.resume(self._co, self, arg)
    if not happy then
      log.error("Couldn't start proc: " .. tostring(errmsg))
      self._co = nil
    end
  else
    -- assume a persistent 'container' process is wanted
    self._persist = true
  end
end

function Proc:add_listener(listener)
  self._listeners[listener] = true
end

function Proc:remove_listener(listener)
  self._listeners[listener] = nil
end

-- set whether this process persists after its main function returns
-- (i.e., if you want to keep children alive)
function Proc:persist(persist_state)
  self._persist = persist_state
end

-- emit an event *from* this proc to anything listening to this proc
function Proc:emit(evttype, evtdata, source)
  for listener, _ in pairs(self._listeners) do
    listener:event(evttype, evtdata, source or self)
  end
end

-- send an event *to* this proc
function Proc:event(evttype, evtdata, evtsource)
  self._events:push_right({evttype, evtdata, evtsource})
end

-- spawn a child process from this process
-- the function will be called as f(self_proc, arg)
function Proc:spawn_child(f, arg)
  return Proc(self, f, arg)
end

-- immediately kill this process and all its children
function Proc:kill()
  self._co = nil
  self._parent:_remove_child(self)
  self._children = nil
  self._persist = false
end

-- whether the proc is alive
function Proc:alive()
  return self._persist or (self._co and coroutine.status(self._co) ~= "dead")
end

-- dispatch a single event or timeout
function Proc:_dispatch_event(t)
  local evtargs
  if self._events:length() > 0 then
    evtargs = self._events:pop_left()
  elseif self._timeout and t > self._timeout
    evtargs = {"timeout"}
  else
    return false
  end
  self._timeout = nil

  local happy, errmsg = coroutine.resume(self._co, unpack(evtargs))
  if not happy then
    self._co = nil
    log.error("Proc error: " .. tostring(errmsg))
    return false
  end

  return true
end

-- internal tick function
function Proc:_tick(t, dt)
  if self._co then
    local more_events = self:_dispatch_event(t)
    while more_events do
      more_events = self:_dispatch_event(t)
    end
  end

  -- call user-defined tick if inheriting from this
  if self.tick then self:tick(t, dt) end

  -- _tick children if we have any
  if not self._children then return end
  for child, _ in pairs(self._children) do
    child:_tick(t, dt)
    if not child:alive() then self._remove_child(child) end
  end
end

function Proc:_add_child(child)
  -- warning! No cycle checking!
  if not self._children then self._children = {} end
  self._children[child] = true
end

function Proc:_remove_child(child)
  if not self._children then return end
  self._children[child] = nil
end

return m
