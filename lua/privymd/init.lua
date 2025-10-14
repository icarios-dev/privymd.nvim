local Block = require("privymd.block")
local Hooks = require("privymd.hooks")

local M = {}

M.config = {
	ft_pattern = "*.md",
	auto_decrypt = true,
	auto_encrypt = true,
	progress = true,
}

function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", M.config, opts)

	local pattern = opts.ft_pattern or M.config.ft_pattern

	-- Définition des autocommands
	if M.config.auto_decrypt then
		vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
			pattern = pattern,
			callback = function()
				Hooks.decrypt_buffer(M.config)
			end,
		})
	end

	if M.config.auto_encrypt then
		vim.api.nvim_create_autocmd("BufWriteCmd", {
			pattern = pattern,
			callback = function()
				Hooks.encrypt_and_save_buffer(M.config)
			end,
		})
	end

	-- Commandes utilisateur

	-- Force manual decryption of current buffer
	vim.api.nvim_create_user_command("PrivyDecrypt", function()
		Hooks.decrypt_buffer(M.config)
	end, {})

	-- Force manual encryption and save
	vim.api.nvim_create_user_command("PrivyEncrypt", function()
		Hooks.encrypt_and_save_buffer(M.config)
	end, {})

	-- Toggle decrypt/encrypt in memory (without saving)
	vim.api.nvim_create_user_command("PrivyToggle", function()
		Hooks.toggle_encryption(M.config)
	end, {})

	-- Debugging tools
	vim.api.nvim_create_user_command("PrivyMDShowBlocks", function()
		Block.debug_list_blocks()
	end, {})

	vim.api.nvim_create_user_command("PrivyMDClearPass", function()
		Hooks.clear_passphrase()
	end, {})
end

return M
