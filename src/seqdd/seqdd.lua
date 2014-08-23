local function unique (x)
  return x
end

-- Must maintain bidirectional links
-- Each node is a list of predecessors and a list of successors.
-- We lose the functional aspect?

local predecessors_mt = {
  __mode = "kv"
}

local function empty ()
  return {
    predecessors = setmetatable ({}, predecessors_mt),
    successors   = {},
  }
end

local function show (node, shown)
  shown = shown or {}
  if shown [node] then
    return
  end
  shown [node] = true
  print (tostring (node) .. ":")
  for e, s in pairs (node.successors) do
    print ("  " .. e .. " -> " .. tostring (s))
  end
  for e, s in pairs (node.predecessors) do
    print ("  " .. e .. " <- " .. tostring (s))
  end
  for _, s in pairs (node.successors) do
    show (s, shown)
  end
end

local function id (node)
  local result = {}
  local keys = {}
  for e, s in pairs (node.successors) do
    keys [#keys + 1] = e
  end
  table.sort (keys)
  for _, k in ipairs (keys) do
    result [#result + 1] =
      k .. ":" .. tostring (node.successors [k]):sub (8)
  end
  return table.concat (result, ";")
end

local terminal = empty ()

-- predecessors should be added in unique function
-- and removed in garbage

local function clone (node)
  local result = empty ()
  for e, s in pairs (node.successors) do
    result.successors [e] = s
  end
  return result
end

local unique_table = setmetatable ({}, { __mode = "kv" })

local function unique (node)
  local key = id (node)
  local found = unique_table [key]
  if found then
    return found
  else
    unique_table [key] = node
    for e, s in pairs (node.successors) do
      s.predecessors [e] = node
    end
    return node
  end
end

local function from_bot (self, k)
  assert (type (k) == "string")
  if k == "" then
    return "", self
  elseif self.predecessors [k] then
    return "", self.predecessors [k]
  end
  for e, p in pairs (self.predecessors) do
    local size = 0
    for i = 1, math.min (#e, #k) do
      if e:sub (-i, -i) ~= k:sub (-i, -i) then
        break
      else
        size = i
      end
    end
    if size ~= 0 then
      if size == #e then
        return from_bot (s, k:sub (1, -size -1))
      else
        local suffix = e:sub (-size, -1)
        local subnode = empty ()
        subnode.successors [suffix] = self
        subnode = unique (subnode)
        p.successors [e] = nil
        self.predecessors [e] = nil
        e = e:sub (1, -size -1)
        p.successors [e] = subnode
        unique (p) -- guaranteed to use the same node
        k = k:sub (1, -size -1)
        return from_bot (subnode, k)
      end
      assert (false)
      return unique (result)
    end
  end
  -- Otherwise:
  return k, self
end

local function from_top (self, k)
  assert (type (k) == "string")
  if self.successors [k] then
    return self
  end
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
        result [e] = from_top (self.successors [e], k:sub (size+1))
      else
        local prefix = e:sub (1, size)
        result.successors [e] = nil
        e = e:sub (size+1)
        local r = empty ()
        r.successors [e] = self.successors [e]
        result.successors [prefix] = from_top (r, k:sub (size+1))
      end
      return unique (result)
    end
  end
  -- Otherwise:
  local kr, r = from_bot (terminal, k:sub (2))
  local result = clone (self)
  result.successors [k:sub (1,1) .. kr] = r
  return unique (result)
end

local x = from_top (empty (), "abcd")
print ("x = ?")
show (x)

local y = from_top (x, "eed")
print ("x = ?")
show (x)
print ("y = ?")
show (y)

-- need recompacting sometimes
