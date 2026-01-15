---Simplified status tracking for Claude Code.
---Since Claude Code doesn't have SSE events, we just track terminal state.

local M = {}

---@alias claudecode.status.Status
---| "active"    -- Terminal exists and claude is running
---| nil         -- No terminal

---@type claudecode.status.Status
M.status = nil

---Update status based on terminal state.
function M.update()
  if require("claudecode.terminal").is_active() then
    M.status = "active"
  else
    M.status = nil
  end
end

---Get statusline indicator.
---@return string
function M.statusline()
  M.update()

  if M.status == "active" then
    return "󰚩" -- Claude icon (active)
  else
    return "󱚧" -- Disconnected
  end
end

return M
