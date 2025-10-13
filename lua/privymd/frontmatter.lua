local log = require("privymd.utils.logger")

local M = {}

---------------------------------------------------------------------
-- 🔍 Récupère le destinataire GPG depuis le front-matter YAML
---------------------------------------------------------------------
function M.get_file_recipient()
	log.trace("Looking for recipient…")
	-- On lit les 100 premières lignes (suffisant pour tout front-matter)
	local lines = vim.api.nvim_buf_get_lines(0, 0, 100, false)
	local in_front_matter = false
	local recipient = nil

	for _, line in ipairs(lines) do
		-- détecte le bloc YAML (---) avec tolérance d'espaces
		if line:match("^%s*%-%-%-%s*$") then
			in_front_matter = not in_front_matter
			if not in_front_matter then
				break -- fin du header YAML
			end
		elseif in_front_matter then
			-- détecte la clé gpg-recipient
			local value = line:match("^%s*gpg%-recipient:%s*(.-)%s*$")
			if value and value ~= "" then
				recipient = value
			end
		end
	end

	if not recipient then
		log.warn("⚠️ Aucun gpg-recipient trouvé dans le front-matter.")
		return nil
	end

	log.trace("Recipient found.")
	return recipient
end

---------------------------------------------------------------------
-- 🧪 (Optionnel) récupérer toutes les métadonnées YAML
-- Utile si tu veux étendre la logique plus tard
---------------------------------------------------------------------
function M.get_all_metadata()
	local lines = vim.api.nvim_buf_get_lines(0, 0, 100, false)
	local in_front_matter = false
	local meta = {}

	for _, line in ipairs(lines) do
		if line:match("^%s*%-%-%-%s*$") then
			in_front_matter = not in_front_matter
			if not in_front_matter then
				break
			end
		elseif in_front_matter then
			local key, value = line:match("^%s*([%w%-%_]+):%s*(.-)%s*$")
			if key and value then
				meta[key] = value
			end
		end
	end

	return meta
end

return M
