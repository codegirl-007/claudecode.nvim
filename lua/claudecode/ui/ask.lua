---@module 'snacks.input'

local M = {}

---@class claudecode.ask.Opts
---
---Text of the prompt.
---@field prompt? string
---
---Options for [`snacks.input`](https://github.com/folke/snacks.nvim/blob/main/docs/input.md).
---@field snacks? snacks.input.Opts

---Input a prompt for `claude`.
---
--- - Press the up arrow to browse recent asks.
--- - Highlights and completes context placeholders.
---   - Press `<Tab>` to trigger built-in completion.
---
---@param default? string Text to pre-fill the input with.
---@param opts? claudecode.api.prompt.Opts Options for `prompt()`.
function M.ask(default, opts)
  opts = opts or {}
  opts.context = opts.context or require("claudecode.context").new()

  ---@type snacks.input.Opts
  local input_opts = {
    default = default,
    highlight = function(text)
      local rendered = opts.context:render(text)
      -- Transform to `:help input()-highlight` format
      return vim.tbl_map(function(extmark)
        return { extmark.col, extmark.end_col, extmark.hl_group }
      end, opts.context.extmarks(rendered.input))
    end,
    completion = "customlist,v:lua.claudecode_completion",
    -- `snacks.input`-only options
    win = {
      b = {
        -- Enable `blink.cmp` completion
        completion = true,
      },
      bo = {
        -- Custom filetype to enable `blink.cmp` source on
        filetype = "claudecode_ask",
      },
      on_buf = function(win)
        -- Wait as long as possible to check for `blink.cmp` loaded
        vim.api.nvim_create_autocmd("InsertEnter", {
          once = true,
          buffer = win.buf,
          callback = function()
            if package.loaded["blink.cmp"] then
              require("claudecode.cmp.blink").setup()
            end
          end,
        })
      end,
    },
  }
  -- Nest `snacks.input` options under `opts.ask.snacks` for consistency
  input_opts = vim.tbl_deep_extend("force", input_opts, require("claudecode.config").opts.ask or {})
  input_opts = vim.tbl_deep_extend("force", input_opts, (require("claudecode.config").opts.ask or {}).snacks or {})

  -- Store context for completion
  require("claudecode.cmp.blink").context = opts.context

  vim.ui.input(input_opts, function(value)
    if value and value ~= "" then
      opts.context:clear()
      require("claudecode").prompt(value, opts)
    else
      opts.context:resume()
    end
  end)
end

---Completion function for context placeholders.
---Must be a global variable for use with `vim.ui.select`.
---
---@param ArgLead string The text being completed.
---@param CmdLine string The entire current input line.
---@param CursorPos number The cursor position in the input line.
---@return table<string> items A list of filtered completion items.
_G.claudecode_completion = function(ArgLead, CmdLine, CursorPos)
  local start_idx, end_idx = CmdLine:find("([^%s]+)$")
  local latest_word = start_idx and CmdLine:sub(start_idx, end_idx) or nil

  local completions = {}
  for placeholder, _ in pairs(require("claudecode.config").opts.contexts or {}) do
    table.insert(completions, placeholder)
  end

  local items = {}
  for _, completion in pairs(completions) do
    if not latest_word then
      local new_cmd = CmdLine .. completion
      table.insert(items, new_cmd)
    elseif completion:find(latest_word, 1, true) == 1 then
      local new_cmd = CmdLine:sub(1, start_idx - 1) .. completion .. CmdLine:sub(end_idx + 1)
      table.insert(items, new_cmd)
    end
  end
  return items
end

return M
