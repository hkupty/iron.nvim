local tables = require("iron.util.tables")
local strings = require("iron.util.strings")
local repl = require("iron.fts.common").functions
local config = require("iron.config")
local fts = require("iron.fts")

local ll = {}
ll.store = {}

ll.get = function(ft)
  return config.scope.get(ll.store, ft)
end

ll.set = function(ft, fn)
  return config.scope.set(ll.store, ft, fn)
end

ll.get_buffer_ft = function(bufnr)
  local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  if tables.get(fts, ft) == nil then
    vim.api.nvim_err_writeln("There's no REPL definition for current filetype "..ft)
  else
    return ft
  end
end

ll.get_preferred_repl = function(ft)
  local repl_definitions = fts[ft]
  local preference = config.preferred[ft]
  local repl_def = nil

  if preference ~= nil then
    repl_def = repl_definitions[preference]
  elseif repl_definitions ~= nil then
    for _, v in pairs(repl_definitions) do
      if vim.fn.executable(v.command[1]) == 1 then
        repl_def = v
        break
      end
    end
    if repl_def == nil then
      vim.api.nvim_err_writeln("Failed to locate REPL executable, aborting")
    end
  else
    vim.api.nvim_err_writeln("There's no REPL definition for current filetype "..ft)
  end
  return repl_def
end

ll.new_repl_window = function(buff, ft)
  if type(config.repl_open_cmd) == "function" then
    return config.repl_open_cmd(buff, ft)
  else
    return view.openwin(config.repl_open_cmd, buff)
  end
end

ll.create_new_repl = function(ft, repl, new_win)
  -- make creation of new windows optional
  if new_win == nil then
    new_win = true
  end

  local winid
  local prevwin = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_create_buf(false, true)

  if new_win then
    winid = ll.new_repl_window(bufnr, ft)
  else
    if ll.get(ft) == nil then
      winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(winid, bufnr)
    else
      winid = ll.get(ft).winid
    end
  end

  vim.api.nvim_set_current_win(winid)
  local job_id = vim.fn.termopen(repl.command)

  local inst = {
    bufnr = bufnr,
    job = job_id,
    repldef = repl,
    winid = winid
  }

  local timer = vim.loop.new_timer()
  timer:start(10, 0, vim.schedule_wrap(function()
      vim.api.nvim_set_current_win(prevwin)
    end))

  return ll.set(ft, inst)
end

ll.create_preferred_repl = function(ft, new_win)
    local repl = ll.get_preferred_repl(ft)

    if repl ~= nil then
      return ll.create_new_repl(ft, repl, new_win)
    end

    return nil
end

ll.ensure_repl_exists = function(ft)
  local mem = ll.get(ft)
  local created = false

  if mem == nil or vim.fn.bufname(mem.bufnr) == "" then
    mem = ll.create_preferred_repl(ft)
    created = true
  end

  return mem, created
end

ll.send_to_repl = function(ft, data)
  local dt = data

  if type(data) == "string" then
    dt = strings.split(data, '\n')
  end

  local mem = ll.get(ft)
  dt = repl.format(mem.repldef, dt)

  local window = vim.fn.win_getid(vim.fn.bufwinnr(mem.bufnr))
  vim.api.nvim_win_set_cursor(window, {vim.api.nvim_buf_line_count(mem.bufnr), 0})

  local indent = ""
  for i, v in ipairs(dt) do
    if #v == 0 then
      dt[i] = indent
    else
      indent = string.match(v, '^(%s)') or ""
    end
  end
  vim.api.nvim_call_function('chansend', {mem.job, dt})
end

ll.get_repl_ft_for_bufnr = function(bufnr)
  -- given a buffer number, tries to look up the corresponding
  -- filetype of the REPL
  -- If the corresponding buffer number does not exist or is not
  -- a REPL, then return nil
  local ft_found = nil
  for ft in pairs(ll.store) do
    local mem = ll.get(ft)
    if mem ~= nil and bufnr == mem.bufnr then
      ft_found = ft
    end
  end
  return ft_found
end


return ll
