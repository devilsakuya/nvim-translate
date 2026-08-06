local M = {}

--- Send a chat completion request to an OpenAI-compatible endpoint.
--- @param opts table { messages, model, temperature, max_tokens, api_key, base_url }
--- @param on_complete function(result: string|nil, err: string|nil)
function M.chat(opts, on_complete)
  local body_table = {
    model = opts.model,
    messages = opts.messages,
    temperature = opts.temperature,
    max_tokens = opts.max_tokens,
  }

  -- Pass enable_thinking only when explicitly set
  if opts.enable_thinking ~= nil then
    body_table.enable_thinking = opts.enable_thinking
  end

  local body = vim.json.encode(body_table)

  local url = opts.base_url:gsub("/+$", "") .. "/chat/completions"
  local api_key = opts.api_key

  local args = {
    "curl",
    "-s",
    "-X",
    "POST",
    url,
    "-H",
    "Content-Type: application/json",
    "-H",
    "Authorization: Bearer " .. api_key,
    "-d",
    body,
  }

  vim.system(args, { text = true }, function(obj)
    if obj.code ~= 0 then
      on_complete(nil, obj.stderr or ("curl exited with code " .. obj.code))
      return
    end

    local ok, response = pcall(vim.json.decode, obj.stdout)
    if not ok then
      on_complete(nil, "Failed to parse API response: " .. tostring(response))
      return
    end

    if response.error then
      on_complete(nil, response.error.message or "Unknown API error")
      return
    end

    local content = response.choices
      and response.choices[1]
      and response.choices[1].message
      and response.choices[1].message.content

    if not content then
      on_complete(nil, "No content in API response")
      return
    end

    on_complete(content, nil)
  end)
end

return M
