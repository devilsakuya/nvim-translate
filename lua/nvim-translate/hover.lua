local config = require("nvim-translate.config")

local M = {}

-- Internal state tracking the current hover window lifecycle
local state = {
  win = nil,
  buf = nil,
  source_win = nil,
  source_buf = nil,
  trigger_mode = nil,
  translated_word = nil,
  augroup = nil,
  dismissed = false, -- true when user dismissed the hover
}

-- Re-entrance guard
local closing = false

function M.is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

function M.is_dismissed()
  return state.dismissed
end

function M.show(lines, opts)
  opts = opts or {}

  M.close()

  -- Reset dismissed flag for new hover
  state.dismissed = false

  -- Sanitize lines: ensure non-empty table with at least one line
  if not lines or #lines == 0 then
    lines = { "" }
  end

  local cfg = config.get()
  local bn, wn = vim.lsp.util.open_floating_preview(lines, "markdown", {
    focus = false,
    border = cfg.border,
    close_events = {},
  })

  state.win = wn
  state.buf = bn
  state.source_win = vim.api.nvim_get_current_win()
  state.source_buf = vim.api.nvim_get_current_buf()
  state.trigger_mode = opts.trigger_mode
  state.translated_word = opts.translated_word

  state.augroup = vim.api.nvim_create_augroup("NvimTranslate", { clear = true })

  if opts.trigger_mode == "n" and opts.translated_word then
    -- Normal mode: close when cursor leaves the translated word
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = state.source_buf,
      group = state.augroup,
      callback = function()
        if closing or not M.is_open() then
          return
        end
        local cur_word = vim.fn.expand("<cword>")
        if cur_word ~= state.translated_word then
          M.close()
        end
      end,
    })
  elseif opts.trigger_mode == "v" then
    -- Visual mode: close when user leaves visual mode (e.g. presses Esc)
    vim.api.nvim_create_autocmd("ModeChanged", {
      group = state.augroup,
      pattern = { "v:*", "V:*", "\22:*" },
      callback = function()
        if M.is_open() then
          M.close()
        end
      end,
    })
  end

  -- Always allow <Esc> inside the hover buffer to close it
  vim.api.nvim_buf_set_keymap(bn, "n", "<Esc>", "", {
    callback = function()
      M.close()
    end,
    noremap = true,
    silent = true,
    desc = "Close translate hover",
  })

  return bn, wn
end

--- Update the content of the current hover window without recreating it.
--- @param lines table Array of strings to display
function M.update(lines)
  if not M.is_open() or not state.buf then
    return
  end
  if not lines or #lines == 0 then
    lines = { "" }
  end
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

function M.focus()
  if not M.is_open() then
    return
  end

  if state.augroup then
    vim.api.nvim_clear_autocmds({ group = state.augroup })
  end

  vim.api.nvim_set_current_win(state.win)
end

function M.close()
  if closing then
    return
  end
  closing = true

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end

  if state.augroup then
    pcall(vim.api.nvim_clear_autocmds, { group = state.augroup })
  end

  -- Mark as dismissed so pending LLM callbacks know not to show
  state.dismissed = true

  state.win = nil
  state.buf = nil
  state.source_win = nil
  state.source_buf = nil
  state.trigger_mode = nil
  state.translated_word = nil
  state.augroup = nil

  closing = false
end

return M
