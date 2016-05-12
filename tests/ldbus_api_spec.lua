-- Works with the 'busted' framework.
-- http://olivinelabs.com/busted/

package.path = "../?.lua;" .. package.path

local ldbus = require("ldbus_api")

describe("Integration with ldbus", function ()
            local server

            local function sleep(n)
               -- no builtin sleep function in Lua.
               os.execute("sleep " .. tonumber(n))
            end

            local function wait_for_signal(watcher, timeout)
               local i = 0
               timeout = timeout or 5

               local result
               repeat
                  i = i + 1
                  sleep(0.01)
                  result = watcher()
               until (result ~= "no_answer" or i > timeout)

               if i > timeout then
                  error("timed out", 2)
               end

               return result
            end

            setup(function ()
                  -- create a server in an external process
                  -- so the tests won's share the DBus connection
                  -- with it.
                  server = io.popen("lua dbus_echo_server.lua")
                  sleep(0.01) -- wait for the server to start
            end)

            teardown(function ()
                  local fifo_file = "/tmp/dbus_echo_server.fifo"
                  local fifow = assert(io.open(fifo_file, "w"))
                  fifow:write("exit")
                  fifow:close()
                  server = nil
                  sleep(0.01) -- wait for the server to exit.
            end)

            it("can call with no argument", function ()

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod"
                  })

                  assert.is_nil(ldbus.api.get_async_response(pending_response))

            end)

            it("can call with string argument", function ()

                  local expected = "test_arg"

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = {
                           {sig = ldbus.basic_types.string,
                            value = expected}
                        }
                  })

                  local response = ldbus.api.get_async_response(pending_response)

                  assert.are.equal(ldbus.basic_types.string, response[1].sig)
                  assert.are.equal(expected, response[1].value)
            end)

            it("can call with int32 argument", function ()

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = {
                           {sig = ldbus.basic_types.int32,
                            value = 256}
                        }
                  })

                  local response = ldbus.api.get_async_response(pending_response)
                  assert.are.equal(ldbus.basic_types.int32, response[1].sig)
                  assert.are.equal(256, response[1].value)

            end)

            it("can call with boolean argument", function ()

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = {
                           {sig = ldbus.basic_types.boolean,
                            value = false}
                        }
                  })

                  local response = ldbus.api.get_async_response(pending_response)
                  assert.are.equal(ldbus.basic_types.boolean, response[1].sig)
                  assert.is_false(response[1].value)

            end)

            it("can call with byte argument", function ()

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = {
                           {sig = ldbus.basic_types.byte,
                            value = 0}
                        }
                  })

                  local response = ldbus.api.get_async_response(pending_response)
                  assert.are.equal(ldbus.basic_types.byte, response[1].sig)
                  assert.are.equal(0, response[1].value)

            end)

            it("can call with array of basic types", function ()

                  local expected = {
                     {sig = ldbus.types.array .. ldbus.basic_types.string,
                      value = {"a", "b", "c"}}
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, ldbus.api.get_async_response(pending_response))
            end)

            it("can call with array of arrays of basic types", function ()

                  local expected = {
                     {sig = ldbus.types.array ..
                         ldbus.types.array ..
                         ldbus.basic_types.string,
                      value = {{"a", "b", "c"},
                         {"d", "e", "f"},
                         {"g", "h", "i"}
                     }}
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, ldbus.api.get_async_response(pending_response))
            end)

            it("can call with array of nested structs", function ()

                  local expected = {
                     {sig = ldbus.types.array .. "(ib(ss))",
                      value = {{0, false, {"x", "a"}},
                         {5, true, {"y", "b"}},
                         {987, true, {"z", "c"}}}}
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, ldbus.api.get_async_response(pending_response))
            end)

            it("can call with variant argument", function ()

                  local expected ={
                     {
                        sig = ldbus.types.variant,
                        value = {sig = ldbus.basic_types.uint32,
                              value = 4294967295}
                     }
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, ldbus.api.get_async_response(pending_response))
            end)

            it("can call with more than one basic type", function ()

                  local expected = {
                     {sig = "s",
                      value = "hello"},
                     {sig = "i",
                      value = 42}
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, ldbus.api.get_async_response(pending_response))
            end)

            it("can call with a struct of basic types", function ()

                  local expected = {
                     {sig = "(isb)",
                      value = {1, "test", false}},
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, ldbus.api.get_async_response(pending_response))
            end)

            it("can call with a nested struct", function ()
                  local expected = {
                     {sig = "(i(bs)s)",
                      value = {1, {false, "inner"}, "outer"}
                      }
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, ldbus.api.get_async_response(pending_response))
            end)

            it("can parse signatures", function ()
                  local sig = ""
                     .. "a{ss}"
                     .. "ai"
                     .. "i"
                     .. "ab"
                     .. "s"
                     .. "(iii)"
                     .. "aai"
                     .. "a{s(bib)}"
                     .. "(i(ii))"
                     .. "((ii)(ii))"
                     .. "(ia{ss}b)"
                     .. "(ia{b(ii)}aai(iaab))"
                  assert.are.same(
                     {
                        "a{ss}",
                        "ai",
                        "i",
                        "ab",
                        "s",
                        "(iii)",
                        "aai",
                         "a{s(bib)}",
                         "(i(ii))",
                         "((ii)(ii))",
                         "(ia{ss}b)",
                         "(ia{b(ii)}aai(iaab))",
                     },
                     ldbus.api.parse_signature(sig))
            end)

            it("can call with a struct that contains an array", function ()
                  local expected = {
                     {sig = "(iais)",
                      value = {1, {5, 6, 7, 8, 9}, "outer"}
                      }
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, ldbus.api.get_async_response(pending_response))
            end)

            it("can call with a struct that contains a dictionary", function ()
                  local expected = {
                     {sig = "(ia{si}s)",
                      value = {1, {one = 5, two = 6, three = 7}, "outer"}
                      }
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, ldbus.api.get_async_response(pending_response))
            end)

            it("can call with a dictionary (array of dict_entry) whose values are basic types", function ()

                  local expected = {
                     {sig = "a{ss}",
                     value = {first = "hello", second = "lua!"}}
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, ldbus.api.get_async_response(pending_response))
            end)

            it("can call with a nested dictionary", function ()

                  local expected = {
                     {sig = "a{sa{si}}",
                      value = {first = {hello = 1},
                               second = {lua = 2}}}
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected,
                                  ldbus.api.get_async_response(pending_response))
            end)

            it("can call with a dictionary (array of dict_entry) whose values are nested structs", function ()

                  local expected = {
                     {sig = "a{s(i(sb)i)}",
                      value = {first = {5, {"x", true}, 6},
                               second = {7, {"y", false}, 8}}}
                  }

                  local pending_response = ldbus.api.call_async(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected,
                                  ldbus.api.get_async_response(pending_response))
            end)

            it("can call with variant of array", function ()

                  local expected ={
                     {
                        sig = ldbus.types.variant,
                        value = {sig = "ab",
                              value = {false, true, false, false}}
                     }
                  }

                  local actual = ldbus.api.call(
                     {
                        bus = "session",
                        dest = "com.example.testServer",
                        path = "/com/example/testServer",
                        interface = "com.example.testServer",
                        method = "TestMethod",
                        args = expected
                  })

                  assert.are.same(expected, actual)
            end)

            it("can call with no arguments and get a string", function ()
                  assert.is_string(
                     ldbus.api.call(
                        {
                           bus = "session",
                           dest = "org.freedesktop.DBus",
                           path = "/org/freedesktop/DBus",
                           interface = "org.freedesktop.DBus",
                           method = "GetId"
                        })[1].value)
            end)

            it("can call with no arguments and get a table", function ()
                  local result = ldbus.api.call(
                     {
                        bus = "session",
                        dest = "org.freedesktop.DBus",
                        path = "/org/freedesktop/DBus",
                        interface = "org.freedesktop.DBus",
                        method = "ListNames"
                  })[1]
                  assert.are.equal(ldbus.types.array .. ldbus.types.string,
                                   result.sig)
                  for i=1, #result.value do
                     assert.is_string(result.value[i])
                  end
            end)

            it("can call with base type arguments", function ()
                  assert.is_number(
                     ldbus.api.call(
                        {
                           bus = "session",
                           dest = "org.freedesktop.DBus",
                           path = "/org/freedesktop/DBus",
                           interface = "org.freedesktop.DBus",
                           method = "GetConnectionUnixUser",
                           args = {
                              {sig = ldbus.basic_types.string,
                               value = "org.freedesktop.DBus"}
                           }
                        })[1].value)
            end)


            it("can watch signals on given interface", function ()
                  -- must filter interface or may get signals from
                  -- other DBus clients!
                  local filter = "type=signal,"
                     .. "interface=com.example.testServer.TestType"

                  local watcher, connection = ldbus.api.watch("session", filter)

                  local expected = {
                     {sig = ldbus.basic_types.string,
                      value = "someOtherValue"}
                  }

                  assert.is_true(
                     ldbus.api.send_signal(
                        {
                           bus = "session",
                           path = "/com/example/otherTestServer",
                           interface = "com.example.otherTestServer.OtherTestType",
                           signal = "OtherTestSignal",
                           args = {sig = ldbus.basic_types.boolean,
                                   value = true}
                        }
                  ))

                  assert.is_true(
                     ldbus.api.send_signal(
                        {
                           bus = "session",
                           path = "/com/example/testServer",
                           interface = "com.example.testServer.TestType",
                           signal = "TestSignal",
                           args = expected
                        }
                  ))
                  -- first is always NameAcquired signal from DBus
                  -- which returns the unique name of the connection.
                  -- Since it's destination is the connection we create
                  -- it will ALWAYS match.
                  assert.are.equal(ldbus.bus.get_unique_name(connection),
                                   wait_for_signal(watcher)[1].value)

                  -- first signal does not match the rule.
                  -- second signal returns its args.
                  assert.are.same(expected,
                                  wait_for_signal(watcher))
                  -- there are no more signals, so we get a time out.
                  assert.has_error(function ()
                        wait_for_signal(watcher)
                                   end, "timed out")
                  assert(ldbus.bus.remove_match(connection, filter, true))
            end)

            it("can watch signals on given member", function ()
                  local filter = "type=signal,member=TestSignal"

                  local watcher, connection = ldbus.api.watch("session", filter)

                  local expected = {
                     {sig = ldbus.basic_types.string,
                      value = "yetSomeOtherValue"}
                  }

                  assert.is_true(
                     ldbus.api.send_signal(
                        {
                           bus = "session",
                           path = "/com/example/otherTestServer",
                           interface = "com.example.testServer.TestType",
                           signal = "OtherTestSignal",
                           args = {sig = ldbus.basic_types.boolean,
                                   value = true}
                        }
                  ))

                  assert.is_true(
                     ldbus.api.send_signal(
                        {
                           bus = "session",
                           path = "/com/example/testServer",
                           interface = "com.example.testServer.TestType",
                           signal = "TestSignal",
                           args = expected
                        }
                  ))

                  -- first signal does not match the rule.
                  -- second signal returns its args.
                  assert.are.same(expected,
                                  wait_for_signal(watcher))
                  -- there are no more signals, so we get a time out.
                  assert.has_error(function ()
                        wait_for_signal(watcher)
                                   end, "timed out")
                  assert(ldbus.bus.remove_match(connection, filter, true))
            end)

            it("can watch errors", function ()
                  local filter = "type=error,"
                     .. "interface=com.example.testServer.TestType"

                  local wrong_destination = "something.that.does.not.exist"
                  local watcher, connection = ldbus.api.watch("session", filter)

                  local expected = {
                     {sig = ldbus.basic_types.string,
                      value = 'The name '..
                         wrong_destination ..
                         ' was not provided by any .service files'}
                  }

                  assert.is_not_nil(
                     ldbus.api.call_async(
                        {
                           bus = "session",
                           dest = wrong_destination,
                           path = "/com/example/testServer",
                           interface = "com.example.testServer.TestType",
                           method = "TestMethod",
                           args = expected
                        }
                  ))
                  assert.are.same(expected,
                                  wait_for_signal(watcher))
                  -- there are no more signals, so we get a time out.
                  assert.has_error(function ()
                        wait_for_signal(watcher)
                                   end, "timed out")
                  assert(ldbus.bus.remove_match(connection, filter, true))
            end)
