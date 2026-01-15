---@module 'snacks'

local M = {}

---Your `claudecode.nvim` configuration.
---Passed via global variable for [simpler UX and faster startup](https://mrcjkb.dev/posts/2023-08-22-setup.html).
---
---@type claudecode.Opts|nil
vim.g.claudecode_opts = vim.g.claudecode_opts

---@class claudecode.Opts
---
---Contexts to inject into prompts, keyed by their placeholder.
---@field contexts? table<string, fun(context: claudecode.Context): string|nil>
---
---Prompts to reference or select from.
---@field prompts? table<string, claudecode.Prompt>
---
---Options for `ask()`.
---Supports [`snacks.input`](https://github.com/folke/snacks.nvim/blob/main/docs/input.md).
---@field ask? claudecode.ask.Opts
---
---Options for `select()`.
---Supports [`snacks.picker`](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md).
---@field select? claudecode.select.Opts
---
---Options for file watching (auto-reload on changes).
---@field file_watcher? claudecode.file_watcher.Opts
---
---Provide an integrated `claude` terminal when one is not found.
---@field provider? claudecode.Provider|claudecode.provider.Opts

---@class claudecode.Prompt : claudecode.api.prompt.Opts
---@field prompt string The prompt to send to `claude`.
---@field ask? boolean Call `ask(prompt)` instead of `prompt(prompt)`. Useful for prompts that expect additional user input.

---@class claudecode.file_watcher.Opts
---@field enabled? boolean Enable file watching for auto-reload (default true)
---@field ignore_patterns? string[] Patterns to ignore (default includes .git, node_modules, etc.)

---@type claudecode.Opts
local defaults = {
  -- stylua: ignore
  contexts = {
    ["@this"] = function(context) return context:this() end,
    ["@buffer"] = function(context) return context:buffer() end,
    ["@buffers"] = function(context) return context:buffers() end,
    ["@visible"] = function(context) return context:visible_text() end,
    ["@diagnostics"] = function(context) return context:diagnostics() end,
    ["@quickfix"] = function(context) return context:quickfix() end,
    ["@diff"] = function(context) return context:git_diff() end,
    ["@marks"] = function(context) return context:marks() end,
    ["@grapple"] = function(context) return context:grapple_tags() end,
  },
  prompts = {
    ask_append = { prompt = "", ask = true },
    ask_this = { prompt = "@this: ", ask = true, submit = true },
    diagnostics = { prompt = "Explain @diagnostics", submit = true },
    diff = { prompt = "Review the following git diff for correctness and readability: @diff", submit = true },
    document = { prompt = "Add comments documenting @this", submit = true },
    explain = { prompt = "Explain @this and its context", submit = true },
    fix = { prompt = "Fix @diagnostics", submit = true },
    implement = { prompt = "Implement @this", submit = true },
    optimize = { prompt = "Optimize @this for performance and readability", submit = true },
    review = { prompt = "Review @this for correctness and readability", submit = true },
    test = { prompt = "Add tests for @this", submit = true },
  },
  ask = {
    prompt = "Ask Claude: ",
    snacks = {
      icon = "󰚩 ",
      win = {
        title_pos = "left",
        relative = "cursor",
        row = -3,
        col = 0,
      },
    },
  },
  select = {
    prompt = "Claude: ",
    sections = {
      prompts = true,
      commands = {
        -- Claude Code slash commands
        ["clear"] = "Clear conversation history",
        ["compact"] = "Compact conversation to reduce context",
        ["config"] = "Open Claude Code configuration",
        ["cost"] = "Show token usage and cost",
        ["doctor"] = "Run diagnostic checks",
        ["help"] = "Show help information",
        ["init"] = "Initialize CLAUDE.md in project",
        ["memory"] = "Manage Claude's memory",
        ["review"] = "Review recent changes",
      },
      provider = true,
    },
    snacks = {
      preview = "preview",
      layout = {
        preset = "vscode",
        hidden = {},
      },
    },
  },
  file_watcher = {
    enabled = true,
    ignore_patterns = {
      "%.git",
      "node_modules",
      "%.next",
      "__pycache__",
      "%.pytest_cache",
      "%.mypy_cache",
      "target",
      "dist",
      "build",
      "%.cache",
    },
  },
  provider = {
    cmd = "claude",
    enabled = (function()
      for _, provider in ipairs(require("claudecode.provider").list()) do
        local ok, _ = provider.health()
        if ok == true then
          return provider.name
        end
      end
      return false
    end)(),
    terminal = {
      split = "right",
      width = math.floor(vim.o.columns * 0.35),
    },
    snacks = {
      auto_close = true,
      win = {
        position = "right",
        enter = false,
        wo = {
          winbar = "",
        },
        bo = {
          filetype = "claudecode_terminal",
        },
      },
    },
  },
}

---Plugin options, lazily merged from `defaults` and `vim.g.claudecode_opts`.
---@type claudecode.Opts
M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), vim.g.claudecode_opts or {})

-- Allow removing default `contexts` and `prompts` by setting them to `false` in your user config.
local user_opts = vim.g.claudecode_opts or {}
for _, field in ipairs({ "contexts", "prompts" }) do
  if user_opts[field] and M.opts[field] then
    for k, v in pairs(user_opts[field]) do
      if not v then
        M.opts[field][k] = nil
      end
    end
  end
end

---The `claude` provider resolved from `opts.provider`.
---@type claudecode.Provider|nil
M.provider = (function()
  local provider
  local provider_or_opts = M.opts.provider

  if provider_or_opts and (provider_or_opts.toggle or provider_or_opts.start or provider_or_opts.stop) then
    ---@cast provider_or_opts claudecode.Provider
    provider = provider_or_opts
  elseif provider_or_opts and provider_or_opts.enabled then
    ---@type boolean, claudecode.Provider
    local ok, resolved_provider = pcall(require, "claudecode.provider." .. provider_or_opts.enabled)
    if not ok then
      vim.notify(
        "Failed to load `claude` provider '" .. provider_or_opts.enabled .. "': " .. resolved_provider,
        vim.log.levels.ERROR,
        { title = "claudecode" }
      )
      return nil
    end

    local resolved_provider_opts = provider_or_opts[provider_or_opts.enabled]
    provider = resolved_provider.new(resolved_provider_opts)

    provider.cmd = provider.cmd or provider_or_opts.cmd
  end

  return provider
end)()

return M
