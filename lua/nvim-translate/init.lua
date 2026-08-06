local config = require("nvim-translate.config")
local cache = require("nvim-translate.cache")

local M = {}

--- Setup the plugin with user options.
--- @param opts table|nil User configuration to merge with defaults.
function M.setup(opts)
  -- Load and merge configuration
  config.setup(opts)

  local cfg = config.get()

  -- Initialize cache
  cache.setup(cfg.max_cache_size)

  -- Register trigger key for normal and visual modes
  vim.keymap.set({ "n", "x" }, cfg.trigger_key, function()
    require("nvim-translate.translate").translate()
  end, {
    desc = "Translate text",
    silent = true,
  })

  -- Register user command :Translate
  vim.api.nvim_create_user_command("Translate", function()
    require("nvim-translate.translate").translate()
  end, {
    desc = "Translate text under cursor or selection",
  })
end

-- Public API

--- Trigger translation (for custom keymaps).
function M.translate()
  require("nvim-translate.translate").translate()
end

--- Clear the translation cache.
function M.clear_cache()
  cache.clear()
  vim.notify("[nvim-translate] Cache cleared", vim.log.levels.INFO)
end

return M
