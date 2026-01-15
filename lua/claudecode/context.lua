---@module 'snacks.picker'

---The context a prompt is being made in.
---Particularly useful when inputting or selecting a prompt
---because that changes the active mode, window, etc.
---So this stores state prior to that.
---@class claudecode.Context
---@field win integer
---@field buf integer
---@field cursor integer[] The cursor positon. { row, col } (1,0-based).
---@field range? claudecode.context.Range The operator range or visual selection range.
local Context = {}
Context.__index = Context

local ns_id = vim.api.nvim_create_namespace("ClaudecodeContext")

local function is_buf_valid(buf)
  return vim.api.nvim_get_option_value("buftype", { buf = buf }) == "" and vim.api.nvim_buf_get_name(buf) ~= ""
end

local function last_used_valid_win()
  local last_used_win = 0
  local latest_last_used = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if is_buf_valid(buf) then
      local last_used = vim.fn.getbufinfo(buf)[1].lastused or 0
      if last_used > latest_last_used then
        latest_last_used = last_used
        last_used_win = win
      end
    end
  end
  return last_used_win
end

---@class claudecode.context.Range
---@field from integer[] { line, col } (1,0-based)
---@field to integer[] { line, col } (1,0-based)
---@field kind "char"|"line"|"block"

---@param buf integer
---@return claudecode.context.Range|nil
local function selection(buf)
  local mode = vim.fn.mode()
  local kind = (mode == "V" and "line") or (mode == "v" and "char") or (mode == "\22" and "block")
  if not kind then
    return nil
  end

  -- Exit visual mode for consistent marks
  if vim.fn.mode():match("[vV\22]") then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", true)
  end

  local from = vim.api.nvim_buf_get_mark(buf, "<")
  local to = vim.api.nvim_buf_get_mark(buf, ">")
  if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
    from, to = to, from
  end

  return {
    from = { from[1], from[2] },
    to = { to[1], to[2] },
    kind = kind,
  }
end

