---Claude Code integration for Neovim.
---
---@module claudecode

local M = {}

---Input a prompt for Claude.
---@param default? string Text to pre-fill the input with.
---@param opts? claudecode.api.prompt.Opts Options for `prompt()`.
M.ask = function(default, opts)
  require("claudecode.ui.ask").ask(default, opts)
end

---Select from all claudecode.nvim functionality.
---@param opts? claudecode.select.Opts Override configured options for this call.
M.select = function(opts)
  require("claudecode.ui.select").select(opts)
end

---Send a prompt to Claude.
---@param prompt string The prompt text.
---@param opts? claudecode.api.prompt.Opts Options for the prompt.
M.prompt = function(prompt, opts)
  require("claudecode.api.prompt").prompt(prompt, opts)
end

---Create a Vim operator for sending prompts with ranges.
---@param prompt string The prompt template.
---@param opts? claudecode.api.prompt.Opts Options for the prompt.
---@return string The operator key to use.
M.operator = function(prompt, opts)
  return require("claudecode.api.operator").operator(prompt, opts)
end

---Execute a Claude Code slash command.
---@param command claudecode.Command|string The command to execute.
M.command = function(command)
  require("claudecode.api.command").command(command)
end

---Toggle the Claude terminal.
M.toggle = function()
  require("claudecode.provider").toggle()
end

---Start the Claude terminal.
M.start = function()
  require("claudecode.provider").start()
end

---Stop the Claude terminal.
M.stop = function()
  require("claudecode.provider").stop()
end

---Get the statusline indicator.
---@return string The statusline string.
M.statusline = function()
  return require("claudecode.status").statusline()
end

return M
