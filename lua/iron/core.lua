local fts = require("iron.fts")
local ll = require("iron.lowlevel")
local focus = require("iron.visibility").focus
local config = require("iron.config")
local marks = require("iron.marks")
local tables = require("iron.util.tables")

local core = {}

-- TODO Unify repl creation fns
core.repl_here = function(ft)
  -- first check if the repl for the current filetype already exists
  local mem = ll.get(ft)
  local exists = not (mem == nil or vim.fn.bufname(mem.bufnr) == "")

  if exists then
    vim.api.nvim_set_current_buf(mem.bufnr)
  else
    -- the repl does not exist, so we have to create a new one,
    -- but in the current window
    mem = ll.create_preferred_repl(ft, false)
  end

  return mem
end

-- TODO unify repl creation fns
core.repl_restart = function()
  -- First, check if the cursor is on top or a REPL
  -- Then, start a new REPL of the same type and enter it into the window
  -- Afterwards, wipe out the old REPL buffer
  -- This is done without asking for confirmation, so user beware
  local bufnr_here = vim.fn.bufnr("%")
  local ft_here = ll.get_repl_ft_for_bufnr(bufnr_here)
  local mem = nil

  if ft_here ~= nil then
    mem = ll.create_preferred_repl(ft_here, false)
    -- created a new one, now have to kill the old one
    vim.api.nvim_command('bwipeout! ' .. bufnr_here)
  else
    local ft = vim.api.nvim_buf_get_option(bufnr_here, 'filetype')

    local mem = ll.get(ft)
    local exists = not (mem == nil or
                        vim.fn.bufname(mem.bufnr) == "")

    if exists then
      -- Wipe the old REPL and then create a new one
      vim.api.nvim_command('bwipeout! ' .. mem.bufnr)
      mem, _ = ll.ensure_repl_exists(ft)
      vim.api.nvim_command('wincmd p')
    else
      -- no repl found, so nothing to do
      vim.api.nvim_err_writeln('No repl found in current buffer; cannot restart')
    end
  end

  return mem
end

-- TODO unify repl creation fns
core.repl_by_name = function(repl_name, ft)
  ft = ft or vim.bo.ft
  local repl = fts[ft][repl_name]

  if repl == nil then
    vim.api.nvim_err_writeln('Repl definition of name "' .. repl_name .. '" not found for file type: '.. ft)
    return
  end

  return ll.create_new_repl(ft, repl)
end

-- TODO unify repl creation fns
core.repl_for = function(ft)
  local mem, created = ll.ensure_repl_exists(ft)

  if not created then
    local showfn = function()
      return ll.new_repl_window(mem.bufnr, ft)
    end
    config.visibility(mem.bufnr, showfn)
  else
    vim.api.nvim_command('wincmd p')
  end

  return mem
end

core.focus_on = function(ft)
  local mem = ll.ensure_repl_exists(ft)

  local showfn = function()
    return ll.new_repl_window(mem.bufnr, ft)
  end

  focus(mem.bufnr, showfn)

  return mem
end

-- TODO Move away/deprecate
core.set_config = function(cfg)
  config = require("iron.defaults")._defaults()
  for k, v in pairs(cfg) do
    config[k] = v
  end
end

core.add_repl_definitions = function(defns)
  for ft, defn in pairs(defns) do
    if fts[ft] == nil then
      fts[ft] = {}
    end
    for repl, repldfn in pairs(defn) do
      fts[ft][repl] = repldfn
    end
  end
end

core.send = function(ft, data)
  ll.ensure_repl_exists(ft)
  ll.send_to_repl(ft, data)
end

core.send_line = function()
  local ft = ll.get_buffer_ft(0)

  if ft ~= nil then

    local linenr = vim.api.nvim_win_get_cursor(0)[1] - 1
    local cur_line = vim.api.nvim_buf_get_lines(0, linenr, linenr + 1, 0)[1]
    local width = vim.fn.strwidth(cur_line)

    if width == 0 then return end

    marks.set{
      from_line = linenr,
      from_col = 0,
      to_line = linenr,
      to_col = width
    }

    core.send(ft, cur_line)
  end
end

core.send_chunk = function(mode, mtype)
  local bstart, bend
  local ft = ll.get_buffer_ft(0)

  if ft == nil then return end

  if mode == "visual" then
    bstart = "'<"
    bend = "'>"
  else
    bstart = "'["
    bend = "']"
  end

  local b_line, b_col = unpack(vim.fn.getpos(bstart),2,3)
  local e_line, e_col = unpack(vim.fn.getpos(bend),2,3)

  local lines = vim.api.nvim_buf_get_lines(0, b_line - 1, e_line, 0)

  if #lines == 0 then return end

  local b_line_len = vim.fn.strwidth(lines[1])
  local e_line_len = vim.fn.strwidth(lines[#lines])

  b_col, e_col = unpack(mtype=='line' and { 0, e_line_len } or { b_col, e_col })

  --handle eol
  b_col = ( b_col > b_line_len ) and b_line_len or b_col
  e_col = ( e_col > e_line_len ) and e_line_len or e_col

  if e_col > 1 then
    lines[#lines] = string.sub(lines[#lines], 1, e_col)
  end
  if b_col > 1 then
    lines[1] = string.sub(lines[1], b_col)
  end

  core.send(ft, lines)

  marks.set{
    from_line = b_line - 1,
    from_col = math.max(b_col - 1, 0),
    to_line = e_line - 1,
    to_col = e_col
  }

  marks.winrestview()
end

core.send_motion = function(mtype) core.send_chunk("motion", mtype) end

core.visual_send = function() core.send_chunk("visual") end

core.repeat_cmd = function()
  local ft = ll.get_buffer_ft(0)
  if ft == nil then return end

  local pos = marks.get()

  tap(pos)

  if pos == nil then return end

  local lines = vim.api.nvim_buf_get_lines(0, pos.from_line, pos.to_line + 1, 0)

  if pos.from_col >= 1 then
    lines[1] = string.sub(lines[1], pos.from_col + 1)
  end
  if pos.to_col >= 1 then
    lines[#lines] = string.sub(lines[#lines], 1, pos.to_col + 1)
  end

  core.send(ft, lines)
end

-- TODO Remove from core, make it public elsewhere
core.list_fts = function()
  local lst = {}

  for k, _ in pairs(fts) do
    table.insert(lst, k)
  end

  return lst
end

-- TODO Remove from core, make it public elsewhere
core.list_definitions_for_ft = function(ft)
  local lst = {}
  local defs = tables.get(fts, ft)

  if defs == nil then
    vim.api.nvim_err_writeln("There's no REPL definition for current filetype " .. ft)
  else
    for k, v in pairs(defs) do
      table.insert(lst, {k, v})
    end
  end

  return lst
end


return core
