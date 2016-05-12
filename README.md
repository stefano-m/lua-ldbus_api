# Description

A high level [DBus](https://dbus.freedesktop.org/doc/dbus-specification.html)
API for Lua built on top of the
[ldbus](https://github.com/daurnimator/ldbus) library.

# DBus data representation:

[DBus data is typed](https://dbus.freedesktop.org/doc/dbus-specification.html#type-system), this is mapped in a Lua table with the following shape:

    dbus_data = {
         sig = <DBus signature>,
         value = <Lua type>
       }

## Basic types

### Int32 and other numbers
All DBus numeric types map to Lua numbers. For example:

       {
         sig = ldbus.basic_types.int32, -- i.e. "i"
         value = 256
       }

### Boolean

       {
         sig = ldbus.basic_types.boolean, -- i.e. "b"
         value = false
       }

## Container types

### Variant

       {
           sig = ldbus.types.variant, -- i.e. "v"
           value = <DBus data>
       }

example:

       {
           sig = ldbus.types.variant,
           value = {
                       sig = ldbus.basic_types.uint32,
                       value = 4294967295
                    }
       }

### Array
A DBus array is an homogeneous Lua array, i.e. an array whose
elements are of the same type.

       {
         sig = ldbus.types.array .. <contents signature>,
         value = {<contents>} -- homogeneous array
       }

   examples:

       {
         sig = "ai", -- i.e. array of int32
         value = {1, 2, 3, 4, 5, 6}
       }

       {
         sig = "aas", -- i.e. array of arrays of strings
         value = {{"a", "b"}, {"c", "d"}, {"e"}}
       }

### Dictionary (Array of Dict Entries)

       {
         sig = ldbus.types.array .. "{" .. <key type> <value type> .. "}",
         value = { <key1> = <value1>, <key2> = <value2>}
       }

   examples:

       {
         sig = "a{ss}"
         value = {a = "A", b = "B", c = "C"}
       }

       {
         sig = "a{sa{si}}", -- nested dictionary
         value = {outer1 = {inner1 = 1}, outer2 = {inner2 = 2}}
       }

### Struct

      {
        sig = "(" .. <type1> .. <type2> .. <type3> [...] .. ")",
        value = { <value1>, <value2>, <value3>, [...]} -- heterogeneous array
      }

   examples:

      {
        sig = "(ibs)",
        value = { 1, true, "hello Lua!"}
      }

      {
        sig = "(ia{si}s)",
        value = {1, {one = 5, two = 6, three = 7}, "hello Lua!"}
      }

# Generating the documentation

You will need [ldoc](https://stevedonovan.github.io/ldoc/) to generate the documentation.
Once it's installed, you can run `ldoc .` from the project's directory (i.e. where `config.ld` is located).
The command will generate HTML documentation in the `doc` folder.
