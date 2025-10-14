local log = require("privymd.utils.logger")
log.set_log_level("debug")

local M = {}

local fence_opening = "````gpg"
local fence_closing = "````"

-- 🔍 Trouve tous les blocs ````gpg```` d'un texte donné
function M.find_blocks(text)
	log.trace("Looking for blocks…")
	local blocks = {}

	local in_block = false
	local start_line, end_line, content

	for line_number, value in ipairs(text) do
		if value:match("^" .. fence_opening .. "$") and not in_block then
			in_block = true
			start_line = line_number
			content = {}
			log.trace("Fence opening : " .. start_line)
		elseif in_block then
			if value:match("^" .. fence_closing .. "$") and in_block then
				in_block = false
				end_line = line_number
				log.trace("Fence closing : " .. end_line)

				--[[ Reverse block collection to preserve line indices
        En insérant chaque bloc à la position 1, on garantit que les
        nouveaux blocs s’ajoutent avant les précédents. La liste finale
        est donc ordonnée du dernier au premier bloc dans le fichier.

        C’est crucial lors du remplacement : le texte chiffré n’ayant
        pas la même longueur que le texte en clair, les indices
        `start_line` et `end_line` deviendraient obsolètes dès le
        deuxième bloc si on traitait le fichier du haut vers le bas.
        ]]
				table.insert(blocks, 1, { start = start_line, end_ = end_line, content = content })
				log.debug(string.format("Block found between : %d and %d", start_line, end_line))
			else
				table.insert(content, value)
			end
		end
	end

	log.debug(#blocks .. " blocks found.")
	return blocks
end

-- Remplace le contenu d’un bloc : plain <=> cipher
function M.set_block_content(start_line, end_line, new_content, lines)
	if type(new_content) ~= "table" then
		log.error("Mauvais format de contenu à insérer.")
		return lines
	end

	-- construit le bloc
	local block_lines = { fence_opening }
	vim.list_extend(block_lines, new_content)
	table.insert(block_lines, fence_closing)

	-- Agit directement dans le buffer
	if not lines then
		vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, block_lines)
		return
	end

	-- Mode "hors buffer" : on agit sur une table Lua
	local new_lines = {}

	vim.list_extend(new_lines, vim.list_slice(lines, 1, start_line - 1))
	vim.list_extend(new_lines, block_lines)
	vim.list_extend(new_lines, vim.list_slice(lines, end_line + 1, #lines))

	return new_lines
end

-- 🔍 Débogage
function M.debug_list_blocks()
	local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local blocks = M.find_blocks(text)
	for index, block in ipairs(blocks) do
		print(string.format("Bloc %d : lignes %d-%d, %d lignes", index, block.start, block.end_, #block.content))
	end
end

-- 🔑 Vérifie si un bloc est chiffré (PGP)
function M.is_encrypted(block)
	if not block or not block.content or #block.content == 0 then
		return false
	end
	local first_line = block.content[1]
	return first_line:match("BEGIN%sPGP%sMESSAGE") ~= nil
end

return M
