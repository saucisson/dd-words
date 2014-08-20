#! /usr/bin/env lua

if #arg ~= 1 then
  print (tostring (arg [0]) .. " <json file>")
  os.exit (1)
end
local name = string.gsub (arg [1], ".json", "")

local json = require "dkjson"

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

local key_set  = {}
local key_list = {}

local function extract_keys (x)
  if is_map (x) then
    for k, v in pairs (x) do
      key_set [k] = true
      extract_keys (v)
    end
  elseif is_list (x) then
    for i, v in ipairs (x) do
      extract_keys (v)
    end
  end
end

extract_keys (data)
for k in pairs (key_set) do
  key_list [#key_list + 1] = k
end
table.sort (key_list)

local state = {
  indent   = false,
  keyorder = key_list,
}

local unicity_table = {}
local id = 1

local function unify (x)
  local key
  if is_value (x) then
    return x
  elseif is_map (x) then
    local r = {}
    for k, v in pairs (x) do
      r [k] = unify (v)
    end
    key = json.encode (r)
  elseif is_list (x) then
    local r = {}
    for i, v in ipairs (x) do
      r [i] = unify (v)
    end
    key = json.encode (r)
  end
  if not unicity_table [key] then
    unicity_table [key] = id
    id = id + 1
  end
  return unicity_table [key]
end

local function count (x)
  if is_value (x) then
    return 0
  elseif is_map (x) then
    local result = 1
    for _, v in pairs (x) do
      result = result + count (v)
    end
    return result
  elseif is_list (x) then
    local result = 1
    for _, v in ipairs (x) do
      result = result + count (v)
    end
    return result
  end
end

local function size ()
  local result = 0
  for _ in pairs (unicity_table) do
    result = result + 1
  end
  return result
end

unify (data)
print ("# Nodes: " .. tostring (size ()) .. " / " .. tostring (count (data)))
