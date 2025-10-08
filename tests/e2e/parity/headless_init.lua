local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = vim.fn.fnamemodify(script_path, ":p:h")
local repo_root = vim.fn.fnamemodify(script_dir, ":h:h:h")

vim.opt.runtimepath:append(repo_root)

require("nvim-eslint").setup({})
