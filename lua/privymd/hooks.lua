local Block = require("privymd.block")
local GPG = require("privymd.gpg_async")
local Front = require("privymd.frontmatter")
local log = require("privymd.utils.logger")
log.set_log_level("trace")

local M = {}

-- cache local de la passphrase pour la session
local _cached_passphrase = nil

-- 🔐 Demande (ou récupère du cache) la passphrase
local function get_passphrase()
	if _cached_passphrase then
		return _cached_passphrase
	end
	_cached_passphrase = vim.fn.inputsecret("Passphrase GPG : ")
	return _cached_passphrase
end

function M.decrypt_buffer()
	log.trace("Déchiffrement du buffer")
	local blocks = Block.find_blocks()

	if #blocks == 0 then
		log.trace("Aucun bloc trouvé.")
		return
	end

	vim.schedule(function()
		log.info("Déchiffrement des blocs GPG en cours…")
	end)

	local passphrase = get_passphrase()

	for _, block in ipairs(blocks) do
		log.trace("Déhiffre le bloc " .. _ .. "…")
		GPG.decrypt_async(block.content, passphrase, function(plaintext)
			if plaintext then
				Block.set_block_content(block.start, block["end"], plaintext)
			end
		end)
	end
end

function M.encrypt_buffer()
	log.trace("Chiffrement du buffer…")
	local blocks = Block.find_blocks()

	if #blocks == 0 then
		log.trace("Aucun bloc trouvé.")
		return
	end

	local recipient = Front.get_file_recipient()
	if not recipient then
		log.trace("Pas de destinataire de chiffrement défini.")
		return
	end
	log.debug("Recipient: " .. recipient)

	-- Crée une copie du buffer pour construire le texte chiffré
	local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	for _, block in ipairs(blocks) do
		local ciphertext = GPG.encrypt_sync(block.content, recipient)
		if ciphertext then
			Block.set_block_content(block.start, block["end"], ciphertext, buf_lines)
		else
			log.error("Échec du chiffrement du bloc.")
		end
	end

	M.save_buffer(buf_lines)
end

function M.save_buffer(buffer)
	local filename = vim.api.nvim_buf_get_name(0)
	local ok, err = pcall(vim.fn.writefile, buffer, filename)
	if not ok then
		log.error("Erreur d'écriture du fichier : " .. tostring(err))
	end
	-- Empêche Neovim d’écrire à nouveau (évite double-écriture)
	vim.cmd("setlocal nomodified")
end

-- 🧹 Réinitialiser le cache de passphrase (optionnel)
function M.clear_passphrase()
	_cached_passphrase = nil
	log.info("Passphrase oubliée de la session.")
end

return M
