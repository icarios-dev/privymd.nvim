local Block = require("privymd.block")
local Hooks = require("privymd.hooks")

local M = {}

function M.setup(opts)
	opts = opts or {}
	local pattern = opts.ft_pattern or "*.md"

	-- Définition des autocommands
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
		pattern = pattern,
		callback = function()
			Hooks.decrypt_buffer()
		end,
	})

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		pattern = pattern,
		callback = function()
			Hooks.encrypt_buffer()
		end,
	})

	-- Commandes utilisateur
	vim.api.nvim_create_user_command("PrivyMDShowBlocks", function()
		Block.debug_list_blocks()
	end, {})

	vim.api.nvim_create_user_command("PrivyMDClearPass", function()
		Hooks.clear_passphrase()
	end, {})
end

return M
