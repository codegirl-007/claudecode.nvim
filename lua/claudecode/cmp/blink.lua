---Completion source for `blink.cmp`.
---Provides completions for context placeholders.

local M = {}

---@type claudecode.Context|nil
M.context = nil

---Setup the blink.cmp source.
function M.setup()
  local ok, blink = pcall(require, "blink.cmp")
  if not ok then
    return
  end

  -- Register the claudecode source
  blink.register_source("claudecode", {
    name = "claudecode",
    enabled = function()
      return vim.bo.filetype == "claudecode_ask"
    end,
    get_completions = function(self, ctx, callback)
      local items = {}

      -- Add context placeholders
      for placeholder in pairs(require("claudecode.config").opts.contexts or {}) do
        table.insert(items, {
          label = placeholder,
          filterText = placeholder,
          insertText = placeholder,
          insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
          kind = require("blink.cmp.types").CompletionItemKind.Variable,
        })
      end

      callback({
        items = items,
        is_incomplete_backward = false,
        is_incomplete_forward = false,
      })
    end,
    resolve = function(self, item, callback)
      item = vim.deepcopy(item)

      if M.context then
        local rendered = M.context:render(item.label)
        item.documentation = {
          kind = "plaintext",
          value = M.context.plaintext(rendered.output),
        }
      end

      callback(item)
    end,
  })
end

return M
