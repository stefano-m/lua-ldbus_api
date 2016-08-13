package = "ldbus_api"
 version = "0.9snapshot-1"
 source = {
    url = "git://github.com/stefano-m/lua-ldbus_api",
    tag = "master"
 }
 description = {
    summary = "An high level DBus API on top of ldbus",
    detailed = [[
    An high level DBus API built on top of ldbus.
    Adds the `ldbus.api` and `ldbus.buses` tables to `ldbus`.
    ]],
    homepage = "https://github.com/stefano-m/lua-ldbus_api",
    license = "Apache v2.0"
 }
 dependencies = {
    "lua >= 5.1",
    "ldbus"
 }
 supported_platforms = { "linux" }
 build = {
    type = "builtin",
    modules = { ldbus_api = "ldbus_api.lua" },
    copy_directories = { "doc", "tests" }
 }
