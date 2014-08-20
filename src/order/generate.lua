#! /usr/bin/env lua

-- TODO: change this value when required!
local list_size = 10

if #arg ~= 1 then
  print (tostring (arg [0]) .. " <json file>")
  os.exit (1)
end
local name = string.gsub (arg [1], ".json", "")

local json = require "dkjson"

local key_list = {}
local key_set  = {}
local str_size = 0

local data = (function ()
  local file = io.open (name .. ".json", "r")
  local text = file:read ("*all")
  local data = json.decode (text)
  file:close ()
  return data
end) ()

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
    for i = #x, list_size do
      x [i] = json.null
    end
    return result
  end
end

local function canonize (x)
  if is_value (x) then
    if type (x) == "string" then
      str_size = math.max (str_size, #x)
    end
    return prefix
  elseif is_map (x) then
    for k, v in pairs (x) do
      key_set [k] = true
      canonize (v)
    end
  elseif is_list (x) then
    for i, v in ipairs (x) do
      canonize (v)
    end
    for i = #x + 1, list_size do
      x [i] = json.null
    end
  end
end

local state = {
  indent   = true,
  level    = 0,
  keyorder = key_list,
}

canonize (data)
print ("Max word size: " .. tostring (str_size))

do
  local result = order (data [1])
  for k in pairs (key_set) do
    key_list [#key_list + 1] = k
  end
  table.sort (key_list)
  local file = io.open (name .. ".order.json", "w")
  local text = json.encode (result, state)
  file:write (text)
  file:close ()
  print ("Generated order in " .. name .. ".order.json.")
end

do
  for i, v in ipairs (data) do
    if v == json.null then
      data [i] = nil
    end
  end
  local file = io.open (name .. ".json", "w")
  local text = json.encode (data, state)
  file:write (text)
  file:close ()
  print ("Canonized data in " .. name .. ".json.")
end
