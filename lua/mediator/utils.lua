local M = {}
---@generic A
---@param tab {[integer]: A}
---@return fun(): integer, A
function M.iter(tab)
  local pos = 0
  return function()
    pos = pos + 1
    local v = tab[pos]
    return v and pos, v
  end
end

return M
