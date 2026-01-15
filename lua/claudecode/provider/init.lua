---@module 'snacks.terminal'

---Provide an integrated `claude`.
---Providers should ignore manually-started `claude` instances,
---operating only on those they start themselves.
---@class claudecode.Provider
---
---The name of the provider.
---@field name? string
---
---The command to start `claude`.
---@field cmd? string
---
---@field new? fun(opts: table): claudecode.Provider
---
---Toggle `claude`.
---@field toggle? fun(self: claudecode.Provider)
---
---Start `claude`.
---Called when attempting to interact with `claude` but none was found.
---Should not steal focus by default, if possible.
---@field start? fun(self: claudecode.Provider)
---
---Stop the previously started `claude`.
---Called when Neovim is exiting.
---@field stop? fun(self: claudecode.Provider)
---
---Health check for the provider.
---Should return `true` if the provider is available,
---else an error string and optional advice (for `vim.health.warn`).
---@field health? fun(): boolean|string, ...string|string[]

---Configure and enable built-in providers.
---@class claudecode.provider.Opts
---
---The built-in provider to use, or `false` for none.
---Default order:
---  - `"snacks"` if `snacks.terminal` is available and enabled
---  - `"terminal"` as a fallback
---@field enabled? "terminal"|"snacks"|false
---
---@field terminal? claudecode.provider.terminal.Opts
---@field snacks? claudecode.provider.snacks.Opts

local M = {}

---Get all providers.
---@return claudecode.Provider[]
function M.list()
  return {
    require("claudecode.provider.snacks"),
    require("claudecode.provider.terminal"),
  }
end

---Toggle `claude` via the configured provider.
function M.toggle()
  local provider = require("claudecode.config").provider
  if provider and provider.toggle then
    provider:toggle()
  else
    error("`provider.toggle` unavailable — run `:checkhealth claudecode` for details", 0)
  end
end

---Start `claude` via the configured provider.
function M.start()
  local provider = require("claudecode.config").provider
  if provider and provider.start then
    provider:start()
  else
    error("`provider.start` unavailable — run `:checkhealth claudecode` for details", 0)
  end
end

---Stop `claude` via the configured provider.
function M.stop()
  local provider = require("claudecode.config").provider
  if provider and provider.stop then
    provider:stop()
    require("claudecode.terminal").clear_state()
  else
    error("`provider.stop` unavailable — run `:checkhealth claudecode` for details", 0)
  end
end

return M
