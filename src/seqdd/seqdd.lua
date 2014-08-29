local __TEST__ = true

-- Unicity Tables
-- --------------
--
-- * `nodes` is a mapping from identifiers to nodes
-- * `identifiers` is a mapping from hashes to identifiers
--
-- Identifiers are tables, to allow to use the garbage collector:
--
-- * proxies refer to identifiers (keys of `nodes`),
-- * nodes contain other identifiers (keys of `nodes`),
-- * hashes only exist as long as their node exists (`hashes`).

local tables = {
  nodes  = setmetatable ({}, { __mode = "k" }),
  hashes = setmetatable ({}, { __mode = "v" }),
}

local function count (t)
  local result = 0
  for _ in pairs (t) do
    result = result + 1
  end
  return result
end

local UP = {}

-- All Types
-- ---------

local Identifier  = {}
local Proxy       = {}
local Up          = {}
local Node        = {}

-- Identifier
-- ----------

function Identifier:new ()
  return setmetatable ({}, Identifier)
end

function Identifier:__tostring ()
  setmetatable (self, nil)
  local result = "@" .. tostring (self) : sub (10)
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
  assert (type (x) == "table" and
    (getmetatable (x) == Proxy or getmetatable (x) == Node))
  assert (sorted == nil or type (sorted) == "boolean")
  local node
  if getmetatable (x) == Proxy then
    node = tables.nodes [x [ID]]
  else
    node = x
  end
  local f = coroutine.wrap (
    function ()
      if sorted then
        local keys = {}
        for e, _ in pairs (node) do
          if type (e) == "string" then
            keys [#keys + 1] = e
          end
        end
        table.sort (keys)
        for _, k in ipairs (keys) do
          local v = node [k]
          coroutine.yield (k, v)
        end
      else
        for k, v in pairs (node) do
          if type (k) == "string" then
            coroutine.yield (k,  v)
          end
        end
      end
    end
  )
  return f
end

function Proxy:new (id)
  assert (type (id) == "table" and getmetatable (id) == Identifier)
  return setmetatable ({ [ID] = id }, Proxy)
end

function Proxy:__index (key)
  assert (type (key) == "string")
  local node   = tables.nodes [rawget (self, ID)]
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
  do
    local id1 = Identifier:new ()
    print ("id1 = " .. tostring (id1))
    local id2 = Identifier:new ()
    print ("id2 = " .. tostring (id2))
    tables.nodes [id1] = setmetatable ({}, Node)
    tables.nodes [id2] = setmetatable ({ ["abcde"] = id1 }, Node)
    local p0 = Proxy:new (id2)
    print ("p0 = " .. tostring (p0))
    local p1 = p0 ["abcd"]
    print ("p1 = " .. tostring (p1))
    local p2 = p1 ["e"]
    print ("p2 = " .. tostring (p2))
    local p3 = p2 ["f"]
    print ("p3 = " .. tostring (p3))
  end
  collectgarbage ()
  print (count (tables.nodes))
end

-- References
-- ----------

Up.__mode = "kv"

function Up:new ()
  return setmetatable ({}, Up)
end

-- Node
-- ----

function Node:new (x)
  assert (not x or (type (x) == "table" and not getmetatable (x)))
  local result = {}
  if x then
    for k, v in pairs (x) do
      result [k] = v
    end
  end
  return setmetatable (result, Node)
end

function Node:unique (node, to_id)
  if not getmetatable (node) then
    node = Node:new (node)
  end
  to_id = to_id and to_id [ID] or to_id
  local elements = {}
  for e, s in arcs (node, true) do
    node [e] = s [ID] or s
    elements [#elements + 1] = e .. ":" .. tostring (s)
  end
  local hash = table.concat (elements, ";")
  local id   = tables.hashes [hash]
  if not id then
    id = to_id or Identifier:new ()
    tables.nodes  [id  ] = node
    tables.hashes [hash] = id
    node [UP] = Up:new ()
    for e, s in arcs (node) do
      tables.nodes [s] [UP] [id] = true
    end
  end
  return Proxy:new (id)
end

if __TEST__ then
  do
    local p1 = Node:unique {}
    print ("p1 = " .. tostring (p1))
    local p2 = Node:unique { ["abcde"] = p1 }
    print ("p2 = " .. tostring (p2))
    local p3 = Node:unique { ["abcde"] = p1, ["z"] = p1 }
    print ("p3 = " .. tostring (p3))
    local p4 = Node:unique ({ ["y"] = p1 }, p3)
    print ("p4 = " .. tostring (p4))
    print ("p3 = " .. tostring (p3))
  end
  collectgarbage ()
  print (count (tables.nodes))
  print (count (tables.hashes))
end

function Node:__gc ()
  -- If the node is suppressed, all references to it have disappeared.
  -- Re canonize successors.
  for _, s in arcs (self) do
    -- TODO: recanonize successor
  end
end

-- Show a proxy:

local function pad (x, size)
  x = tostring (x)
  for i = #x+1, size do
    x = x .. " "
  end
  return x
end

local function show (proxy, shown)
  shown = shown or {}
  local id = proxy [ID]
  if shown [id] then
    return
  end
  shown [id] = true
  print (tostring (id) .. ":")
  local size = 0
  for e, _ in arcs (proxy) do
    size = math.max (size, #e)
  end
  for e, s in arcs (proxy, true) do
    print ("  " .. pad (e, size) .. " -> " .. tostring (s))
  end
  for _, s in arcs (proxy, true) do
    show (Proxy:new (s), shown)
  end
end

if __TEST__ then
  do
    local p1 = Node:unique {}
    local p2 = Node:unique { ["abcde"] = p1 }
    local p3 = Node:unique { ["abcde"] = p1, ["z"] = p1 }
    show (p3)
  end
end

--[[
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
