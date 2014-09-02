local assert = require "luassert"
local seqdd  = require "seqdd"

local Node        = seqdd.Node
local Identifier  = seqdd.Identifier
local Proxy       = seqdd.Proxy
local nodes       = seqdd.nodes
local ID          = seqdd.ID

--[[
do
  assert.has.no.error (function () return Identifier:new () end)
end

do
  do
    local p1 = Node:unique {}
    local p2 = Node:unique { ["abcde"] = p1 }
    local p3 = Node:unique { ["abcde"] = p1, ["z"] = p1 }
    local p4 = Node:unique ({ ["y"] = p1 }, p3 [ID])
    assert (#nodes == 3)
    for _ = 1, 3 do
      collectgarbage ()
    end
    assert (#nodes == 3)
  end
  for _ = 1, 3 do
    collectgarbage ()
  end
  assert (#nodes == 1)
end

do
  local p
  do
    local p1 = Node:unique {}
    local p2 = Node:unique { ["a"] = p1 }
    local p3 = Node:unique { ["b"] = p2 }
    p = p3
    assert (#nodes == 3)
  end
  do
    for _ = 1, 3 do
      collectgarbage ()
    end
    assert (#nodes == 2)
  end
  p = nil
  for _ = 1, 3 do
    collectgarbage ()
  end
  assert (#nodes == 1)
end
--]]

do
  local x = Proxy:word "ah" + Proxy:word "an" + Proxy:word "as"
  Proxy:show { x = x }
end

--[[
do
  local p = Proxy:word "abcde"
  local q = Proxy:word "abfde"
end

do
  local x = Proxy:word ""
  x = x + Proxy:word "abcde"
  x = x + Proxy:word "abfde"
  x = x + Proxy:word "abde"
  x = x + Proxy:word "dz"
  Proxy:show { x = x }
end
--]]
