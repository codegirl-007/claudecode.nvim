local M = {}

function M.check()
  vim.health.start("claudecode.nvim")

  -- Check for claude binary
  if vim.fn.executable("claude") == 1 then
    vim.health.ok("`claude` executable found")
  else
    vim.health.error("`claude` executable not found", {
      "Install Claude Code: https://claude.ai/download",
      "Make sure `claude` is in your PATH",
    })
  end

  -- Check autoread setting
  if vim.o.autoread then
    vim.health.ok("`autoread` is enabled")
  else
    vim.health.warn("`autoread` is not enabled", {
      "Set `vim.o.autoread = true` to enable automatic buffer reloading when Claude edits files",
    })
  end

  -- Check provider
  local config = require("claudecode.config")
  if config.provider then
    vim.health.ok("Provider configured: " .. (config.provider.name or "custom"))

    -- Check provider health
    if config.provider.health then
      local ok, err, advice = config.provider.health()
      if ok == true then
        vim.health.ok("Provider health check passed")
      else
        vim.health.warn("Provider health check: " .. (err or "unknown error"), advice)
      end
    end
  else
    vim.health.warn("No provider configured", {
      "Configure a provider in `vim.g.claudecode_opts.provider`",
    })
  end

  -- Check terminal state
  local terminal = require("claudecode.terminal")
  if terminal.is_active() then
    vim.health.ok("Claude terminal is active")
  else
    vim.health.info("Claude terminal is not currently running")
  end
end

return M
