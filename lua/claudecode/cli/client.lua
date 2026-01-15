---Send input to Claude Code terminal.
---Replaces the HTTP-based client with terminal stdin communication.

local M = {}

---Send text to the Claude Code terminal.
---@param text string The text to send
---@param callback? fun() Optional callback when sent
---@return boolean success
function M.send(text, callback)
  local terminal = require("claudecode.terminal")

  if not terminal.is_active() then
    vim.notify("Claude Code terminal is not active", vim.log.levels.WARN, { title = "claudecode" })
    return false
  end

  local success = terminal.send(text)

  if callback then
    -- Schedule callback for next tick
    vim.schedule(callback)
  end

  return success
end

---Send text with newline (submits the input).
---@param text string The text to send
---@param callback? fun() Optional callback when sent
---@return boolean success
function M.send_line(text, callback)
  local terminal = require("claudecode.terminal")

  if not terminal.is_active() then
    vim.notify("Claude Code terminal is not active", vim.log.levels.WARN, { title = "claudecode" })
    return false
  end

  local success = terminal.send_line(text)

  if callback then
    vim.schedule(callback)
  end

  return success
end

---Send a prompt to Claude Code.
---This is the main function for sending user prompts.
---@param prompt string The prompt text
---@param callback? fun() Optional callback when sent
function M.send_prompt(prompt, callback)
  M.send_line(prompt, callback)
end

---Send a slash command to Claude Code.
---@param command string The command (with or without leading /)
---@param callback? fun() Optional callback when sent
function M.send_command(command, callback)
  -- Ensure command starts with /
  local cmd = command:match("^/") and command or ("/" .. command)
  M.send_line(cmd, callback)
end

---Check if terminal is active.
---@return boolean
function M.is_active()
  return require("claudecode.terminal").is_active()
end

return M
