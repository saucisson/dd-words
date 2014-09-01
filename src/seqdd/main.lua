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

local id
local sequence
local result

print ("Extracting sequences...")
local i = 0
io.write ("\27[s")
while true do
  local line = io.read ()
  if i % 1000 == 0 then
    io.write ("\27[u")
    io.write (pad (i))
    io.flush ()
  end
  if not line then
    line = ">"
  end
  local first = line:sub (1, 1)
  if first == ">" and id then
    i = i + 1
    if #sequence <= threshold then
      print (sequence)
      local dd = Proxy:word (sequence)
      if not result then
        result = dd
      else
        result = result + dd
      end
    end
    id = nil
    sequence = nil
  end
  if line == ">" then
    break
  elseif sequence then
    sequence = sequence .. line
  else
    id = line:match ("|(%d+)|")
    sequence = ""
  end
end
i = i + 1
--io.write ("\27[u")
--io.write (pad (i) .. " / " .. pad (size))
print ""
