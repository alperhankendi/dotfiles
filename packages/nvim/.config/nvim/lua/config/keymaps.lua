-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Toggle system clipboard on/off
vim.keymap.set("n", "<leader>c", function()
  if vim.o.clipboard == "" then
    vim.o.clipboard = "unnamedplus"
    vim.notify("📋 Clipboard enabled", vim.log.levels.INFO, { title = "Clipboard" })
  else
    vim.o.clipboard = ""
    vim.notify("🚫 Clipboard disabled", vim.log.levels.WARN, { title = "Clipboard" })
  end
end, { desc = "Toggle clipboard" })
