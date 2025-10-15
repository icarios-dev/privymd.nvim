-- Charge plenary + environnement de test busted
vim.cmd("set rtp^=" .. vim.fn.fnamemodify(".", ":p"))
vim.cmd("set rtp^=" .. vim.fn.stdpath("data") .. "/lazy/plenary.nvim")
require("plenary.busted")

-- Rendre les notifs silencieuses
vim.notify = function(msg, _)
	vim.api.nvim_echo({ { msg, "Normal" } }, true, {})
end

-- Désactive les autocommands d’E/S pendant les tests
local ok, privymd = pcall(require, "privymd")
if ok then
	privymd.setup({
		auto_decrypt = false,
		auto_encrypt = false,
	})
end
