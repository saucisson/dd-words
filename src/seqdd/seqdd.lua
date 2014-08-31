-- Unicity Tables
-- --------------
--
-- * `nodes` is a mapping from identifiers to nodes
-- * `identifiers` is a mapping from hashes to identifiers
--
-- Identifiers are  to allow to use the garbage collector:
--
-- * proxies refer to identifiers (keys of `nodes`),
-- * nodes contain other identifiers (keys of `nodes`),
-- * hashes only exist as long as their node exists (`hashes`).

local function count (t)
  local result = 0
  for _ in pairs (t) do
    result = result + 1
  end
  return result
end

local function name (x)
  return function ()
    return x
  end
end

local Nodes  = setmetatable ({}, { __tostring = name "Nodes" })
Nodes.__mode = "k"
Nodes.__len = count

local Hashes = setmetatable ({}, { __tostring = name "Hashes" })
Hashes.__mode = "v"
Hashes.__len = count

local UP = setmetatable ({}, { __tostring = name "UP" })
UP.__mode   = "kv"
UP.__len = count

local nodes  = setmetatable ({}, Nodes )
local hashes = setmetatable ({}, Hashes)

local ID     = setmetatable ({}, { __tostring = name "ID" })
local PREFIX = setmetatable ({}, { __tostring = name "PREFIX" })

local Identifier  = setmetatable ({}, { __tostring = name "Identifier" })
Identifier.__mode = "k"
Identifier.__len  = count

local Proxy       = setmetatable ({}, { __tostring = name "Proxy" })
local Node        = setmetatable ({}, { __tostring = name "Node" })

-- Identifier
-- ----------

function Identifier:new ()
  return setmetatable ({}, Identifier)
end

