local M = {}

-- trouve le bloc ```gpg``` autour du curseur
function M.find_block()
	local cur = vim.fn.line(".")
	local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	if not buf then
		return nil
	end

	local start_line, end_line, backticks
	for i = cur, 1, -1 do
		local line = buf[i]
		if not line then
			break
		end
		local fence, lang = line:match("^(`+)(%S*)")
		if fence and lang:match("gpg") then
			start_line = i + 1
			backticks = #fence
			break
		end
	end

	if not start_line then
		vim.notify("Pas de ligne d’ouverture ```gpg trouvée au-dessus du curseur.", vim.log.levels.WARN)
		return nil
	end

	for i = start_line + 1, #buf do
		local line = buf[i]
		if line and line:match("^" .. string.rep("`", backticks) .. "$") then
			end_line = i - 1
			break
		end
	end

	if not end_line then
		vim.notify("Bloc ```gpg trouvé à la ligne " .. start_line .. " mais sans fermeture.", vim.log.levels.WARN)
		return nil
	end

	return start_line, end_line
end

-- récupère uniquement le contenu entre les backticks
function M.get_content(start_content, end_content)
	local lines = {}
	for i = start_content, end_content do
		table.insert(lines, vim.fn.getline(i))
	end

	if #lines == 0 then
		vim.notify("Bloc vide ou invalide", vim.log.levels.WARN)
		return
	end

	return lines
end

-- remplace le contenu d’un bloc par de nouvelles lignes
function M.set_content(start_content, end_content, new_lines)
	vim.api.nvim_buf_set_lines(0, start_content - 1, end_content, false, new_lines)
end

return M
