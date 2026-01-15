---Simplified events module for Claude Code.
---Since Claude Code doesn't have SSE events like OpenCode,
---this module is mostly a stub for API compatibility.
---
---File watching for auto-reload is handled in terminal.lua instead.

local M = {}

---Subscribe to events (no-op for Claude Code).
---File watching is started automatically when terminal becomes active.
function M.subscribe()
  -- No-op: File watching is handled by terminal.lua
end

---Unsubscribe from events (no-op for Claude Code).
function M.unsubscribe()
  -- No-op: File watching is stopped by terminal.lua when terminal closes
end

return M
