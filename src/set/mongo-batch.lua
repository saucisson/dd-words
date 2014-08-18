#! /usr/bin/env lua

local json  = require "dkjson"
local mongo = require "mongo"

local subsize = 10000

local db = assert (mongo.Connection.New ())
assert (db:connect "localhost")
assert (db:remove ("test.values", {}))

local max_name = 0
local counts   = {}
local max_size = 1
for _, name in ipairs (arg) do
  max_name = math.max (max_name, #name)
  local count = 0
  for line in io.lines (name) do
    count = count + 1
  end
  counts [name] = count
  max_size = math.max (max_size, math.ceil (math.log10 (count)))
end
print (max_size)

local function pad (str, size, where)
  str = tostring (str)
  local result = ""
  if where == "left" then
    for i = 1, size - #str do
      result = result .. " "
    end
    result = result .. str
  elseif where == "right" then
    result = result .. str
    for i = 1, size - #str do
      result = result .. " "
    end
  end
  return result
end

for _, name in ipairs (arg) do
  local count = 0
  local lines = {}
  io.write (pad (name, max_name + 5, "right"))
  io.write ("\27[s")
  io.flush ()
  for line in io.lines (name) do
    if count % subsize == 0 then
      assert (db:insert_batch ("test.values", lines))
      lines = {}
      io.write ("\27[u")
      io.write (pad (count, max_size, "left") ..
                " / " ..
                pad (counts [name], max_size, "left"))
      io.flush ()
    end
    lines [#lines + 1] = {
      word = line,
    }
    count = count + 1
  end
  io.write ("\27[u")
  io.write (pad (count, max_size, "left") ..
            " / " ..
            pad (counts [name], max_size, "left"))
  print ""
end

print ("# Words: " .. (db:count "test.values"))
