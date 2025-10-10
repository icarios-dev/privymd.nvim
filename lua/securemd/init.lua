local Gpg = require("securemd.gpg")

local M = {}

function M.setup()
	vim.api.nvim_create_user_command("ToggleGpgBlock", Gpg.toggle, {})
	vim.keymap.set("n", "<leader>gt", Gpg.toggle, { desc = "Basculer bloc GPG" })
end

return M
