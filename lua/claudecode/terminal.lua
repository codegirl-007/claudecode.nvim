---Terminal state management for Claude Code.
---Replaces the HTTP port-based server discovery with terminal job tracking.

local M = {}

---@class claudecode.terminal.State
---@field provider claudecode.Provider|nil The provider instance
---@field job_id number|nil The Neovim job ID
---@field bufnr number|nil The terminal buffer number
---@field channel number|nil The terminal channel for stdin

---@type claudecode.terminal.State
local state = {
  provider = nil,
  job_id = nil,
  bufnr = nil,
  channel = nil,
}

---File watcher handle for auto-reload
---@type uv_fs_event_t|nil
local fs_watcher = nil

---Directories to ignore when watching for file changes
local IGNORE_PATTERNS = {
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
}

---Check if a path should be ignored
---@param path string
---@return boolean
local function should_ignore(path)
  for _, pattern in ipairs(IGNORE_PATTERNS) do
    if path:match(pattern) then
      return true
    end
  end
  return false
end

---Start watching for file changes
local function start_file_watcher()
  if fs_watcher then
    return -- Already watching
  end

  local cwd = vim.fn.getcwd()
  fs_watcher = vim.uv.new_fs_event()

  if not fs_watcher then
    return
  end

  fs_watcher:start(cwd, { recursive = true }, function(err, filename)
    if err then
      return
    end

    -- Skip ignored directories
    if filename and should_ignore(filename) then
      return
    end

    -- Schedule checktime on main thread
    vim.schedule(function()
      if vim.o.autoread then
        vim.cmd("checktime")
      end
    end)
  end)
end

---Stop watching for file changes
local function stop_file_watcher()
  if fs_watcher then
    fs_watcher:stop()
    fs_watcher = nil
  end
end

---Get the current terminal state.
---@return claudecode.terminal.State
function M.get_state()
  return state
end

---Update the terminal state.
---@param updates claudecode.terminal.State
function M.set_state(updates)
  state = vim.tbl_extend("force", state, updates)

  -- Start file watcher when terminal becomes active
  if state.channel then
    start_file_watcher()
  else
    stop_file_watcher()
  end
end

---Clear the terminal state.
function M.clear_state()
  state = {
    provider = nil,
    job_id = nil,
    bufnr = nil,
    channel = nil,
  }
  stop_file_watcher()
end

---Check if the terminal is active and valid.
---@return boolean
function M.is_active()
  if not state.bufnr then
    return false
  end

  -- Check if buffer is still valid
  if not vim.api.nvim_buf_is_valid(state.bufnr) then
    M.clear_state()
    return false
  end

  return state.channel ~= nil
end

---Send text to the terminal stdin.
---@param text string The text to send
---@return boolean success
function M.send(text)
  if not M.is_active() then
    vim.notify("Claude terminal not active", vim.log.levels.WARN, { title = "claudecode" })
    return false
  end

  local ok, err = pcall(vim.fn.chansend, state.channel, text)
  if not ok then
    vim.notify("Failed to send to terminal: " .. tostring(err), vim.log.levels.ERROR, { title = "claudecode" })
    return false
  end
  return true
end

---Send text with Enter key to submit it.
---@param text string The text to send
---@return boolean success
function M.send_line(text)
  if not M.is_active() then
    vim.notify("Claude terminal not active", vim.log.levels.WARN, { title = "claudecode" })
    return false
  end

  -- Find the terminal window
  local term_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == state.bufnr then
      term_win = win
      break
    end
  end

  if term_win then
    local current_win = vim.api.nvim_get_current_win()

    -- Focus terminal and enter terminal mode
    vim.api.nvim_set_current_win(term_win)
    vim.cmd("startinsert")

    -- Use vim.schedule to ensure we're in terminal mode, then use nvim_input
    vim.schedule(function()
      -- nvim_input sends keys immediately to the input queue
      vim.api.nvim_input(text)

      -- Send Enter after a small delay
      vim.defer_fn(function()
        vim.api.nvim_input(vim.api.nvim_replace_termcodes("<CR>", true, false, true))

        -- Return focus after Enter is processed
        vim.defer_fn(function()
          vim.cmd("stopinsert")
          pcall(vim.api.nvim_set_current_win, current_win)
        end, 150)
      end, 50)
    end)

    return true
  else
    -- Fallback to chansend if no terminal window found
    local ok, err = pcall(vim.fn.chansend, state.channel, text .. "\r")
    if not ok then
      vim.notify("Failed to send to terminal: " .. tostring(err), vim.log.levels.ERROR, { title = "claudecode" })
      return false
    end
    return true
  end
end

