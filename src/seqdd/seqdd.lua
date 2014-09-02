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

local has__gc
do
  local t = setmetatable ({}, {
    __gc = function () has__gc = true end
  })
  t = nil
  collectgarbage ()
  if not has__gc then
    print "No __gc support detected."
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
local terminal

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
  local _ = self
  return setmetatable ({}, Identifier)
end

function Identifier:parents (id)
  local _ = self
  assert (getmetatable (id) == Identifier)
  local f = coroutine.wrap (
    function ()
      for p in pairs (id) do
        if getmetatable (p) == Node then
          coroutine.yield (Proxy:new (p [ID]))
        end
      end
    end
  )
  return f
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
  local _ = self
  assert (getmetatable (id) == Identifier)
  local result = setmetatable ({
    [ID    ] = id,
    [PREFIX] = ""
  }, Proxy)
  id [result] = true
  return result
end

function Proxy:arcs (proxy, sorted)
  local _ = self
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

function Proxy:arc (proxy)
  local _ = self
  assert (getmetatable (proxy) == Proxy)
  assert (#proxy == 1)
  local node = nodes [proxy [ID]]
  local e, s = Node:arc (node)
  return e, Proxy:new (s)
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

function Proxy:word (word)
  local _ = self
  assert (type (word) == "string")
  local function split (word, to)
    for parent in Identifier:parents (to [ID]) do
      if #parent == 1 then
        local rhs, _ = Proxy:arc (parent)
        if word == rhs then
          return "", Node:unique { [word] = to }
        end
        local suffix_size = 0
        for j = 1, math.min (#word, #rhs) do
          if word:sub (-j) == rhs:sub (-j) then
            suffix_size = j
          else
            break
          end
        end
        if suffix_size > 0 then
          local suffix = word:sub (-suffix_size)
          to = Node:unique { [suffix] = to }
          if #rhs ~= suffix_size then
            local old_node = {
              [rhs:sub (1, #rhs-suffix_size)] = to
            }
            Node:unique (old_node, parent [ID])
          end
          return word:sub (1, #word-suffix_size), to
        end
      end
    end
    return "", Node:unique { [word] = to }
  end
  local result  = terminal
  local current = word .. "#"
  while true do
    if current == "" then
      return result
    end
    current, result = split (current, result)
  end
end

function Proxy:__eq (rhs)
  local lhs = self
  return lhs [ID]     == rhs [ID]
     and lhs [PREFIX] == rhs [PREFIX]
end

function Proxy:__add (rhs)
  return Proxy:union (self, rhs)
end

function Proxy:__len ()
  local node = nodes [self [ID]]
  return #node
end

function Proxy:__tostring ()
  return tostring (self [ID]) .. " [" .. self [PREFIX] .. "]"
end

--[[
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
--]]

-- Show a proxy:

local function pad (x, size)
  x = tostring (x)
  for _ = #x+1, size do
    x = x .. " "
  end
  return x
end

function Proxy:show (proxies, shown)
  local _ = self
  shown = shown or {}
  local referenced = {}
  for k, proxy in pairs (proxies) do
    local id = proxy [ID]
    if not shown [id] then
      shown [id] = true
      if type (k) == "string" then
        print (tostring (k) .. " = " .. tostring (proxy) .. ":")
      else
        print (tostring (proxy) .. ":")
      end
      local size = 0
      for e, _ in Proxy:arcs (proxy) do
        size = math.max (size, #e)
      end
      for e, s in Proxy:arcs (proxy, true) do
        print ("  " .. pad (e, size) .. " -> " .. tostring (s))
        referenced [#referenced + 1] = s
      end
    end
--    for k in pairs (id) do
--      if getmetatable (k) == Node then
--        print ("  <- " .. tostring (k))
--      end
--    end
  end
  if #referenced ~= 0 then
    Proxy:show (referenced, shown)
  end
end

-- Node
-- ----

function Node:new (x)
  local _ = self
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
  local _ = self
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

function Node:arc (node)
  local _ = self
  assert (getmetatable (node) == Node)
  assert (#node == 1)
  for k, v in pairs (node) do
    if type (k) == "string" then
      return k, v
    end
  end
end

function Node:unique (x, to)
  local _ = self
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
  local _ = self
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

local function split (lhs, rhs)
  assert (getmetatable (lhs) == Proxy)
  assert (getmetatable (rhs) == Proxy)
  local result = {}
  local l = {}
  local r = {}
  for el, sl in Proxy:arcs (lhs, true) do
    l [el] = sl
  end
  for er, sr in Proxy:arcs (rhs, true) do
    r [er] = sr
  end
  for el, sl in pairs (l) do
    local found = false
    for er, sr in pairs (r) do
      if el == er then
        result [#result + 1] = {
          prefix = el,
          el     = "",
          er     = "",
          sl     = sl,
          sr     = sr,
        }
        l [el] = nil
        r [er] = nil
        found = true
        break
      else
        local prefix = ""
        for i=1, math.min (#el, #er) do
          if el:sub (1, i) == er:sub (1, i) then
            prefix = el:sub (1, i)
          else
            break
          end
        end
        if prefix ~= "" then
          result [#result + 1] = {
            prefix = prefix,
            el = el:sub (#prefix + 1),
            er = er:sub (#prefix + 1),
            sl = sl,
            sr = sr,
          }
          l [el] = nil
          r [er] = nil
          found = true
          break
        end
      end
    end
    if not found then
      result [#result + 1] = {
        e = el,
        s = sl,
      }
      l [el] = nil
    end
  end
  for er, sr in pairs (r) do
    result [#result + 1] = {
      e = er,
      s = sr,
    }
  end
  return result
end

function Proxy:union (lhs, rhs)
  local _ = self
--  Proxy:show { lhs = lhs, rhs = rhs }
  assert (getmetatable (lhs) == Proxy)
  assert (getmetatable (rhs) == Proxy)
  if lhs == rhs then
    return lhs
  end
  local splitted = split (lhs, rhs)
  local result = {}
  for _, x in ipairs (splitted) do
--    for k, v in pairs (x) do
--      print ("  " .. tostring (k) .. " => " .. tostring (v))
--    end
    if x.prefix then
      if x.el == "" and x.er == "" then
        result [x.prefix] = Proxy:union (x.sl, x.sr)
      elseif x.el == "" then
        result [x.prefix] = Proxy:union (
          x.sl,
          Node:unique {
            [x.er] = x.sr
          }
        )
      elseif x.er == "" then
        result [x.prefix] = Proxy:union (
          Node:unique {
            [x.el] = x.sl
          },
          x.sr
        )
      else
        result [x.prefix] = Node:unique {
          [x.el] = x.sl,
          [x.er] = x.sr,
        }
      end
    else
      result [x.e] = x.s
    end
  end
  return Node:unique (result)
end

function Node:__len ()
  local result = 0
  for _ in Node:arcs (self) do
    result = result + 1
  end
  return result
end

--[[
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
--]]

function Node:__tostring ()
  return tostring (self [ID])
end

terminal = Node:unique {}

return {
  Proxy       = Proxy,
  Node        = Node,
  Identifier  = Identifier,
  nodes       = nodes,
  ID          = ID,
}