end)

describe("Getting values from DBus data", function ()
            it("works on simple variants", function ()
                  local expected =  4294967295

                  dbus_data = {
                     sig = "v",
                     value = {sig = "i",
                              value = expected}
                  }

                  assert.are.equal(
                     expected,
                     ldbus.api.get_value(dbus_data))
            end)

            it("works on container variants", function ()
                  local expected =  {1, 2, 3, 4}

                  dbus_data = {
                     sig = "vai",
                     value = {sig = "ai",
                              value = expected}
                  }

                  assert.are.same(
                     expected,
                     ldbus.api.get_value(dbus_data))
            end)

            it("works with a dictionary of variants", function ()
                 local expected = {
                   a_string = "some string",
                   an_array = {"a", "b", "c"},
                   a_number = 5
                 }

                 dbus_data = {
                   sig = "a{sv}",
                   value = {
                     a_string = {sig = "v", value = {sig = "s", value = "some string"}},
                     an_array = {sig = "v", value = {sig = "as", value = {"a", "b", "c"}}},
                     a_number = {sig = "v", value = {sig = "i", value = 5}}
                   }
                 }

                 assert.are.same(
                   expected,
                   ldbus.api.get_value(dbus_data))
            end)

            it("works with a nested dictionary", function ()
                  local expected = {first = {hello = 1},
                                    second = {lua = 2}}
                  dbus_data = {sig = "a{sa{si}}",
                               value = expected}
                  assert.are.same(
                     expected,
                     ldbus.api.get_value(dbus_data))
            end)

            it("works with a false boolean", function ()
                 local expected = false
                 dbus_data = {sig = "v",
                              value = {sig = "b", value = expected}}
                 assert.are.same(expected,
                                ldbus.api.get_value(dbus_data))
            end)

            it("won't allow to set anything on the 'bus' table", function ()
                  assert.has_error(function ()
                        ldbus.buses.something = 1
                  end, "Cannot set values")
            end)

            it("has the 'system and 'session' buses", function ()
                 assert.not_nil(ldbus.buses.system)
                 assert.not_nil(ldbus.buses.session)
            end)

            it("fails with a wrong DBus address", function ()
                  assert.has_error(function ()
                        local x = ldbus.buses.something_else
                                   end,
                    "Address does not contain a colon")
            end)

            it("fails when it cannot connect to a socket", function ()
                 assert.has_error(function ()
                     local x = ldbus.buses["unix:path=/dev/null"]
                                  end,
                   "Failed to connect to socket /dev/null: Connection refused")
            end)

            it("fails when a non-existent file is requested", function ()
                 local non_existent = "/tmp/" .. tostring(os.time())
                 assert.has_error(function ()
                     local x = ldbus.buses["unix:path=" .. non_existent]
                                  end,
                   "Failed to connect to socket " ..
                     non_existent ..
                     ": No such file or directory")
            end)

            -- TODO: test with a valid socket (unix or TCP/IP)?
end)
