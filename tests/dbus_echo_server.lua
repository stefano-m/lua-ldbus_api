package.path = "../?.lua;" .. package.path

local ldbus = require("ldbus_api")

local function sleep(n)
   -- no builtin sleep function in Lua.
   os.execute("sleep " .. tonumber(n))
end

-- Ugly way to get non-blocking IO.
local fifo_file = "/tmp/dbus_echo_server.fifo"
local fifow = assert(io.open(fifo_file, "w"))
fifow:close()
local fifo = assert(io.open(fifo_file))

local function process_requests(srv)
   while true do
      sleep(0.01)
      srv()
      if fifo:read() == "exit" then
         fifo:close()
         assert(io.popen("rm -f " .. fifo_file))
         return 0
      end
   end
end

local destination = "com.example.testServer"
print("Start echo server on " .. destination)
process_requests(ldbus.api.serve("session",
                            destination,
                            {ldbus.api.examples.echo}))
print("Echo server stopped")
