vim.api.nvim_create_autocmd("VimLeave", {
  group = vim.api.nvim_create_augroup("ClaudecodeProvider", { clear = true }),
  pattern = "*",
  callback = function()
    pcall(require("claudecode.provider").stop)
  end,
  desc = "Stop `claude` provider on exit",
})
