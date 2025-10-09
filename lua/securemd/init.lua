local M = {}

-- 🔍 Crée un fichier temporaire sécurisé dans /tmp/username
local function create_tmpfile(content)
	local username = os.getenv("USER") or "user"
	local tmpdir = "/tmp/" .. username
	os.execute("mkdir -p " .. tmpdir)

	local tmpfile = tmpdir .. "/gpgbuf_" .. tostring(math.random(100000, 999999))
	local f, err = io.open(tmpfile, "w")
	if not f then
		vim.notify("Impossible de créer le fichier temporaire: " .. tostring(err), vim.log.levels.ERROR)
		return nil
	end
	f:write(content)
	f:close()
	os.execute("chmod 600 " .. tmpfile)
	return tmpfile
end

-- 🔍 trouve le bloc ```gpg``` autour du curseur
local function find_gpg_block()
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
		local bt, lang = line:match("^(`+)(%S*)")
		if bt and lang:match("gpg") then
			start_line = i
			backticks = #bt
			break
		end
	end

	if not start_line then
		return nil
	end

	for i = start_line + 1, #buf do
		local line = buf[i]
		if line and line:match("^`{" .. backticks .. "}$") then
			end_line = i
			break
		end
	end

	if not end_line or not backticks then
		return nil
	end
	return start_line, end_line, backticks
end

-- 🔍 vérifier si le bloc est chiffré
local function is_encrypted(start_line)
	if not start_line then
		return false
	end
	local first_content = vim.fn.getline(start_line + 1)
	return first_content and first_content:match("^%-%-%-BEGIN PGP MESSAGE%-%-%-") ~= nil
end

-- 🔍 lire l’option de chiffrement du bloc
local function get_block_mode(start_line)
	local line = vim.fn.getline(start_line)
	if not line then
		return "s"
	end
	local mode = line:match("%[mode:(%a)%]")
	if mode ~= "s" and mode ~= "c" then
		mode = "s"
	end
	return mode
end

-- 🔓 déchiffre en mémoire uniquement
local function decrypt_block_memory(start_line, end_line)
	local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line - 1, false)
	if not lines or #lines < 2 then
		vim.notify("Bloc vide ou invalide", vim.log.levels.WARN)
		return
	end

	local content = table.concat(lines, "\n", 2, #lines - 1)
	local tmpfile = create_tmpfile(content)
	if not tmpfile then
		return
	end

	local handle = io.popen("gpg --decrypt " .. tmpfile)
	if not handle then
		vim.notify("Erreur lors de l’exécution de gpg", vim.log.levels.ERROR)
		os.remove(tmpfile)
		return
	end

	local result = handle:read("*a")
	handle:close()
	os.remove(tmpfile)

	if result then
		vim.api.nvim_buf_set_lines(0, start_line, end_line - 1, false, vim.split(result, "\n"))
		vim.notify("Bloc déchiffré en mémoire ✅", vim.log.levels.INFO)
	end
end

-- 🔒 chiffre en mémoire avec mode mémorisé
local function encrypt_block_memory(start_line, end_line)
	local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line - 1, false)
	if not lines or #lines < 2 then
		vim.notify("Bloc vide ou invalide", vim.log.levels.WARN)
		return
	end

	local content = table.concat(lines, "\n", 2, #lines - 1)
	local tmpfile = create_tmpfile(content)
	if not tmpfile then
		return
	end

	local mode = get_block_mode(start_line)
	local cmd
	if mode == "c" then
		local recipient = vim.fn.input("ID GPG destinataire: ")
		cmd = string.format("gpg --encrypt --armor -r %s %s", recipient, tmpfile)
	else
		cmd = string.format("gpg --symmetric --armor %s", tmpfile)
	end

	local handle = io.popen(cmd)
	if not handle then
		vim.notify("Erreur lors de l’exécution de gpg", vim.log.levels.ERROR)
		os.remove(tmpfile)
		return
	end

	local result = handle:read("*a")
	handle:close()
	os.remove(tmpfile)

	if result then
		local new_lines = {}
		local line_start = vim.fn.getline(start_line)
		if line_start and not line_start:match("%[mode:") then
			line_start = line_start .. string.format(" [mode:%s]", mode)
		end
		new_lines[1] = line_start or lines[1]
		for line in result:gmatch("[^\r\n]+") do
			table.insert(new_lines, line)
		end
		new_lines[#new_lines + 1] = lines[#lines] -- backticks fin
		vim.api.nvim_buf_set_lines(0, start_line, end_line, false, new_lines)
		vim.notify("Bloc chiffré en mémoire 🔐 (mode: " .. mode .. ")", vim.log.levels.INFO)
	end
end

-- ⚡ toggle automatique
function M.toggle_block()
	local start_line, end_line = find_gpg_block()
	if not start_line then
		vim.notify("Aucun bloc ```gpg``` valide trouvé.", vim.log.levels.WARN)
		return
	end

	if is_encrypted(start_line) then
		decrypt_block_memory(start_line, end_line)
	else
		encrypt_block_memory(start_line, end_line)
	end
end

-- 📦 pliage automatique
local function fold_gpg_block()
	local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	if not buf then
		return
	end

	local fold_start, backticks = nil, nil
	for i, line in ipairs(buf) do
		if not line then
			goto continue
		end
		local bt, lang = line:match("^(`+)(%S*)")
		if bt and lang:match("gpg") then
			fold_start = i
			backticks = #bt
		elseif fold_start and backticks and i > fold_start and line:match("^`{" .. backticks .. "}$") then
			pcall(vim.api.nvim_buf_add_fold, 0, fold_start - 1, i)
			fold_start, backticks = nil, nil
		end
		::continue::
	end
end

-- 📦 setup
function M.setup()
	vim.api.nvim_create_user_command("ToggleGpgBlock", M.toggle_block, {})
	vim.keymap.set("n", "<leader>gt", M.toggle_block, { desc = "Basculer bloc GPG" })

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
		pattern = "*",
		callback = fold_gpg_block,
	})
end

return M
