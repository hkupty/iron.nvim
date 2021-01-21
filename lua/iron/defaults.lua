local view = require("iron.view")
local tables = require("iron.util.tables")
local namespace = vim.api.nvim_create_namespace("iron")

local defaults = {
  highlight_last = "IronLastSent",
  visibility = require("iron.visibility").toggle,
  scope = require("iron.scope").path_based,
  preferred = {},
  repl_open_cmd = view.openwin('topleft vertical 100 split'),
  namespace = namespace,
  mark = { -- Arbitrary numbers
    save_pos = 20,
    send = 77,
    begin_last = 99, -- Deprecated
    end_last = 100 -- Deprecated
  },
}

return setmetatable({
    _defaults = function() return tables.clone(defaults) end
  }, {
  __newindex = function(tbl, k, v)
    error("Don't alter default table. Change iron.config instead", 2)
  end,
  __index = function(_, k)
    return defaults[k]
  end
})
