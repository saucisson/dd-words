#! /usr/bin/env lua

local json  = require "dkjson"
local mongo = require "mongo"

local db = assert (mongo.Connection.New ())
assert (db:connect "localhost")
assert (db:remove ("test.values", {}))

local filename = arg [1]
local data = (function ()
  local file = io.open (filename, "r")
  local text = file:read ("*all")
  local data = json.decode (text)
  file:close ()
  return data
end) ()

for _, v in ipairs (data) do
  assert (db:insert ("test.values", v))
end

print ("# Words: " .. (db:count "test.values"))
