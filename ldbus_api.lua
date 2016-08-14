--[[
  Copyright 2016 Stefano Mazzucco

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]

--[[--
  A high level [DBus](https://dbus.freedesktop.org/doc/dbus-specification.html)
  API for Lua built on top of the
  [ldbus](https://github.com/daurnimator/ldbus) library.

  Adds the `ldbus.api` and `ldbus.buses` tables to `ldbus`.

  @license Apache License, version 2.0
  @author Stefano Mazzucco <stefano AT curso DOT re>
  @copyright 2016 Stefano Mazzucco
]]

local ldbus = require("ldbus")

ldbus.api = {}

--- Available connections to the DBus daemon. Fields on this table
-- can only be accessed. Trying to set fields will result in an error.
-- @field session Connection to the session bus for this process
-- @field system  Connection to the system bus for this process
-- @field any_valid_dbus_address Connection to the
-- [DBus address](https://dbus.freedesktop.org/doc/dbus-tutorial.html#addresses).
-- If a connection cannot be established, an error will be raised.
-- @table ldbus.buses
ldbus.buses = {}
setmetatable(ldbus.buses,
             {
               __index = function(tbl, key)
                 local v
                 if key == "session" or key == "system" then
                   v = assert(ldbus.bus.get(key), "Could not get bus " .. key)
                 else
                   v = assert(ldbus.connection.open(key))
                 end
                 rawset(tbl, key, v)
                 return v
               end,
               __newindex = function() error("Cannot set values", 2) end
})

local _noop_mt = {
  -- Return a function that returns nil
  __index = function ()
    return function () return nil end
  end
}

local _dbus2lua = {}
setmetatable(_dbus2lua, _noop_mt)

--- Return a table representing DBus data from a DBus iterable.
-- @param iter A DBus iterable obtained from ldbus.
-- @return A table with 'sig' and 'value' fields representing DBus data.
-- @see from_message
function ldbus.api.from_iter(iter)
  return _dbus2lua[iter:get_arg_type()](iter)
end

do
  for _, v in pairs(ldbus.basic_types) do
    _dbus2lua[v] = function(it) return {sig = v, value = it:get_basic()} end
  end

  _dbus2lua[ldbus.types.variant] = function (it)
    return {sig = ldbus.types.variant, value = ldbus.api.from_iter(it:recurse())}
  end

  _dbus2lua[ldbus.types.dict_entry] = function (it)
    local contents = it:recurse()
    local k = assert(contents:get_basic(),
                     "Key in dict entry must be of basic type")
    contents:next()
    local v = assert(ldbus.api.from_iter(contents), "Dict entry can't have nil value").value
    return {key = k, value = v}
  end

  local function _to_array_or_dict_or_struct(it)
    local t = {sig = it:get_signature(), value = {}}
    local contents = it:recurse()
    local d
    while contents:get_arg_type() do
      d = ldbus.api.from_iter(contents)
      if d.key then
        -- array of dict_entry, i.e. dictionary
        t.value[d.key] = d.value
      else
        -- array (homogeneous) or struct (inhomogeneos)
        t.value[#t.value + 1] = d.value
      end
      contents:next()
    end
    return t
  end

  _dbus2lua[ldbus.types.struct] = _to_array_or_dict_or_struct

  _dbus2lua[ldbus.types.array] = _to_array_or_dict_or_struct
end

--- Return an array of tables representing DBus data from a DBus message, or nil.
-- @param message A DBus message obtained from ldbus.
-- @return An array of tables with 'sig' and 'value' fields representing DBus data.
-- @return nil If the message is empty
-- @see from_iter
function ldbus.api.from_message(message)
  local iter = ldbus.message.iter.new()
  local t = {}
  if message:iter_init(iter) then
    while iter:get_arg_type() do
      t[#t+1] = ldbus.api.from_iter(iter)
      iter:next()
    end
    return t
  end
  return nil
end

local _basic_types = {}
for k, v in pairs(ldbus.basic_types) do
  _basic_types[v] = k
end

--- Parse a string representing a DBus signature.
-- The returned values can be passed to parse_signature again
-- for further refinement.
-- @param sig A string representing a DBus signature.
-- @return An array of strings representing the components of the signature.
function ldbus.api.parse_signature(sig)
  local function _reduce_sig(char, init)
    if _basic_types[char] then
      if init.rest == "" then
        init.types[#init.types + 1] = char
      elseif init.rest:match("^a*[%({]") then
        init.rest = init.rest .. char
      else
        init.types[#init.types + 1] = init.rest .. char
        init.rest = ""
      end
    else
      init.rest = init.rest .. char
      if init.rest:match("^%b()") then
        init.types[#init.types + 1] = init.rest
        init.rest = ""
      elseif init.rest:match("^a%b{}") then
        init.types[#init.types + 1] = init.rest
        init.rest = ""
      end
    end
  end

  local init = {types = {}, rest = ""}

  for c in sig:gmatch(".") do
    _reduce_sig(c, init)
  end

  assert(init.rest == "",
         "Can't parse signature. Rest not empty: " .. init.rest)
  return init.types
end

local _lua2dbus = {}
setmetatable(_lua2dbus, _noop_mt)

local function _iter_append(iter, data)
  _lua2dbus[data.sig:sub(1, 1)](iter, data)
end

do
  for _, v in pairs(ldbus.basic_types) do
    _lua2dbus[v] = function (iter, data)
      assert(iter:append_basic(data.value, data.sig), "Could not append basic value")
    end
  end

  _lua2dbus[ldbus.types.variant] = function (iter, data)
    local container = assert(
      iter:open_container(ldbus.types.variant, data.value.sig),
      "Could not open variant container")
    _iter_append(container, data.value)
    iter:close_container(container)
  end

  _lua2dbus[ldbus.types.array] = function (iter, data)
    local t_contents = data.sig:match("^a%b{}")
      and data.sig:sub(3, -2)  -- dictionary
      or data.sig:sub(2)       -- array

    -- Figure out whether it's a dict or an array.
    local t1, t2 = unpack(ldbus.api.parse_signature(
                            t_contents))
    local t_value = t2 and t2 or t1
    local t_key = t2 and t1

    local container
    if t_key then
      assert(_basic_types[t_key],
             "dict key must be of basic type, got " .. t_key)
      container = assert(
        iter:open_container(ldbus.types.array,
                            string.format("{%s}", t_contents)),
        "Could not open dictionary container")
      for k, v in pairs(data.value) do
        local entry = assert(
          container:open_container(ldbus.types.dict_entry, nil),
          "Could not open dict entry container")
        _iter_append(entry, {sig = t_key, value = k})
        _iter_append(entry, {sig = t_value, value = v})
        container:close_container(entry)
      end
    else
      container = assert(
        iter:open_container(ldbus.types.array, t_value),
        "Could not open array container")
      for _, v in pairs(data.value) do
        _iter_append(container, {sig = t_contents, value = v})
      end
    end

    if container then
      iter:close_container(container)
    end
  end

  _lua2dbus["("] = function (iter, data)
    local container = assert(
      iter:open_container(ldbus.types.struct, nil),
      "Could not open struct container")
    local t_contents = data.sig:sub(2, #data.sig - 1)
    for i, t in ipairs(ldbus.api.parse_signature(t_contents)) do
      _iter_append(container,
                   {sig = t,
                    value = data.value[i]})
    end
    iter:close_container(container)
  end
end

local function _append_to(msg, datalist)
  local iter = ldbus.message.iter.new()
  msg:iter_init_append(iter)

  for _, data in ipairs(datalist) do
    _iter_append(iter, data)
  end
end

local function _init_call(opts)
  local conn = ldbus.buses[opts.bus]

  local msg = assert(ldbus.message.new_method_call(
                       opts.dest,
                       opts.path,
                       opts.interface,
                       opts.method),
                     "Could not create message from method call")

  if opts.args then
    _append_to(msg, opts.args)
  end

  return conn, msg
end

--[[-- Call a DBus method on a given interface blocking execution.
  @param opts A table defining the options to be passed.

  `opts` must contain the following fields:

  > `bus`: The bus name ("session" or "system") or a valid
  > [DBus address](https://dbus.freedesktop.org/doc/dbus-tutorial.html#addresses)
  > as a string.

  > `dest`: The destination as a string.

  > `path`: The object path as a string.

  > `interface`: The interface name as a string.

  > `method`: The method to be called as a string.

  > `args`: The arguments to be passed to the method as an array of DBus data.

  The following field is optional:

  > `timeout`: The timeout in seconds as a number after which the blocking call will fail.

  @return A table representing the DBus data.
  @see call_async
  @see from_message
]]
function ldbus.api.call(opts)
  local conn, msg = _init_call(opts)
  local reply = assert(conn:send_with_reply_and_block(msg, opts.timeout))
  return ldbus.api.from_message(reply)
end

--- Call a method on a DBus interface asynchrounously.
-- @param opts A table defining the options to be passed.
-- @return An UserData object representing a pending DBus call
-- @see call
function ldbus.api.call_async(opts)
  local conn, msg = _init_call(opts)
  return assert(conn:send_with_reply(msg, opts.timeout))
end

--- Forcefully get a response from a pending DBus call.
-- This is a blocking call that may never return!
-- @param pending An UserData object representing a pending DBus call
-- @return A table representing the DBus data.
-- @see from_message
-- @see call_async
function ldbus.api.get_async_response(pending)
  pending:block()
  local reply = pending:steal_reply()
  return ldbus.api.from_message(reply)
end

local function _init_signal(opts)
  local conn = ldbus.buses[opts.bus]

  if opts.dest then
    assert(ldbus.bus.request_name(
             conn,
             opts.dest,
             {replace_existing = true}),
           "Could not request connection " .. opts.dest)
  end

  local msg = assert(ldbus.message.new_signal(
                       opts.path,
                       opts.interface,
                       opts.signal),
                     "Could not get message from signal")

  if opts.args then
    _append_to(msg, opts.args)
  end

  return conn, msg
end

--[[-- Send a signal.
  @param opts A table defining the options to be passed.

  `opts` must contain the following fields:

  > `bus`: The bus name ("session" or "system") or a valid
  > [DBus address](https://dbus.freedesktop.org/doc/dbus-tutorial.html#addresses)
  > as a string.

  > `path`: The object path as a string.

  > `interface`: The interface name as a string.

  > `signal`: The signal to be sent as a string.

  > `args`: The arguments to be passed to the method as an array of DBus data.

  The following field is optional as signals usually do not need a destination:

  > `dest`: The destination as a string.

  @return Whether the signal was sent or not (`true` or `false`/`nil`).
]]
function ldbus.api.send_signal(opts)
  local conn, msg = _init_signal(opts)
  local status = conn:send(msg)
  conn:flush()
  return status
end

--[[--Watch a bus for messages matching a filter.
  @param bus The bus name ("session" or "system") or a valid
  [DBus address](https://dbus.freedesktop.org/doc/dbus-tutorial.html#addresses)
  as a string.
  @param filter A string that conforms to the
  [DBus match rules](https://dbus.freedesktop.org/doc/dbus-specification.html#message-bus-routing-match-rules).
  For example:

  filter="type=signal,sender=org.freedesktop.DBus,\
  interface=org.freedesktop.DBus,\
  member=Foo,path=/bar/foo"

  @return A function (that wraps a coroutine) that can be called with no arguments
  **and** the DBus connection returned by the DBus daemon.
  The function call will return the DBus data table that matches the filter,
  or `"no_answer"` if nothing has been received yet. If the connection is closed,
  the function will return `"connection_closed"`.

  **Note**:

  * `ldbus.bus.add_match` is used internally for the session and system buses
  **only**.
  * all messages that specify the current connection as its **destination**
  will be matched **regardless** of the filter.
  * each call to `watch` within the **same process** will **append** a match rule
  to the **same** connection.
  E.g. when one calls `watch("session", "type=signal")` and then they call
  `watch("session", "member=SomeMethod")`, the function returned by the **second**
  call will also match the messages from **first** filter!
  This is due to the fact that DBus returns one unique connection per process.
  You can still use the connection returned to remove the previous filter, e.g.
  `w, c = watch("session", "member=SomeMethod")` and then
  `ldbus.bus.remove_match(c, "type=signal)`.
  That would of course break the **first** call though.
]]
function ldbus.api.watch(bus, filter)
  local conn = ldbus.buses[bus]

  if bus == "session" or bus == "system" then
    assert(ldbus.bus.add_match(conn, filter),
           "Could not add match rule " .. filter)
  end

  conn:flush()

  local fn =  coroutine.wrap(
    function ()
      while conn:read_write(0) do
        local msg = conn:pop_message()
        local result = "no_answer"
        if msg then
          result = ldbus.api.from_message(msg)
        end
        coroutine.yield(result)
      end
      coroutine.yield("connection_closed")
  end)

  return fn, conn
end

--[[-- Serve a an interface on the given bus.
  @param bus The bus name ("session" or "system") or a valid
  [DBus address](https://dbus.freedesktop.org/doc/dbus-tutorial.html#addresses)
  as a string.
  @param destination The destination interface.
  @param callbacks An array of functions that will be called when the interface
  receives a method call.

  Each callback will be passed a DBus message and a DBus connection
  and it should return two parameters: `status` and `serial` that should
  be compatible to what `ldbus` uses in `connection:send`.
  In particular, if `status` is `nil` it means that the request has not
  been processed yet. If a callback errors, the `{false, <ERROR MESSAGE>}` pair
  is returned istead.

  @return A function that accepts no arguments (and wraps a coroutine).
  Each time the function is called, it will return an array of
  the `status` and `serial` from the callback or the pair
  "connection_closed", `nil` if the connection is closed.

  @see ldbus.api.examples.echo
]]
function ldbus.api.serve(bus, destination, callbacks)
  local conn = ldbus.buses[bus]
  assert(
    assert(ldbus.bus.request_name(conn,
                                  destination,
                                  {replace_existing = true}),
           "Could not request connection " .. destination) == "primary_owner",
    "Not primary owner of connection " .. destination)

  local fn =  coroutine.wrap(
    function ()
      local results = {}
      while conn:read_write(0) do
        local msg = conn:pop_message()
        if msg and msg:get_type() == "method_call" then
          for i, callback in ipairs(callbacks) do
            local did_succeed, status, serial = pcall(callback, msg, conn)
            if did_succeed then
              results[i] = {status, serial}
            else
              results[i] = {did_succeed, status}
            end
          end
        end
        coroutine.yield(results)
      end
      coroutine.yield("connection_closed", nil)
  end)

  return fn
end

--- Get the value from DBus data
-- @param dbus_data A table representing DBus data (i.e. has a key called 'value') or a basic Lua type (number, string, etc.)
-- @return The value of the DBus data with its signature stripped
function ldbus.api.get_value(dbus_data)
  if type(dbus_data) == "table" then
    if dbus_data.value ~= nil then
      return ldbus.api.get_value(dbus_data.value)
    else
      local t = {}
      for k, v in pairs(dbus_data) do
        t[k] = ldbus.api.get_value(v)
      end
      return t
    end
  else
    return dbus_data
  end
end

ldbus.api.examples = {}

--[[-- Callback that sends back whatever it receives.
  @param msg An ldbus DBus message
  @param conn An ldbus DBus connection
  @return The `status`, `serial` pair returned by `ldbus` `connection:send`
  @see serve
]]
function ldbus.api.examples.echo(msg, conn)
  local data = ldbus.api.from_message(msg)

  local response = assert(msg:new_method_return(),
                          "Could not create reply to method call")

  if data then
    _append_to(response, data)
  end

  local status, serial = conn:send(response)
  conn:flush()
  return status, serial
end

return ldbus
