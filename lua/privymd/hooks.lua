local Block = require("privymd.block")
local Gpg = require("privymd.gpg")
local Front = require("privymd.frontmatter")
local log = require("privymd.utils.logger")
-- log.set_log_level("debug")

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

---------------------------------------------------------------------
-- 🔓 Decrypt a single block
---------------------------------------------------------------------
local function decrypt_block(block, passphrase, on_done)
	if not block or not Block.is_encrypted(block) then
		if on_done then
			on_done()
		end
		return
	end

	Gpg.decrypt_async(block.content, passphrase, function(plaintext)
		vim.schedule(function()
			if not plaintext then
				log.error("Failed to decrypt block.")
				if on_done then
					on_done()
				end
				return
			end

			Block.set_block_content(block.start, block.end_, plaintext)
			if on_done then
				on_done()
			end
		end)
	end)
end

---------------------------------------------------------------------
-- 🔒 Encrypt a single block
---------------------------------------------------------------------
local function encrypt_block(block, recipient, text)
	if not block or Block.is_encrypted(block) then
		return
	end

	local ciphertext = Gpg.encrypt_sync(block.content, recipient)
	if not ciphertext then
		log.error("Encryption failed for current block.")
		return
	end

	return Block.set_block_content(block.start, block.end_, ciphertext, text)
end

---------------------------------------------------------------------
-- End Helpers
---------------------------------------------------------------------

function M.decrypt_buffer()
	if not Gpg.is_gpg_available() then
		log.warn("GPG non disponible — déchiffrement annulé.")
		return
	end
	log.trace("Decrypting buffer...")
	local bufnr = vim.api.nvim_get_current_buf()
	local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local blocks = Block.find_blocks(text)

	if #blocks == 0 then
		log.trace("No GPG blocks found.")
		return
	end

	local passphrase = get_passphrase()
	local modified_before = vim.bo.modified
	vim.bo[bufnr].modified = false

	local i = 1

	local function decrypt_next()
		local block = blocks[i]
		if not block then
			vim.bo[bufnr].modified = modified_before
			log.info("All blocks decrypted")
			return
		end

		decrypt_block(block, passphrase, function()
			i = i + 1
			decrypt_next()
		end)
	end

	decrypt_next()
end

function M.encrypt_text(text, recipient)
	if not Gpg.is_gpg_available() then
		log.warn("GPG non disponible — chiffrement annulé.")
		return
	end
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

	for _, block in ipairs(blocks) do
		local new_text = encrypt_block(block, recipient, text)
		if not new_text then
			log.error(("Skipping block %d: encryption failed."):format(block.start))
		end
		text = new_text
	end

	log.info("Encryption complete ✔")
	return text
end

function M.save_buffer(buf_lines)
	if type(buf_lines) ~= "table" or #buf_lines == 0 then
		log.error("Aucune donnée à écrire (buffer vide ou invalide).")
		return
	end
	local filename = vim.api.nvim_buf_get_name(0)
	local ok, err = pcall(vim.fn.writefile, buf_lines, filename)
	if not ok then
		log.error("Erreur d'écriture : " .. tostring(err))
		return
	end

	log.info("Fichier chiffré écrit, buffer conservé en clair.")
	-- Marque le buffer comme sauvegardé
	vim.bo.modified = false
end

function M.encrypt_and_save_buffer()
	-- Crée une copie du buffer pour construire le texte chiffré
	local plaintext = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local recipient = Front.get_file_recipient()
	local blocks = Block.find_blocks(plaintext)
	local ciphertext

	if #blocks == 0 then
		M.save_buffer(plaintext)
		return
	elseif #blocks > 0 and not recipient then
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
	ciphertext = M.encrypt_text(plaintext, recipient)
	M.save_buffer(ciphertext)
end

-- 🧹 Réinitialiser le cache de passphrase (optionnel)
function M.clear_passphrase()
	_cached_passphrase = nil
	log.info("Passphrase oubliée de la session.")
end

---------------------------------------------------------------------
-- 🔁 Toggle encryption/decryption for the block under cursor
---------------------------------------------------------------------
function M.toggle_encryption()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local text = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local blocks = Block.find_blocks(text)
	if #blocks == 0 then
		log.info("No GPG blocks found.")
		return
	end

	-- find the block under cursor
	local target
	for _, block in ipairs(blocks) do
		if cursor_line >= block.start and cursor_line <= block.end_ then
			target = block
			break
		end
	end
	if not target then
		log.warn("Cursor not inside a GPG block.")
		return
	end

	local modified_before = vim.bo[bufnr].modified
	vim.bo[bufnr].modified = false

	if Block.is_encrypted(target) then
		local passphrase = get_passphrase()
		decrypt_block(target, passphrase)
	else
		local recipient = Front.get_file_recipient()
		if not recipient then
			return
		end
		encrypt_block(target, recipient)
	end

	vim.bo[bufnr].modified = modified_before
end

return M
