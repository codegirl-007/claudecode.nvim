---@module 'snacks'

---Provide an embedded `claude` via [`snacks.terminal`](https://github.com/folke/snacks.nvim/blob/main/docs/terminal.md).
---@class claudecode.provider.Snacks : claudecode.Provider
---
---@field opts snacks.terminal.Opts
local Snacks = {}
Snacks.__index = Snacks
Snacks.name = "snacks"

---@class claudecode.provider.snacks.Opts : snacks.terminal.Opts

---@param opts? claudecode.provider.snacks.Opts
---@return claudecode.provider.Snacks
function Snacks.new(opts)
  local self = setmetatable({}, Snacks)
  self.opts = opts or {}
  return self
end

---Check if `snacks.terminal` is available and enabled.
function Snacks.health()
  local snacks_ok, snacks = pcall(require, "snacks")
  if not snacks_ok then
    return "`snacks.nvim` is not available.", {
      "Install `snacks.nvim` and enable `snacks.terminal.`",
    }
  elseif not snacks.config.get("terminal", {}).enabled then
    return "`snacks.terminal` is not enabled.",
      {
        "Enable `snacks.terminal` in your `snacks.nvim` configuration.",
      }
  end

  return true
end

function Snacks:get()
  ---@type snacks.terminal.Opts
  local opts = vim.tbl_deep_extend("force", self.opts, { create = false })
  local win = require("snacks.terminal").get(self.cmd, opts)
  return win
end

---Update the terminal state manager with snacks terminal state.
function Snacks:update_terminal_state()
  local win = self:get()
  if win and win.buf and vim.api.nvim_buf_is_valid(win.buf) then
    -- Get the terminal channel from the buffer
    local ok, channel = pcall(vim.api.nvim_buf_get_var, win.buf, "terminal_job_id")
    if ok then
      require("claudecode.terminal").set_state({
        provider = self,
        bufnr = win.buf,
        channel = channel,
      })
      return
    end
  end

  -- Clear state if terminal not available
  require("claudecode.terminal").clear_state()
end

function Snacks:toggle()
  require("snacks.terminal").toggle(self.cmd, self.opts)
  vim.schedule(function()
    self:update_terminal_state()
  end)
end

function Snacks:start()
  if not self:get() then
    require("snacks.terminal").open(self.cmd, self.opts)
    vim.schedule(function()
      self:update_terminal_state()
    end)
  else
    self:update_terminal_state()
  end
end

function Snacks:stop()
  local win = self:get()
  if win then
    win:close()
  end
  require("claudecode.terminal").clear_state()
end

return Snacks
