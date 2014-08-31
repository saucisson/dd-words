local assert = require "luassert"
local seqdd  = require "seqdd"

local Node        = seqdd.Node
local Identifier  = seqdd.Identifier
local Proxy       = seqdd.Proxy
local nodes       = seqdd.nodes

do
  assert.has.no.error (function () return Identifier:new () end)
end

do
  do
    local p1 = Proxy:unique {}
    local p2 = Proxy:unique { ["abcde"] = p1 }
    local p3 = Proxy:unique { ["abcde"] = p1, ["z"] = p1 }
    local p4 = Proxy:unique ({ ["y"] = p1 }, p3)
    assert (#nodes == 3)
    for _ = 1, 3 do
      collectgarbage ()
    end
    assert (#nodes == 3)
  end
  for _ = 1, 3 do
    collectgarbage ()
  end
  assert (#nodes == 0)
end

do
  local p
  do
    local p1 = Proxy:unique {}
    local p2 = Proxy:unique { ["a"] = p1 }
    local p3 = Proxy:unique { ["b"] = p2 }
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
  assert (#nodes == 0)
end
