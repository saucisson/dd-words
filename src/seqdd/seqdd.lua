local __TEST__ = true

-- Unicity Tables
-- --------------
--
-- * `nodes` is a mapping from identifiers to nodes
-- * `identifiers` is a mapping from hashes to identifiers
--
-- Identifiers are tables, to allow to use the garbage collector.

local tables = {
  nodes       = setmetatable ({}, { __mode = "k" }),
  identifiers = setmetatable ({}, { __mode = "v" }),
}

local UP = {}

-- Identifier
-- ----------
local Identifier = {}
Identifier.__index = Identifier
function Identifier:new ()
  return setmetatable ({}, Identifier)
end
function Identifier:__tostring ()
  setmetatable (self, nil)
  local result = tostring (self) : sub (10)
  setmetatable (self, Identifier)
  return result
end

if __TEST__ then
  local id = Identifier:new ()
  print (id)
end

-- Proxy
-- -----

local ID     = {}
local PREFIX = {}

-- Iterate over the contents of proxy or node.
local function arcs (x, sorted)
  local node = tables.nodes [x [ID]] or x
  local f = coroutine.wrap (
    function ()
      if sorted then
        local keys = {}
        for e, _ in pairs (node) do
          if type (e) ~= "table" then
            keys [#keys + 1] = e
          end
        end
        table.sort (keys)
        for _, k in ipairs (keys) do
          coroutine.yield (k, node [k])
        end
      else
        for k, v in pairs (node) do
          coroutine.yield (k, v)
        end
      end
    end
  )
  return f
end

local Proxy = {}
Proxy.__index = Proxy
function Proxy:new (id)
  return setmetatable ({ [ID] = id }, Proxy)
end
function Proxy:__index (key)
  local node   = tables.nodes [self [ID]]
  local prefix = (rawget (self, PREFIX) or "") .. key
  -- Follow the arc contained in the prefix:
  for e, s in arcs (node) do
    if prefix == e then
      return Proxy:new (s)
    elseif prefix:find (e, 1, true) == 1 then
      -- e <= prefix
      local result = Proxy:new (s)
      return result [prefix:sub(#e+1)]
    elseif e:find (prefix, 1, true) == 1 then
      -- prefix <= e
      local result = Proxy:new (self [ID])
      result [PREFIX] = prefix
      return result
    end
  end
end
function Proxy:__tostring ()
  local id     = rawget (self, ID)
  local prefix = rawget (self, PREFIX)
  return tostring (id) ..
         (prefix and " [" .. prefix .. "]" or "")
end

if __TEST__ then
  local id1 = Identifier:new ()
  print ("id1 = " .. tostring (id1))
  local id2 = Identifier:new ()
  print ("id2 = " .. tostring (id2))
  tables.nodes [id1] = {}
  tables.nodes [id2] = { ["abcde"] = id1 }
  local p0 = Proxy:new (id2)
  print ("p0 = " .. tostring (p0))
  local p1 = p0 ["abcd"]
  print ("p1 = " .. tostring (p1))
  local p2 = p1 ["e"]
  print ("p2 = " .. tostring (p2))
  local p3 = p2 ["f"]
  print ("p3 = " .. tostring (p3))
end

-- References
-- ----------
local Up = {
  __mode = "kv",
}

-- Node
-- ----
local Node = {
  __gc = function (self)
    -- If the node is suppressed, all references to it have disappeared.
    -- Re canonize successors.
    for _, s in arcs (self) do
      -- TODO: recanonize successor
    end
  end
}

--[[
-- Return a proxy from a node:
local function unique (node, to_id)
  local keys = {}
  for e, _ in pairs (node) do
    keys [#keys + 1] = e
  end
  table.sort (keys)
  local elements = {}
  for _, e in ipairs (keys) do
    elements [#elements + 1] = e .. ":" .. id (node [e])
  end
  local hash = table.concat (elements, ";")
  local nid  = uniques [hash]
  if not nid then
    nid = to_id or {}
    ids     [nid ] = node
    uniques [hash] = nid
    node [UP] = setmetatable ({}, up_mt)
    for e, s in arcs (node) do
      s = s [ID] or s
      node [e] = s
      ids [s] [UP] [nid] = true
    end
  end
  return setmetatable ({ [ID] = nid }, proxy_mt)
end

-- Show a proxy:
local function show (proxy, shown)
  shown = shown or {}
  local nid = proxy [ID]
  if shown [nid] then
    return
  end
  shown [nid] = true
  print (id (nid) .. ":")
  for e, s in arcs (proxy) do
    print ("  " .. e .. " -> " .. id (s))
  end
  for _, s in arcs (proxy) do
    show ({ [ID] = s }, shown)
  end
end

local one = unique {}
print ("one: " .. tostring (one))

local function canonize (word)
  assert (type (word) == "string")
  local result = one
  local nodes = {}
  print (word)
  for e in pairs (result [UP]) do
    print ("UP " .. tostring (e))
  end

  print ("Found " .. tostring (#nodes) .. " potential nodes.")
  
  local lhs = word
  for _, i in ipairs (nodes) do
    print ("i = " .. tostring (i))
    for rhs, s in arcs { [ID] = i } do
      print ("Comparing " .. lhs .. " with " .. rhs)
      for j = math.min (#lhs, #rhs)-1, 0, -1 do
        if lhs:sub (#lhs-j) == rhs:sub (#rhs-j) then
          print ("Match found: " .. lhs:sub (#lhs-j))
          result = unique { [lhs:sub (#lhs-j)] = result }
          word = lhs:sub (1, #lhs-j-1)
          local previous_node = ids [i]
          previous_node [rhs] = nil
          previous_node [rhs:sub (1, #rhs-j-1)] = s
          unique (previous_node, i)
        end
      end
    end
  end
  return unique { [word] = result }
end

local w1 = canonize "abcde"
show (w1)

local w2 = canonize "abcfe"
show (w1)
show (w2)
--]]
--[[
  for e in pairs (self.successors) do
    -- Is there an intersection between k and an edge?
    -- For instance: { abc } + abd
    local size = 0
    for i = 1, math.min (#e, #k) do
      if e:sub (i, i) ~= k:sub (i, i) then
        break
      else
        size = i
      end
    end
    if size ~= 0 then
      local result = clone (self)
      if size == #e then
        result [e] = canonize (self.successors [e], k:sub (size+1))
      else
        local prefix = e:sub (1, size)
        result.successors [e] = nil
        e = e:sub (size+1)
        local r = empty ()
        r.successors [e] = self.successors [e]
        result.successors [prefix] = canonize (r, k:sub (size+1))
      end
      return unique (result)
    end
  end
  -- Otherwise:
  -- TODO
  local kr, r = from_bot (terminal, k:sub (2))
  local result = clone (self)
  result.successors [k:sub (1,1) .. kr] = r
  return unique (result)
end

local x = canonize (empty (), "abcd")
print ("x = ?")
show (x)

local y = canonize (x, "eed")
print ("x = ?")
show (x)
print ("y = ?")
show (y)

-- need recompacting sometimes
--]]
