---Provide an embedded `claude` via a [Neovim terminal](https://neovim.io/doc/user/terminal.html) buffer.
---@class claudecode.provider.Terminal : claudecode.Provider
---
---@field opts claudecode.provider.terminal.Opts
---
---@field bufnr? integer
---@field winid? integer
---@field job_id? integer
local Terminal = {}
Terminal.__index = Terminal
Terminal.name = "terminal"

---@class claudecode.provider.terminal.Opts : vim.api.keyset.win_config

function Terminal.new(opts)
  local self = setmetatable({}, Terminal)
  self.opts = opts or {}
  self.winid = nil
  self.bufnr = nil
  self.job_id = nil
  return self
end

function Terminal.health()
  return true
end

---Update the terminal state manager with our state.
function Terminal:update_terminal_state()
  local channel = nil
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    -- Get the terminal channel from the buffer
    local ok, chan = pcall(vim.api.nvim_buf_get_var, self.bufnr, "terminal_job_id")
    if ok then
      channel = chan
    end
  end

  require("claudecode.terminal").set_state({
    provider = self,
    job_id = self.job_id,
    bufnr = self.bufnr,
    channel = channel,
  })
end

---Start if not running, else hide/show the window.
function Terminal:toggle()
  if self.bufnr == nil then
    self:start()
  else
    if self.winid ~= nil and vim.api.nvim_win_is_valid(self.winid) then
      -- Hide the window
      vim.api.nvim_win_hide(self.winid)
      self.winid = nil
    elseif self.bufnr ~= nil and vim.api.nvim_buf_is_valid(self.bufnr) then
      -- Show the window
      local previous_win = vim.api.nvim_get_current_win()
      self.winid = vim.api.nvim_open_win(self.bufnr, true, self.opts)
      vim.api.nvim_set_current_win(previous_win)
    end
    -- Ensure state is up to date
    require("claudecode.terminal").set_state({
      provider = self,
      job_id = self.job_id,
      bufnr = self.bufnr,
      channel = self.job_id,
    })
  end
end

---Open a window with a terminal buffer.
function Terminal:start()
  if self.bufnr == nil then
    local previous_win = vim.api.nvim_get_current_win()

    self.bufnr = vim.api.nvim_create_buf(true, false)
    self.winid = vim.api.nvim_open_win(self.bufnr, true, self.opts)

    -- Redraw terminal buffer on initial render.
    -- Fixes empty columns on the right side.
    local auid
    auid = vim.api.nvim_create_autocmd("TermRequest", {
      buffer = self.bufnr,
      callback = function(ev)
        if ev.data.cursor[1] > 1 then
          vim.api.nvim_del_autocmd(auid)
          vim.api.nvim_set_current_win(self.winid)
          vim.cmd([[startinsert | call feedkeys("\<C-\>\<C-n>\<C-w>p", "n")]])
        end
      end,
    })

    self.job_id = vim.fn.jobstart(self.cmd, {
      term = true,
      on_exit = function()
        self.winid = nil
        self.bufnr = nil
        self.job_id = nil
        require("claudecode.terminal").clear_state()
      end,
    })

    -- For terminal buffers, get the channel from the buffer variable
    -- This is more reliable than using job_id directly
    local channel = self.job_id
    vim.schedule(function()
      if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
        local ok, term_channel = pcall(vim.api.nvim_buf_get_var, self.bufnr, "terminal_job_id")
        if ok and term_channel then
          channel = term_channel
          require("claudecode.terminal").set_state({
            provider = self,
            job_id = self.job_id,
            bufnr = self.bufnr,
            channel = channel,
          })
        end
      end
    end)

    -- Set initial state with job_id as channel (will be updated above)
    require("claudecode.terminal").set_state({
      provider = self,
      job_id = self.job_id,
      bufnr = self.bufnr,
      channel = channel,
    })

    vim.api.nvim_set_current_win(previous_win)
  end
end

---Close the window, delete the buffer.
function Terminal:stop()
  if self.winid ~= nil and vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
    self.winid = nil
  end
  if self.bufnr ~= nil and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end
  self.job_id = nil
  require("claudecode.terminal").clear_state()
end

return Terminal
