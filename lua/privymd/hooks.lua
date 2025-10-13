local Block = require("privymd.block")
local GPG = require("privymd.gpg_async")
local Front = require("privymd.frontmatter")
local log = require("privymd.utils.logger")
-- log.set_log_level("trace")

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

-- 🔓 Déchiffrement automatique à l’ouverture
function M.decrypt_on_open()
	log.trace("Déchiffrement automatique à l'ouverture")
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
		GPG.decrypt_async(block.content, passphrase, function(plaintext)
			if plaintext then
				Block.set_block_content(block.start, block["end"], plaintext)
			end
		end)
	end
end

-- 🔒 Chiffrement automatique à la sauvegarde
function M.encrypt_on_save()
	log.trace("Chiffrement avant sauvegarde…")
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

	for block_number, block in ipairs(blocks) do
		log.trace("Chiffre le bloc " .. block_number .. "…")
		log.debug(table.concat(block.content, "\n"))
		local ciphertext = GPG.encrypt_sync(block.content, recipient)

		if ciphertext then
			log.debug(table.concat(ciphertext, "\n"))
			log.trace("Remplace le texte en clair par le texte chiffré.")
			Block.set_block_content(block.start, block["end"], ciphertext)
		else
			log.error("Échec du chiffrement du bloc.")
		end
	end
end

-- 🧹 Réinitialiser le cache de passphrase (optionnel)
function M.clear_passphrase()
	_cached_passphrase = nil
	log.info("Passphrase oubliée de la session.")
end

return M
