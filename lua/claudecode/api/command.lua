local M = {}

---Claude Code slash commands.
---@alias claudecode.Command
---| 'clear'
---| 'compact'
---| 'config'
---| 'cost'
---| 'doctor'
---| 'help'
---| 'init'
---| 'login'
---| 'logout'
---| 'memory'
---| 'model'
---| 'permissions'
---| 'pr-comments'
---| 'review'
---| 'status'
---| 'terminal-setup'
---| string

---Execute a Claude Code slash command.
---
---@param command claudecode.Command|string
function M.command(command)
  require("claudecode.terminal")
    .ensure_terminal()
    :next(function()
      require("claudecode.cli.client").send_command(command)
    end)
    :catch(function(err)
      vim.notify(err, vim.log.levels.ERROR, { title = "claudecode" })
    end)
end

return M