function Identifier:__tostring ()
  setmetatable (self, nil)
  local result = "@" .. tostring (self) : sub (10) ..
        " #" .. tostring (#self)
  setmetatable (self, Identifier)
  return result
end

-- Proxy
-- -----

function Proxy:new (id)
  assert (getmetatable (id) == Identifier)
  local result = setmetatable ({
    [ID    ] = id,
    [PREFIX] = ""
  }, Proxy)
  id [result] = true
  return result
end

function Proxy:arcs (proxy, sorted)
  assert (getmetatable (proxy) == Proxy)
  assert (sorted == nil or type (sorted) == "boolean")
  local node = nodes [proxy [ID]]
  local f = coroutine.wrap (
    function ()
      for e, s in Node:arcs (node, sorted) do
        coroutine.yield (e, Proxy:new (s))
      end
    end
  )
  return f
end

function Proxy:__index (key)
  assert (type (key) == "string")
  local id     = self [ID]
  local prefix = self [PREFIX] .. key
  -- Follow the arc contained in the prefix:
  for e, s in Proxy:arcs (self) do
    if prefix == e then
      return s
    elseif prefix:find (e, 1, true) == 1 then
      -- e <= prefix
      return s [prefix:sub(#e+1)]
    elseif e:find (prefix, 1, true) == 1 then
      -- prefix <= e
      local result = Proxy:new (id)
      result [PREFIX] = prefix
      return result
    end
  end
end

function Proxy:__len ()
  local node = nodes [self [ID]]
  return #node
end

function Proxy:__tostring ()
  return tostring (self [ID]) .. " [" .. self [PREFIX] .. "]"
end

function Proxy:__gc ()
  local id = self [ID]
  id [self] = nil
  if #id <= 1 then
    for n in pairs (id) do
      if getmetatable (n) == Node then
        Node:reduce (n)
      end
    end
  end
end

-- Show a proxy:

local function pad (x, size)
  x = tostring (x)
  for _ = #x+1, size do
    x = x .. " "
  end
  return x
end

function Proxy:show (proxy, shown)
  shown = shown or {}
  local id = proxy [ID]
  if shown [id] then
    return
  end
  shown [id] = true
  print (tostring (proxy) .. ":")
  local size = 0
  for e, _ in Proxy:arcs (proxy) do
    size = math.max (size, #e)
  end
  for e, s in Proxy:arcs (proxy, true) do
    print ("  " .. pad (e, size) .. " -> " .. tostring (s))
  end
  for _, s in Proxy:arcs (proxy, true) do
    Proxy:show (s, shown)
  end
end

-- Node
-- ----

function Node:new (x)
  assert (getmetatable (x) == nil)
  local result = {}
  for k, v in pairs (x) do
    if getmetatable (v) == Proxy then
      v = v [ID]
    end
    assert (type (k) == "string")
    assert (getmetatable (v) == Identifier)
    result [k] = v
  end
  return setmetatable (result, Node)
end

function Node:arcs (node, sorted)
  assert (getmetatable (node) == Node)
  assert (sorted == nil or type (sorted) == "boolean")
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

function Node:unique (x, to)
  local node = Node:new (x)
  assert (getmetatable (node) == Node)
  assert (to == nil or getmetatable (to) == Identifier)
  local elements = {}
  for e, s in Node:arcs (node, true) do
    elements [#elements + 1] = e .. ":" .. tostring (s)
  end
  local hash = table.concat (elements, ";")
  local id   = hashes [hash]
  if not id then
    id = to or Identifier:new ()
    nodes  [id  ] = node
    hashes [hash] = id
    node   [ID  ] = id
    for _, s in Node:arcs (node) do
      s [node] = true
    end
  end
  return Proxy:new (id)
end

function Node:reduce (node)
  -- Pattern: an arc followed by a node with only one arc, and no other
  -- references.
  assert (getmetatable (node) == Node)
  local id   = node [ID]
  local replacement = {}
  local replace     = false
  for e, s in Node:arcs (node) do
    if type (e) == "string" then
      local node_refs  = 0
      local proxy_refs = 0
      for k in pairs (s) do
        if getmetatable (k) == Node then
          node_refs = node_refs + 1
        elseif getmetatable (k) == Proxy then
          proxy_refs = proxy_refs + 1
        end
      end
      local successor = nodes [s]
      if proxy_refs == 0 and node_refs == 1 and #successor == 1 then
        replace = true
        for es, ss in Node:arcs (successor) do
          replacement [e .. es] = ss
        end
      end
    end
  end
  if replace then
    Node:unique (replacement, id)
  end
end

local terminal = Node:unique {}

function Node:canonize (word)
  assert (type (word) == "string")
  local function split (word, to)
    for node in pairs (to [ID]) do
      if getmetatable (node) == Node then
        for rhs, s in Node:arcs (node) do
          for j = math.min (#word, #rhs)-1, 0, -1 do
            if word:sub (#word-j) == rhs:sub (#rhs-j) then
              to   = Node:unique { [word:sub (#word-j)] = to }
              word = word:sub (1, #word-j-1)
              local old_node = {}
              for k, v in Node:arcs (node) do
                old_node [k] = v
                v [node] = nil
              end
              old_node [rhs] = nil
              old_node [rhs:sub (1, #rhs-j-1)] = to
              Node:unique (old_node, node [ID])
              return word, to
            end
          end
        end
      end
    end
    return word, Node:unique { [word] = to }
  end
  local result  = terminal
  local current = word
  while true do
    current, result = split (word, result)
    if current == word then
      return result
    else
      word = current
    end
  end
end

function Node:__len ()
  local result = 0
  for _ in Node:arcs (self) do
    result = result + 1
  end
  return result
end

function Node:__gc ()
  for _, s in Node:arcs (self) do
    s [self] = nil
    if #s <= 1 then
      for n in pairs (s) do
        if getmetatable (n) == Node then
          Node:reduce (n)
        end
      end
    end
  end
end

function Node:__tostring ()
  return tostring (self [ID])
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

return {
  Proxy       = Proxy,
  Node        = Node,
  Identifier  = Identifier,
  nodes       = nodes,
  ID          = ID,
}
