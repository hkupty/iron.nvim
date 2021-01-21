-- luacheck: globals unpack vim

-- [[ -> iron
-- Here is the complete iron API.
-- Below is a brief description of module separation:
--  -->> ll:
--    Low level functions that interact with neovim's windows and buffers.
--
--  -->> config:
--    This is what guides irons behavior.
--
--  -->> core:
--    User api, should have all public functions there.
-- ]]

local iron = {
  -- Will eventually be removed
  config = require("iron.config"),
  -- Most likely shouldn't be exposed here
  ll = require("iron.lowlevel"),
  core = require("iron.core"),
}

return iron
