return {
  "smoka7/hop.nvim",
  event = "VeryLazy", -- lazy-load after startup finishes
  config = function()
    require("hop").setup()
  end,
  keys = {
    { "s", "<cmd>HopChar2<CR>", mode = { "n", "v" }, desc = "Hop 2-char" },
  },
}

