-- ui/proc.t
--
-- a UI 'process' (co-routine)

local class = require("class")
local m = {}

local Proc = class("Proc")
m.Proc = Proc

-- start a process from a function, parented to another process
-- Warning! Prefer using proc:spawn_child() over directly calling constructor!
function Proc:init(parent, f, arg)
  if parent then
    self.root = parent.root
    self._parent = parent
    parent:_add_child(self)
  else -- assume this is meant to be the root
    self.root = self
  end
  self._listeners = {} -- weak-keyed table of listeners
  setmetatable(self._listeners, {__mode = "k"})

  if f then
    self._co = coroutine.create(f)
    local happy, errmsg = coroutine.resume(self._co, self, arg)
    if not happy then
      log.error("Couldn't start proc: " .. tostring(errmsg))
      self._co = nil
    end
  else -- assume a persistent 'container' process is wanted
    self._persist = true
  end
end

function Proc:on(evttype, receiver, f)
  if not self._listeners[evttype] then self._listeners[evttype] = {} end
  self._listeners[evttype][receiver] = f
end

function Proc:off(evttype, receiver)
  if not self._listeners[evttype] then return end
  self._listeners[evttype][receiver] = nil
end

-- set whether this process persists after its main function returns
-- (i.e., if you want to keep children alive)
function Proc:persist(persist_state)
  self._persist = persist_state
end

-- emit an event *from* this proc to anything listening to this proc
function Proc:emit(evttype, evtdata, source)
  local targets = self._listeners[evttype]
  if not targets then return end
  for receiver, f in pairs(targets) do
    local retain = f(receiver, evttype, evtdata, source or self)
    if retain == false or receiver._dead then
      targets[receiver] = nil
    end
  end
end

-- spawn a child process from this process
-- f can be either a function or a class constructor
-- if a function: the function will be called as f(self_proc, ...)
-- if a constructor: will be called as Constructor(parent, ...)
function Proc:spawn_child(f, ...)
  if type(f) == "function" then
    return Proc(self, f, ...)
  else
    return f(self, ...)
  end
end

-- immediately kill this process
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

-- internal tick function
function Proc:_tick(t, dt)
  if self._co then
    if not self._cb then
      -- coroutine.resume(self._co, "tick", dt)
      self:_raw_resume("tick", dt)
    elseif self._timeout and self._timeout <= 0.0 then
      self._cb:_timeout(t)
    elseif self._timeout then
      self._timeout = self._timeout - dt
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

function Proc:_yield(cb, timeout)
  if self._cb then
    truss.error("Tried to yield from already yielded Proc!")
    return
  end
  self._cb = cb
  self._timeout = timeout
  return coroutine.yield()
end

-- wait one frame/tick
function Proc:wait_frame()
  self:_yield(nil, nil)
end

function Proc:_raw_resume(...)
  local happy, errmsg = coroutine.resume(self._co, ...)
  if not happy then
    self._co = nil
    log.error("Proc error: " .. errmsg)
  end
end

function Proc:_resume(cb, ...)
  if cb ~= self._cb then
    truss.error("Tried to resume from wrong callback!")
    return
  end
  self._cb = nil
  self._timeout = nil
  self:_raw_resume(...)
  --coroutine.resume(self._co, ...)
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

local Callback = class("Callback")
function Callback:init(parent)
  self._parent = parent
end

function Callback:kill()
  self._dead = true
  self._expire = true
end

function Callback:call(etype, edata, esource)
  if not self._parent:alive() then
    self:kill()
    return false
  end
  self.value = {etype, edata, esource}
  if self._parent._cb == self then
    self._parent:_resume(self, etype, edata, esource)
  end
  return self._expire
end

function Callback:wait_result(timeout)
  return self._parent:_yield(self, timeout)
end

function Callback:wait_result_type(typelist, timeout)
  local ttable = {}
  for _, etype in ipairs(typelist) do ttable[etype] = true end
  while true do
    local etype, edata, esource = self._parent:_yield(self, timeout)
    if ttable[etype] or etype == "timeout" then
      return etype, edata, esource
    end
  end
end

function Callback:_timeout(t)
  self:call("timeout", t)
end

function Proc:callback()
  return Callback(self)
end

function Proc:wait_event(target, evttype, timeout)
  local cb = self:callback()
  target:on(evttype, cb, cb.call)
  return cb:wait_result(timeout)
end

function Proc:wait_callback(f, timeout)
  local cb = self:callback()
  f(cb)
  return cb:wait_result(timeout)
end

function Proc:wait_any(cblist, timeout)
  local cb = self:callback()
  for _, f in ipairs(cblist) do
    f(cb)
  end
  return cb:wait_result(timeout)
end

-- local function on(target, evt)
--   return function(cb)
--     target:on(evt, cb, cb.call)
--   end
-- end

-- local evttype, evtdata = wait_event(some_object, "mousedown")
--
-- local cb = self:callback()
-- some_object:on("bla", cb, cb.call)
-- local evttype, evtdata = cb:wait_result()

return m
