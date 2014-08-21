#! /usr/bin/env luajit

if #arg < 2 then
  print (arg [0] .. "<threshold> <input-file> <output-file>")
end

local threshold = tonumber (arg [1])
local input     = arg [2]
local output    = arg [3]

local size = 0
for line in io.lines (input) do
  local first = line:sub (1, 1)
  if first == ">" then
    size = size + 1
  end
end
local size_characters = math.ceil (math.log10 (size))

local function pad (str)
  str = tostring (str)
  local result = str
  for i = 1, size_characters - #str do
    result = " " .. result
  end
  return result
end

local id = nil
local sequence = nil

print ("Extracting sequences...")
local i = 0
io.write ("\27[s")
local file = io.open (output, "w")
for line in io.lines (input) do
  if i % 1000 == 0 then
    io.write ("\27[u")
    io.write (pad (i) .. " / " .. pad (size))
    io.flush ()
  end
  local first = line:sub (1, 1)
  if first == ">" and id then
    i = i + 1
    if #sequence <= threshold then
      file:write (sequence .. "\n")
    end
    id = nil
    sequence = nil
  end
  if sequence then
    sequence = sequence .. line
  else
    id = line:match ("|(%d+)|")
    sequence = ""
  end
end
if #sequence <= threshold then
  file:write (sequence .. "\n")
end
i = i + 1
io.write ("\27[u")
io.write (pad (i) .. " / " .. pad (size))
file:close ()
print ""
