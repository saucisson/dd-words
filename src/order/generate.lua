#! /usr/bin/env lua

-- TODO: change this value when required!
local list_size = 10

if #arg ~= 1 then
  print (tostring (arg [0]) .. " <json file>")
  os.exit (1)
end

local json = require "dkjson"

local file = io.open (arg [1], "r")
local text = file:read ("*all")
local data = json.decode (text)
file:close ()

local function is_value (x)
  return type (x) ~= "table"
end

local function is_map (x)
  return type (x) == "table" and #x == 0
end

local function is_list (x)
  return type (x) == "table" and #x ~= 0
end

local function keys (x)
  local result = {}
  for k, _ in pairs (x) do
    result [#result + 1] = k
  end
  table.sort (result)
  return result
end

local function order (x, prefix)
  prefix = prefix or ""
  if is_value (x) then
    return prefix
  elseif is_map (x) then
    local result = {}
    local ks = keys (x)
    for _, k in ipairs (ks) do
      result [#result + 1] = order (x [k], prefix .. "/" .. k)
    end
    return result
  elseif is_list (x) then
    local result = {}
    for i = 1, list_size do
      result [#result + 1] = order (x [1], prefix .. "/" .. tostring (i))
    end
    return result
  end
end

print (json.encode (order (data [1])))
