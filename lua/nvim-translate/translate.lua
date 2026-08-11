local config = require("nvim-translate.config")
local cache = require("nvim-translate.cache")
local llm = require("nvim-translate.llm")
local hover = require("nvim-translate.hover")

local M = {}

-- Request ID to discard stale LLM responses
local request_id = 0

-- Spinner state
local spinner_timer = nil
local spinner_idx = 1

local spinner_stop -- forward declaration

local function spinner_start()
  spinner_stop()
  local cfg = config.get()
  local frames = cfg.spinner_frames or { "|", "/", "-", "\\" }
  local interval = cfg.spinner_interval or 120
  spinner_idx = 1
  spinner_timer = vim.uv.new_timer()
  spinner_timer:start(0, interval, vim.schedule_wrap(function()
    if not hover.is_open() then
      spinner_stop()
      return
    end
    hover.update({ "  " .. frames[spinner_idx] .. "  Translating..." })
    spinner_idx = (spinner_idx % #frames) + 1
  end))
end

function spinner_stop()
  if spinner_timer then
    spinner_timer:stop()
    if not spinner_timer:is_closing() then
      spinner_timer:close()
    end
    spinner_timer = nil
  end
end

--- Resolve API key from config: string > function > env var
--- @return string|nil api_key
--- @return string|nil error_msg
local function resolve_api_key(opts)
  if type(opts.api_key) == "string" and opts.api_key ~= "" then
    return opts.api_key
  elseif type(opts.api_key) == "function" then
    local key = opts.api_key()
    if key and key ~= "" then
      return key
    end
  elseif opts.api_key == nil and opts.api_key_env then
    local key = os.getenv(opts.api_key_env)
    if key and key ~= "" then
      return key
    end
  end
  return nil, "API key not configured (set api_key or " .. (opts.api_key_env or "OPENAI_API_KEY") .. ")"
end

--- Resolve base URL from config: string > env var > fallback
--- @return string base_url
local function resolve_base_url(opts)
  if type(opts.base_url) == "string" and opts.base_url ~= "" then
    return opts.base_url
  elseif opts.base_url_env then
    local url = os.getenv(opts.base_url_env)
    if url and url ~= "" then
      return url
    end
  end
  return "https://api.openai.com/v1"
end

--- Get the input text based on the current mode.
--- @return string text, string trigger_mode, string|nil translated_word
local function get_input()
  local mode = vim.fn.mode()

  if mode:match("[vV\22]") then
    -- Visual mode: get selected text before exiting
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getpos(".")
    local lines = vim.fn.getregion(start_pos, end_pos, { type = mode })
    return table.concat(lines, "\n"), "v", nil
  else
    -- Normal mode: get word under cursor
    local word = vim.fn.expand("<cword>")
    return word, "n", word
  end
end

--- Main translation entry point.
function M.translate()
  -- If hover is already open, jump cursor into it (for copying)
  if hover.is_open() then
    hover.focus()
    return
  end

  -- Get input text
  local text, trigger_mode, translated_word = get_input()

  if text == nil or text == "" then
    vim.notify("[nvim-translate] Nothing to translate", vim.log.levels.WARN)
    return
  end

  local opts = config.get()

  -- Check cache
  if opts.cache_enabled then
    local cached = cache.get(text)
    if cached then
      hover.show(vim.split(cached, "\n"), {
        trigger_mode = trigger_mode,
        translated_word = translated_word,
      })
      return
    end
  end

  -- Show loading indicator with spinner
  hover.show({ "  |  Translating..." }, {
    trigger_mode = trigger_mode,
    translated_word = translated_word,
  })
  spinner_start()

  -- Resolve API key
  local api_key, err = resolve_api_key(opts)
  if not api_key then
    spinner_stop()
    hover.show({ "[Error] " .. (err or "API key not configured") }, {
      trigger_mode = trigger_mode,
      translated_word = translated_word,
    })
    return
  end

  -- Increment request ID to track this request
  request_id = request_id + 1
  local current_id = request_id

  -- Build a fresh messages array (new session each time)
  local messages = {
    { role = "system", content = opts.prompt },
    { role = "user", content = text },
  }

  -- Call LLM asynchronously
  llm.chat({
    messages = messages,
    model = opts.model,
    temperature = opts.temperature,
    max_tokens = opts.max_tokens,
    api_key = api_key,
    base_url = resolve_base_url(opts),
    enable_thinking = opts.enable_thinking,
  }, function(result, llm_err)
    vim.schedule(function()
      spinner_stop()

      -- Discard stale responses
      if current_id ~= request_id then
        return
      end

      -- User dismissed the hover while loading, don't show result
      if hover.is_dismissed() then
        return
      end

      if llm_err then
        hover.show({ "[Error] " .. llm_err }, {
          trigger_mode = trigger_mode,
          translated_word = translated_word,
        })
        return
      end

      -- Cache the result
      if opts.cache_enabled then
        cache.set(text, result)
      end

      -- Display translation
      hover.show(vim.split(result, "\n"), {
        trigger_mode = trigger_mode,
        translated_word = translated_word,
      })
    end)
  end)
end

return M