---Debug function to test different Enter key sequences.
---@param text string The text to send
---@param enter_char string The Enter character to use ("\\n", "\\r", "\\r\\n", or "\\x0d")
function M.debug_send(text, enter_char)
  if not M.is_active() then
    vim.notify("Claude terminal not active", vim.log.levels.WARN, { title = "claudecode" })
    return false
  end

  local enter_map = {
    ["\\n"] = "\n",
    ["\\r"] = "\r",
    ["\\r\\n"] = "\r\n",
    ["\\x0d"] = "\x0d",
    ["\\x0a"] = "\x0a",
  }

  local enter = enter_map[enter_char] or enter_char
  vim.notify("Sending: '" .. text .. "' + enter char: " .. enter_char, vim.log.levels.INFO, { title = "claudecode" })

  local ok, err = pcall(vim.fn.chansend, state.channel, text .. enter)
  if not ok then
    vim.notify("Failed: " .. tostring(err), vim.log.levels.ERROR, { title = "claudecode" })
    return false
  end
  return true
end

---Debug function to print current terminal state and test chansend.
function M.debug_state()
  print("=== Terminal State Debug ===")
  print("state.bufnr: " .. vim.inspect(state.bufnr))
  print("state.job_id: " .. vim.inspect(state.job_id))
  print("state.channel: " .. vim.inspect(state.channel))

  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    print("Buffer is valid: true")
    local ok, term_job_id = pcall(vim.api.nvim_buf_get_var, state.bufnr, "terminal_job_id")
    if ok then
      print("Buffer terminal_job_id: " .. vim.inspect(term_job_id))
    else
      print("Buffer terminal_job_id: NOT SET")
    end
  else
    print("Buffer is valid: false")
  end

  print("is_active(): " .. tostring(M.is_active()))
  print("============================")
end

---Type text in terminal but don't press Enter (for debugging).
---Focus stays on terminal so you can manually press Enter.
function M.debug_type_only(text)
  if not M.is_active() then
    vim.notify("Terminal not active", vim.log.levels.WARN)
    return
  end

  local term_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == state.bufnr then
      term_win = win
      break
    end
  end

  if term_win then
    vim.api.nvim_set_current_win(term_win)
    vim.cmd("startinsert")
    vim.schedule(function()
      vim.api.nvim_input(text)
      vim.notify("Text typed. You're in terminal mode - press Enter manually to test.", vim.log.levels.INFO)
    end)
  end
end

---Test sending Enter key only (no text).
function M.debug_enter_only()
  if not M.is_active() then
    vim.notify("Terminal not active", vim.log.levels.WARN)
    return
  end
  print("Testing Enter key sequences on channel: " .. state.channel)

  -- Test each Enter sequence
  for _, seq in ipairs({ "\n", "\r", "\x0d", "\x0a" }) do
    local name = seq == "\n" and "\\n" or seq == "\r" and "\\r" or seq == "\x0d" and "\\x0d" or "\\x0a"
    print("Trying: " .. name)
    local ok, err = pcall(vim.fn.chansend, state.channel, seq)
    print("  Result: " .. (ok and "OK" or ("ERROR: " .. tostring(err))))
    vim.cmd("sleep 200m")  -- Wait 200ms between tests
  end
end

---Poll for terminal to be ready.
---@param callback fun(ok: boolean, state: claudecode.terminal.State|string)
local function poll_for_terminal(callback)
  local retries = 0
  local max_retries = 10
  local timer = vim.uv.new_timer()

  timer:start(
    100, -- Initial delay
    200, -- Repeat interval
    vim.schedule_wrap(function()
      retries = retries + 1

      if M.is_active() then
        timer:stop()
        timer:close()
        callback(true, state)
      elseif retries >= max_retries then
        timer:stop()
        timer:close()
        callback(false, "Terminal did not become ready")
      end
    end)
  )
end

---Ensure terminal is running, starting it if needed.
---@return claudecode.Promise
function M.ensure_terminal()
  return require("claudecode.promise").new(function(resolve, reject)
    -- Already active
    if M.is_active() then
      resolve(state)
      return
    end

    -- Get provider from config
    local provider = require("claudecode.config").provider
    if not provider then
      reject("No provider configured")
      return
    end

    -- Start the provider
    provider:start()

    -- Poll for terminal to be ready
    poll_for_terminal(function(ok, result)
      if ok then
        resolve(result)
      else
        reject(result)
      end
    end)
  end)
end

---Get terminal (alias for ensure_terminal for API compatibility).
---@param launch? boolean Whether to launch if not running (default true)
---@return claudecode.Promise
function M.get_terminal(launch)
  if launch == false and not M.is_active() then
    return require("claudecode.promise").new(function(_, reject)
      reject("Terminal not running")
    end)
  end
  return M.ensure_terminal()
end

return M
