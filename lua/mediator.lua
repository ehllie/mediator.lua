local utils = require("mediator.utils")

local conflict_start = "^<<<<<<<"
local conflict_base = "^|||||||"
local conflict_middle = "^======="
local conflict_end = "^>>>>>>>"

---@alias Conflict {cstart: number, cbase: number?, cmiddle: number, cend: number}

---@alias Config {find_unmerged: fun(bufn: number): string[]}

---@alias Section
---| "ours"
---| "theirs"
---| "base"

---@param bufn number
---@return string[]
local function git_diff_unmerged(bufn) end

---@param iter fun() : (number, string) | nil
---@return Conflict | nil
local function next_conflict(iter)
  ---@type Conflict
  local ret = {}
  for index, line in iter do
    local lnum = index - 1
    if line:match(conflict_start) then
      ret.cstart = lnum
    elseif line:match(conflict_base) then
      ret.cbase = lnum
    elseif line:match(conflict_middle) then
      ret.cmiddle = lnum
    elseif line:match(conflict_end) then
      ret.cend = lnum
      return ret
    end
  end
  return nil
end

---@param bufn number
---@return Conflict[]
local function get_conflicts(bufn)
  local lines = utils.iter(vim.api.nvim_buf_get_lines(bufn, 0, -1, false))
  ---@type Conflict[]
  local ret = {}
  local next = nil
  repeat
    next = next_conflict(lines)
    if next then table.insert(ret, next) end
  until not next
  return ret
end

---@param bufn number
---@return {conflict: Conflict, section?: Section}?
local function locate_cursor(bufn)
  bufn = bufn or 0
  local row, _ = unpack(vim.api.nvim_win_get_cursor(bufn))
  -- Offset by 1 because conflict locations are 0-indexed
  row = row - 1
  for _, conflict in ipairs(get_conflicts(bufn)) do
    if conflict.cstart <= row and row <= conflict.cend then
      if conflict.cstart < row and row < conflict.cend then
        if row < conflict.cmiddle then
          local section = conflict.cbase and conflict.cbase < row and "base" or "ours"
          return { conflict = conflict, section = section }
        elseif conflict.cmiddle < row then
          return { conflict = conflict, section = "theirs" }
        end
      end
      return { conflict = conflict, section = nil }
    end
  end
end

---@param conflict Conflict
---@param section Section
---@return string[]
local function conflict_content(conflict, section)
  local function getbuf(start, _end) return vim.api.nvim_buf_get_lines(0, start, _end, true) end

  if section == "ours" then
    return getbuf(conflict.cstart + 1, conflict.cbase or conflict.cmiddle)
  elseif section == "theirs" then
    return getbuf(conflict.cmiddle + 1, conflict.cend)
  else
    return getbuf(conflict.cbase + 1, conflict.cmiddle)
  end
end

local default_config = {
  find_unmerged = git_diff_unmerged,
}

local M = {}

---@param section? Section
function M.resolve(section)
  local loc = locate_cursor(0)
  if loc then
    if section == "base" and not loc.conflict.cbase then return end
    section = section or loc.section
    if section then
      local content = conflict_content(loc.conflict, section)
      vim.api.nvim_buf_set_lines(0, loc.conflict.cstart, loc.conflict.cend + 1, true, content)
    end
  end
end

---@param config Config
function M.setup(config)
  local cmd = vim.api.nvim_create_user_command
  cmd("ResolveOurs", function() M.resolve("ours") end)
  cmd("ResolveTheirs", function() M.resolve("theirs") end)
  cmd("ResolveBase", function() M.resolve("base") end)
end

return M