---@param buf integer
---@param range claudecode.context.Range
local function highlight(buf, range)
  local end_row = range.to[1] - (range.kind == "line" and 0 or 1)
  local end_col = nil
  if range.kind ~= "line" then
    local line = vim.api.nvim_buf_get_lines(buf, end_row, end_row + 1, false)[1] or ""
    end_col = math.min(range.to[2] + 1, #line)
  end
  vim.api.nvim_buf_set_extmark(buf, ns_id, range.from[1] - 1, range.from[2], {
    end_row = end_row,
    end_col = end_col,
    hl_group = "Visual",
  })
end

---@param range? claudecode.context.Range The range of the operator or visual selection. Defaults to current visual selection, if any.
function Context.new(range)
  local self = setmetatable({}, Context)
  self.win = last_used_valid_win()
  self.buf = vim.api.nvim_win_get_buf(self.win)
  self.cursor = vim.api.nvim_win_get_cursor(self.win)
  self.range = range or selection(self.buf)
  if self.range then
    highlight(self.buf, self.range)
  end
  return self
end

function Context:clear()
  vim.api.nvim_buf_clear_namespace(self.buf, ns_id, 0, -1)
end

function Context:resume()
  self:clear()
  if self.range ~= nil then
    vim.cmd("normal! gv")
  end
end

---Render `opts.contexts` in `prompt`.
---@param prompt string
---@return { input: snacks.picker.Text[], output: snacks.picker.Text[] }
function Context:render(prompt)
  local contexts = require("claudecode.config").opts.contexts or {}
  local context_placeholders = vim.tbl_keys(contexts)
  table.sort(context_placeholders, function(a, b)
    return #a > #b -- longest first, in case some overlap
  end)

  ---@type table<string, { input: (fun(): snacks.picker.Text), output: (fun(): snacks.picker.Text) }>
  local placeholders = {}
  for _, context_placeholder in ipairs(context_placeholders) do
    placeholders[context_placeholder] = {
      input = function()
        return { context_placeholder, "ClaudecodeContextPlaceholder" }
      end,
      output = function()
        local value = contexts[context_placeholder](self)
        if value then
          return { value, "ClaudecodeContextValue" }
        else
          return { context_placeholder, "ClaudecodeContextPlaceholder" }
        end
      end,
    }
  end

  local input, output = {}, {}
  local i = 1
  while i <= #prompt do
    -- Find the next placeholder and its position
    local next_pos, next_placeholder = #prompt + 1, nil
    for placeholder in pairs(placeholders) do
      local pos = prompt:find(placeholder, i, true)
      if pos and pos < next_pos then
        next_pos = pos
        next_placeholder = placeholder
      end
    end

    -- Add plain text before the next placeholder
    local text = prompt:sub(i, next_pos - 1)
    if #text > 0 then
      table.insert(input, { text })
      table.insert(output, { text })
    end

    -- If a placeholder is found, replace it with its value
    if next_placeholder then
      table.insert(input, placeholders[next_placeholder].input())
      table.insert(output, placeholders[next_placeholder].output())
      i = next_pos + #next_placeholder
    else
      -- No more placeholders, break
      break
    end
  end

  return {
    input = input,
    output = output,
  }
end

---Convert rendered context to plaintext.
---@param rendered snacks.picker.Text[]
---@return string
function Context.plaintext(rendered)
  return table.concat(vim.tbl_map(
    ---@param part snacks.picker.Text
    function(part)
      return part[1]
    end,
    rendered
  ))
end

---Convert rendered context to extmarks.
---Handles multiline parts.
---@param rendered snacks.picker.Text[]
---@return snacks.picker.Extmark[]
function Context.extmarks(rendered)
  local row = 1
  local col = 1
  local extmarks = {}
  for _, part in ipairs(rendered) do
    local part_text = part[1]
    local part_hl = part[2] or nil
    local segments = vim.split(part_text, "\n", { plain = true })
    for i, segment in ipairs(segments) do
      if i > 1 then
        row = row + 1
        col = 1
      end
      ---@type snacks.picker.Extmark
      if part_hl then
        local extmark = {
          row = row,
          col = col - 1,
          end_col = col + #segment - 1,
          hl_group = part_hl,
        }
        table.insert(extmarks, extmark)
      end
      col = col + #segment
    end
  end
  return extmarks
end

---Get the relative file path for a buffer.
---@param buf integer
---@return string|nil
local function get_rel_path(buf)
  if not is_buf_valid(buf) then
    return nil
  end
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
end

---Get the filetype for a buffer.
---@param buf integer
---@return string
local function get_filetype(buf)
  return vim.bo[buf].filetype or ""
end

---Get lines from a buffer.
---@param buf integer
---@param start_line integer 1-based
---@param end_line integer 1-based
---@return string[]
local function get_lines(buf, start_line, end_line)
  return vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
end

---Format code as a markdown code block.
---@param code string|string[]
---@param filetype string
---@return string
local function format_code_block(code, filetype)
  local content = type(code) == "table" and table.concat(code, "\n") or code
  return string.format("```%s\n%s\n```", filetype, content)
end

---Range if present (with actual code), else cursor position reference.
---This is the key change from opencode: we include actual code content
---instead of just line references, because Claude Code doesn't support
---the L21:C10 line range syntax.
function Context:this()
  local rel_path = get_rel_path(self.buf)
  local filetype = get_filetype(self.buf)

  if self.range then
    -- Get the actual code content from the buffer
    local lines = get_lines(self.buf, self.range.from[1], self.range.to[1])
    local code_block = format_code_block(lines, filetype)

    if rel_path then
      return string.format(
        "@%s (lines %d-%d):\n%s",
        rel_path,
        self.range.from[1],
        self.range.to[1],
        code_block
      )
    else
      return string.format(
        "Selected code (lines %d-%d):\n%s",
        self.range.from[1],
        self.range.to[1],
        code_block
      )
    end
  else
    -- Just cursor position
    if rel_path then
      return string.format("@%s (around line %d)", rel_path, self.cursor[1])
    else
      return string.format("Current position: line %d", self.cursor[1])
    end
  end
end

---The current buffer reference.
function Context:buffer()
  local rel_path = get_rel_path(self.buf)
  if rel_path then
    return "@" .. rel_path
  end
  return nil
end

---All open buffers.
function Context:buffers()
  local file_list = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local path = get_rel_path(buf)
    if path then
      table.insert(file_list, "@" .. path)
    end
  end
  if #file_list == 0 then
    return nil
  end
  return table.concat(file_list, " ")
end

---The visible lines in all open windows (with actual content).
function Context:visible_text()
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if is_buf_valid(buf) then
      local start_line = vim.fn.line("w0", win)
      local end_line = vim.fn.line("w$", win)
      local rel_path = get_rel_path(buf)
      local filetype = get_filetype(buf)
      local lines = get_lines(buf, start_line, end_line)

      if rel_path and #lines > 0 then
        table.insert(visible, string.format(
          "@%s (visible lines %d-%d):\n%s",
          rel_path,
          start_line,
          end_line,
          format_code_block(lines, filetype)
        ))
      end
    end
  end
  if #visible == 0 then
    return nil
  end
  return table.concat(visible, "\n\n")
end

---Diagnostics for the current buffer (with code context).
function Context:diagnostics()
  local diagnostics = vim.diagnostic.get(self.buf)
  if #diagnostics == 0 then
    return nil
  end

  local rel_path = get_rel_path(self.buf)
  local file_ref = rel_path and ("@" .. rel_path) or "current buffer"

  local diagnostic_strings = {}
  for _, diagnostic in ipairs(diagnostics) do
    local line_num = diagnostic.lnum + 1
    local location = string.format("Line %d", line_num)

    -- Get the actual line of code for context
    local lines = get_lines(self.buf, line_num, line_num)
    local code_line = lines[1] or ""

    table.insert(
      diagnostic_strings,
      string.format(
        "- %s (%s): %s\n  Code: `%s`",
        location,
        diagnostic.source or "unknown",
        diagnostic.message:gsub("%s+", " "):gsub("^%s", ""):gsub("%s$", ""),
        code_line:gsub("^%s+", "")
      )
    )
  end

  return string.format(
    "%d diagnostics in %s:\n%s",
    #diagnostics,
    file_ref,
    table.concat(diagnostic_strings, "\n")
  )
end

---Formatted quickfix list entries.
function Context:quickfix()
  local qflist = vim.fn.getqflist()
  if #qflist == 0 then
    return nil
  end
  local lines = {}
  for _, entry in ipairs(qflist) do
    local has_buf = entry.bufnr ~= 0 and vim.api.nvim_buf_get_name(entry.bufnr) ~= ""
    if has_buf then
      local rel_path = get_rel_path(entry.bufnr)
      if rel_path then
        table.insert(lines, string.format("@%s line %d", rel_path, entry.lnum))
      end
    end
  end
  if #lines == 0 then
    return nil
  end
  return table.concat(lines, "\n")
end

---The git diff (unified diff format).
function Context:git_diff()
  local handle = io.popen("git --no-pager diff")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  if result and result ~= "" then
    return "Git diff:\n```diff\n" .. result .. "\n```"
  end
  return nil
end

---Global marks.
function Context:marks()
  local marks = {}
  for _, mark in ipairs(vim.fn.getmarklist()) do
    if mark.mark:match("^'[A-Z]$") then
      local buf = mark.pos[1]
      local rel_path = get_rel_path(buf)
      if rel_path then
        table.insert(marks, string.format("@%s line %d", rel_path, mark.pos[2]))
      end
    end
  end
  if #marks == 0 then
    return nil
  end
  return table.concat(marks, ", ")
end

---[`grapple.nvim`](https://github.com/cbochs/grapple.nvim) tags.
function Context:grapple_tags()
  local is_available, grapple = pcall(require, "grapple")
  if not is_available then
    return nil
  end
  local tags = grapple.tags()
  if not tags or #tags == 0 then
    return nil
  end
  local paths = {}
  for _, tag in ipairs(tags) do
    local rel_path = vim.fn.fnamemodify(tag.path, ":.")
    table.insert(paths, "@" .. rel_path)
  end
  return table.concat(paths, " ")
end

return Context
