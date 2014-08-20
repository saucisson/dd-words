#! /usr/bin/env lua

if #arg ~= 1 then
  print (tostring (arg [0]) .. " <json file>")
  os.exit (1)
end
local name = string.gsub (arg [1], ".json", "")

local json = require "dkjson"

local key_list = {}
local key_set  = {}
local list_size   = 0
local string_size = 0

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
    if type (x) == "string" then
      local result = {}
      for i = 1, string_size do
        result [#result + 1] = prefix .. "/" .. tostring (i)
      end
      return result
    else
      return prefix
    end
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

local function canonize (x)
  if is_value (x) then
    if type (x) == "string" then
      string_size = math.max (string_size, #x)
    end
  elseif is_map (x) then
    for k, v in pairs (x) do
      key_set [k] = true
      x [k] = canonize (v)
    end
  elseif is_list (x) then
    if x ~= data then
      list_size = math.max (list_size, #x)
    end
    for i, v in ipairs (x) do
      x [i] = canonize (v)
    end
  end
  return x
end

local function pad (x)
  if is_value (x) and type (x) == "string" then
    local result = x
    for i = #x + 1, string_size do
      result = result .. " "
    end
    return result
  elseif is_map (x) then
    for k, v in pairs (x) do
      x [k] = pad (v)
    end
  elseif is_list (x) then
    for i, v in ipairs (x) do
      x [i] = pad (v)
    end
    for i = #x + 1, list_size do
      x [i] = json.null
    end
  end
  return x
end

local state = {
  indent   = true,
  level    = 0,
  keyorder = key_list,
}

data = canonize (data)
print ("Max list size: " .. tostring (list_size))
print ("Max string size: " .. tostring (string_size))
data = pad (data)

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
