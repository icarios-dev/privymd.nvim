local Block = require("privymd.block")
local GPG = require("privymd.gpg_async")
local Front = require("privymd.frontmatter")
local Progress = require("privymd.progress")
local log = require("privymd.utils.logger")
log.set_log_level("debug")

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

function M.decrypt_buffer(config)
	log.trace("Decrypting buffer...")
	local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local blocks = Block.find_blocks(text)

	if #blocks == 0 then
		log.trace("No GPG blocks found.")
		return
	end

	vim.schedule(function()
		log.info("Decrypting GPG blocks...")
	end)

	local passphrase = get_passphrase()
	if config and config.progress then
		Progress.start(#blocks, "Decrypting GPG blocks…")
	end

	-- 🔒 Sauvegarde de l'état initial
	local bufnr = vim.api.nvim_get_current_buf()
	local modified_before = vim.bo.modified
	vim.bo.modified = false

	-- Exécution séquentielle pour éviter les corruptions
	local i = 1
	local function decrypt_next()
		local block = blocks[i]
		if not block then
			if config and config.progress then
				Progress.stop("Decryption complete ✔")
			end
			-- Restaure l'état "non modifié"
			vim.bo[bufnr].modified = modified_before
			return
		end

		GPG.decrypt_async(block.content, passphrase, function(plaintext)
			if plaintext then
				-- ⚙️ Mise à jour synchrone du buffer
				vim.schedule(function()
					Block.set_block_content(block.start, block.end_, plaintext)
					if config and config.progress then
						Progress.update(i)
					end
					i = i + 1
					decrypt_next()
				end)
			else
				log.error("Failed to decrypt block " .. i)
				i = i + 1
				decrypt_next()
			end
		end)
	end

	decrypt_next()
end

function M.encrypt_text(text, recipient, config)
	log.trace("Chiffrement du buffer…")
	local blocks = Block.find_blocks(text)

	if #blocks == 0 then
		log.trace("Aucun bloc GPG détecté.")
		return
	end

	if not recipient then
		log.trace("Pas de destinataire de chiffrement défini.")
		return
	end

	if config and config.progress then
		Progress.start(#blocks, "Encrypting GPG blocks…")
	end

	for index, block in ipairs(blocks) do
		local ciphertext = GPG.encrypt_sync(block.content, recipient)
		if not ciphertext then
			log.error("Échec du chiffrement du bloc.")
			return
		end
		if config and config.progress then
			Progress.update(index)
		end
		text = Block.set_block_content(block.start, block.end_, ciphertext, text)
	end

	if config and config.progress then
		Progress.stop("Encryption complete ✔")
	end
	return text
end

function M.save_buffer(buf_lines)
	if not buf_lines or #buf_lines == 0 then
		log.error("Aucune donnée à écrire (buffer vide ou invalide).")
		return
	end
	local filename = vim.api.nvim_buf_get_name(0)
	local ok, err = pcall(vim.fn.writefile, buf_lines, filename)
	if not ok then
		log.error("Erreur d'écriture : " .. tostring(err))
		return
	end

	-- Marque le buffer comme sauvegardé
	vim.bo.modified = false
end

function M.encrypt_and_save_buffer(config)
	-- Crée une copie du buffer pour construire le texte chiffré
	local plaintext = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local recipient = Front.get_file_recipient()
	local blocks = Block.find_blocks(plaintext)
	local ciphertext

	if #blocks == 0 then
		M.save_buffer(plaintext)
		return
	elseif #blocks ~= 0 and not recipient then
		-- ⚠️ Warning and confirmation prompt
		local choice = vim.fn.confirm(
			"⚠️ No GPG recipient found in the front matter.\n"
				.. "The file will be saved unencrypted.\n\n"
				.. "Do you want to continue?",
			"&Yes\n&No",
			2 -- default: No
		)

		if choice ~= 1 then
			log.info("Save cancelled.")
			return
		end

		-- Continue without encryption
		M.save_buffer(plaintext)
		return
	end

	-- Normal encryption
	ciphertext = M.encrypt_text(plaintext, recipient, config)
	M.save_buffer(ciphertext)
	log.info("Fichier chiffré écrit, buffer conservé en clair.")
end

-- 🧹 Réinitialiser le cache de passphrase (optionnel)
function M.clear_passphrase()
	_cached_passphrase = nil
	log.info("Passphrase oubliée de la session.")
end

return M
