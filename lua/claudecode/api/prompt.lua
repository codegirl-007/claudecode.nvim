local M = {}

---@class claudecode.api.prompt.Opts
---@field submit? boolean Submit the prompt immediately (default true for terminal).
---@field context? claudecode.Context The context the prompt is being made in.

---Prompt `claude`.
---
--- - Resolves `prompt` if it references an `opts.prompts` entry by name.
--- - Injects `opts.contexts` into `prompt`.
---
---@param prompt string
---@param opts? claudecode.api.prompt.Opts
function M.prompt(prompt, opts)
  local referenced_prompt = require("claudecode.config").opts.prompts[prompt]
  prompt = referenced_prompt and referenced_prompt.prompt or prompt
  opts = {
    submit = opts and opts.submit ~= nil and opts.submit or true,
    context = opts and opts.context or require("claudecode.context").new(),
  }

  require("claudecode.terminal")
    .ensure_terminal()
    :next(function(terminal_state)
      -- Render context placeholders
      local rendered = opts.context:render(prompt)
      local plaintext = opts.context.plaintext(rendered.output)

      -- Small delay to ensure Claude Code is ready to receive input
      vim.defer_fn(function()
        -- Send to terminal
        if opts.submit then
          require("claudecode.cli.client").send_line(plaintext)
        else
          require("claudecode.cli.client").send(plaintext)
        end
        opts.context:clear()
      end, 100)  -- 100ms delay

      return terminal_state
    end)
    :catch(function(err)
      vim.notify(err, vim.log.levels.ERROR, { title = "claudecode" })
      opts.context:clear()
      return true
    end)
end

return M
