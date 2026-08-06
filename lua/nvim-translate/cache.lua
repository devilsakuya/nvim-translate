local M = {}

local store = {} -- key -> { value = string, order = number }
local order_counter = 0
local size = 0
local max_size = 100

function M.setup(capacity)
  max_size = capacity or 100
  store = {}
  order_counter = 0
  size = 0
end

function M.get(key)
  local entry = store[key]
  if not entry then
    return nil
  end
  order_counter = order_counter + 1
  entry.order = order_counter -- mark as recently used
  return entry.value
end

function M.set(key, value)
  if store[key] then
    store[key].value = value
    order_counter = order_counter + 1
    store[key].order = order_counter
    return
  end

  if size >= max_size then
    -- evict least recently used entry
    local oldest_key, oldest_order = nil, math.huge
    for k, v in pairs(store) do
      if v.order < oldest_order then
        oldest_order = v.order
        oldest_key = k
      end
    end
    if oldest_key then
      store[oldest_key] = nil
      size = size - 1
    end
  end

  order_counter = order_counter + 1
  store[key] = { value = value, order = order_counter }
  size = size + 1
end

function M.clear()
  store = {}
  order_counter = 0
  size = 0
end

return M
