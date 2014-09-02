#! /usr/bin/env luajit

if #arg < 1 then
  print (arg [0] .. "<threshold>")
  os.exit (1)
end

local threshold = tonumber (arg [1])

local seqdd = require "seqdd"
local Proxy = seqdd.Proxy

local size_characters = 10

local function pad (str)
  str = tostring (str)
  local result = str
  for _ = 1, size_characters - #str do
    result = " " .. result
  end
  return result
end

local result = nil
local inserted = 0
local total    = 0
io.write ("\27[s")
while true do
  local line = io.read ()
  if total % 100 == 0 then
    io.write ("\27[u")
    io.write (pad (inserted) .. " / " .. pad (total))
    io.flush ()
  end
  if not line then
    break
  end
  if #line <= threshold then
--    print (line)
    local dd = Proxy:word (line)
    if not result then
      result = dd
    else
      result = result + dd
    end
    inserted = inserted + 1
--    Proxy:show { result = result }
  end
  total = total + 1
end
print ""
--Proxy:show { result = result }
