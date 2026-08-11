# nvim-translate

A lightweight Neovim translation plugin powered by OpenAI-compatible LLMs.

> **AI Project** - This project is powered by GLM-5.2.

## Features

- **Normal mode**: translate the word under cursor
- **Visual mode**: translate the selected text
- **LSP-style hover** display with Markdown highlighting
- **OpenAI-compatible** API support (configurable base URL, model, etc.)
- **API key** via plaintext, function, or environment variable
- **LRU cache** to avoid duplicate API calls
- **Session isolation**: each translation uses a fresh LLM session
- **Smart close behavior**:
  - Normal mode trigger: hover closes when cursor leaves the word
  - Visual mode trigger: hover closes when exiting visual mode (ModeChanged)
  - Press trigger key again while hover is open: jump cursor into hover (for copying)
  - Inside hover: press `Esc` to close
- **Character spinner** loading indicator
- **Thinking mode** toggle (default off)

## Default Translation Behavior

- Non-Chinese text -> translated to **Simplified Chinese**
- Chinese text -> translated to **English**
- Language auto-detected, no need to specify source language

## Installation (lazy.nvim)

### Option 1: Environment variables (recommended)

```lua
{
  "devilsakuya/nvim-translate",
  lazy = true,
  keys = {
    { "<leader>xx", desc = "Translate", mode = { "n", "x" } },
  },
  opts = {},
}
```

No config needed - just set the environment variables:

```bash
export OPENAI_API_KEY="sk-xxxxxxxx"
export OPENAI_BASE_URL="https://api.openai.com/v1"
```

### Option 2: Plaintext API key

```lua
{
  "devilsakuya/nvim-translate",
  lazy = true,
  keys = {
    { "<leader>xx", desc = "Translate", mode = { "n", "x" } },
  },
  opts = {
    api_key = "sk-xxxxxxxx",
    base_url = "https://api.openai.com/v1",
  },
}
```

### Option 3: Function (dynamic retrieval)

```lua
{
  "devilsakuya/nvim-translate",
  lazy = true,
  keys = {
    { "<leader>xx", desc = "Translate", mode = { "n", "x" } },
  },
  opts = {
    api_key = function()
      return os.getenv("OPENAI_API_KEY")
    end,
  },
}
```

> **Note**: The `keys` field should match your `trigger_key` configuration so that
> lazy.nvim knows when to load the plugin.

## Configuration

All options with defaults:

```lua
{
  -- API configuration
  api_key = nil,              -- string | function | nil (falls back to env)
  api_key_env = "OPENAI_API_KEY",
  base_url = nil,             -- string | nil (falls back to env)
  base_url_env = "OPENAI_BASE_URL",
  model = "deepseek-v4-flash",

  -- LLM parameters
  temperature = 0.3,
  max_tokens = 2048,
  enable_thinking = false,    -- disable model thinking by default

  -- Translation system prompt (configurable)
  prompt = "...",              -- see config.lua for full default
  --
  -- Simple custom prompt example:
  --   prompt = "Translate the following text. Chinese to English, otherwise to Chinese. Output only the translation."

  -- Trigger key
  trigger_key = "<leader>xx",

  -- Cache
  cache_enabled = true,
  max_cache_size = 100,

  -- Floating window display
  border = "rounded",

  -- Spinner
  spinner_frames = { "|", "/", "-", "\\" }, -- character sequence for loading spinner
  spinner_interval = 120,                 -- ms between spinner frames
}
```

### Custom Spinner Example

```lua
require("nvim-translate").setup({
  spinner_frames = { ".  ", ".. ", "...", " ..", "  .", "   " },
  spinner_interval = 200,
})
```

## Usage

- Press `<leader>xx` in **normal mode** to translate the word under cursor.
- Press `<leader>xx` in **visual mode** to translate the selected text.
- Press `<leader>xx` again while the hover is open to jump cursor into it (for copying).
- Press `Esc` inside the hover to close it.
- In normal mode, moving the cursor off the translated word auto-closes the hover.
- In visual mode, exiting visual mode (press `Esc`) auto-closes the hover.
- Run `:Translate` as an alternative to the keybinding.

## Custom Keybinding

If you prefer to set up your own keybindings:

```lua
{
  "devilsakuya/nvim-translate",
  lazy = true,
  config = function()
    require("nvim-translate").setup({
      trigger_key = "<leader>xx", -- set to nil to skip auto keybinding
    })
  end,
  keys = {
    { "<leader>xx", "<cmd>Translate<cr>", desc = "Translate", mode = { "n", "x" } },
  },
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:Translate` | Translate text under cursor or selection |

## API

```lua
-- Trigger translation programmatically
require("nvim-translate").translate()

-- Clear the translation cache
require("nvim-translate").clear_cache()
```

## Requirements

- Neovim >= 0.10
- `curl` available in PATH
- An OpenAI-compatible API key
- Environment variables `OPENAI_API_KEY` and `OPENAI_BASE_URL` (or configure in setup)
