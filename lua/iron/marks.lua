local config = require("iron.config")
local marks = {}

-- TODO: Externalize, load on demand or upon "init" function
vim.api.nvim_set_hl(config.namespace, "IronLastSent", {
    bold = true
  })

vim.api.nvim_set_hl_ns(config.namespace)

marks.set = function(opts)
  local extmark_config = {
    id = config.mark.send,
    -- to_line can be ignored if it's single line
    end_line = opts.to_line or opts.from_line,
    end_col = opts.to_col
  }

  if opts.hl ~= nil then

    -- Intentionally check here
    -- so opts.false disables highlight
    if opts.hl ~= false then
      extmark_config.hl_group = opts.hl
    end

  elseif (config.highlight_last ~= false and
      config.highlight_last ~= nil) then
    extmark_config.hl_group = config.highlight_last
  end

  vim.api.nvim_buf_set_extmark(0, config.namespace, opts.from_line, opts.from_col, extmark_config)
end

marks.drop_last = function()
  vim.api.nvim_buf_del_extmark(0, config.namespace, config.mark.send)
end

marks.clear_hl = function()
  local payload = marks.get()
  payload.hl = false
  marks.set(payload)
end

marks.get = function()
  local mark_pos = vim.api.nvim_buf_get_extmark_by_id(0, config.namespace, config.mark.send, {details = true})

  if #mark_pos == 0 then
    return nil
  end

  return {
    from_line = mark_pos[1],
    from_col = mark_pos[2],
    to_line = mark_pos[3].end_row,
    to_col = mark_pos[3].end_col
  }

end

marks.winrestview = function()
  local mark = vim.api.nvim_buf_get_extmark_by_id(0, config.namespace, config.mark.save_pos, {})

  if #mark ~= 0 then
    -- winrestview is 1-based
    vim.fn.winrestview({lnum = mark[1], col = mark[2]})
    vim.api.nvim_buf_del_extmark(0, config.namespace, config.mark.save_pos)
  end
end

marks.winsaveview = function()
  local pos = vim.fn.winsaveview()
  vim.api.nvim_buf_set_extmark(0, config.namespace, pos.lnum, pos.col, {id = config.mark.save_pos})
end

return marks

