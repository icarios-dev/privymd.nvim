local log = require("privymd.utils.logger")

local M = {}

---------------------------------------------------------------------
-- 🔍 Retrieve the GPG recipient from YAML front-matter (strict mode)
---------------------------------------------------------------------
function M.get_file_recipient()
	log.trace("Looking for recipient (strict YAML front-matter)…")

	-- lire seulement les premières lignes (inutile d’aller plus loin)
	local lines = vim.api.nvim_buf_get_lines(0, 0, 50, false)
	if #lines == 0 or not lines[1]:match("^%s*%-%-%-%s*$") then
		-- le fichier ne commence pas par un bloc YAML
		log.debug("No YAML front-matter detected (missing opening '---').")
		return nil
	end

	local recipient = nil
	for i = 2, #lines do
		local line = lines[i]

		-- fin du front-matter
		if line:match("^%s*%-%-%-%s*$") or line:match("^%s*%.%.%.%s*$") then
			break
		end

		-- recherche de la clé gpg-recipient
		local value = line:match("^%s*gpg%-recipient:%s*(.-)%s*$")
		if value and value ~= "" then
			recipient = value
			break
		end
	end

	if not recipient then
		log.warn("⚠️ No GPG recipient found in front-matter.")
		return nil
	end

	log.trace("Recipient found: " .. recipient)
	return recipient
end

return M
