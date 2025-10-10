-- Évite des alertes linter
local uv
if vim.loop then
	uv = vim.loop
end

local Block = require("securemd.block")

local M = {}

-- 🔧 Helper pour transformer un flux texte en lignes
local function split_lines(str)
	local t = {}
	for s in str:gmatch("([^\n]*)\n?") do
		table.insert(t, s)
	end
	return t
end

local function get_file_recipient()
	local lines = vim.api.nvim_buf_get_lines(0, 0, 100, false) -- lit les 100 premières lignes
	local in_front_matter = false

	for _, line in ipairs(lines) do
		if line:match("^%-%-%-$") then
			-- vim.notify("front-matter YAML détecté", vim.log.levels.DEBUG)
			-- toggle front-matter
			in_front_matter = not in_front_matter
		elseif in_front_matter then
			-- vim.notify("in front-matter YAML", vim.log.levels.DEBUG)
			-- cherche gpg-recipient
			local recipient = line:match("^%s*gpg%-recipient:%s*(.+)%s*$")
			-- vim.notify(recipient, vim.log.levels.DEBUG)
			if recipient and recipient ~= "" then
				return recipient
			end
		end
	end

	vim.notify("Pas de destinataire GPG défini dans le front-matter.", vim.log.levels.ERROR)
	return nil
end

-- --------------------------------------------------------------------
-- 🔐 Fonction bas niveau : exécute GPG asynchrone (non bloquant)
-- --------------------------------------------------------------------
local function run_gpg_async(args, stdin_data, passphrase, on_exit)
	local stdin_pipe = uv.new_pipe(false)
	local stdout_pipe = uv.new_pipe(false)
	local stderr_pipe = uv.new_pipe(false)
	local pass_pipe = uv.new_pipe(false)

	local stdout_chunks, stderr_chunks = {}, {}

	local handle, spawn_err = uv.spawn("gpg", {
		args = args,
		stdio = { stdin_pipe, stdout_pipe, stderr_pipe, pass_pipe },
	}, function(code, signal)
		-- Une fois gpg terminé
		uv.read_stop(stdout_pipe)
		uv.read_stop(stderr_pipe)

		-- Fermeture des pipes
		for _, p in ipairs({ stdin_pipe, stdout_pipe, stderr_pipe, pass_pipe }) do
			if p and not p:is_closing() then
				p:close()
			end
		end

		local stdout_str = table.concat(stdout_chunks)
		local stderr_str = table.concat(stderr_chunks)

		vim.schedule(function()
			if code ~= 0 then
				local msg = ("gpg (exit %d, signal %s): %s"):format(code or -1, tostring(signal), stderr_str)
				vim.notify(msg, vim.log.levels.ERROR)
				on_exit(nil, msg)
			else
				on_exit(split_lines(stdout_str))
			end
		end)
	end)

	if not handle then
		vim.schedule(function()
			vim.notify("Échec du lancement de gpg: " .. tostring(spawn_err), vim.log.levels.ERROR)
			on_exit(nil, spawn_err)
		end)
		return
	end

	-- lecture stdout/stderr
	uv.read_start(stdout_pipe, function(err, data)
		if err then
			table.insert(stderr_chunks, "stdout err: " .. err)
		elseif data then
			table.insert(stdout_chunks, data)
		end
	end)
	uv.read_start(stderr_pipe, function(err, data)
		if err then
			table.insert(stderr_chunks, "stderr err: " .. err)
		elseif data then
			table.insert(stderr_chunks, data)
		end
	end)

	-- passphrase sur fd3
	pass_pipe:write(passphrase .. "\n")
	pass_pipe:shutdown(function()
		pass_pipe:close()
	end)

	-- entrée (cipher/plaintext)
	if stdin_data then
		stdin_pipe:write(stdin_data)
	end
	stdin_pipe:shutdown(function()
		stdin_pipe:close()
	end)
end

-- --------------------------------------------------------------------
-- 🧩 API : run_gpg_cmd_as_async()
-- --------------------------------------------------------------------
local function run_gpg_cmd_async(cmd_table, input, passphrase, on_done)
	vim.env.GPG_TTY = vim.fn.system("tty"):gsub("\n", "")

	local needs_pass = false
	for _, a in ipairs(cmd_table) do
		if a == "--decrypt" or a == "--sign" or a == "--symmetric" then
			needs_pass = true
			break
		end
	end

	local args = vim.deepcopy(cmd_table)
	table.insert(args, 1, "--batch")
	table.insert(args, 2, "--quiet")

	if needs_pass then
		table.insert(args, "--pinentry-mode")
		table.insert(args, "loopback")
		table.insert(args, "--passphrase-fd")
		table.insert(args, "3")
	end

	local stdin_data = nil
	if type(input) == "table" then
		stdin_data = table.concat(input, "\n")
	elseif type(input) == "string" then
		stdin_data = input
	end

	run_gpg_async(args, stdin_data, passphrase or "", on_done)
end

-- --------------------------------------------------------------------
-- 🔓 Déchiffrement asynchrone
-- --------------------------------------------------------------------
function M.decrypt_async(ciphertext, on_done)
	if not ciphertext or type(ciphertext) ~= "table" then
		return
	end

	local passphrase = vim.fn.inputsecret("Pass phrase: ")
	if not passphrase or passphrase == "" then
		vim.notify("Déchiffrement annulé : passphrase vide", vim.log.levels.WARN)
		return
	end

	local cmd = { "--decrypt" }
	run_gpg_cmd_async(cmd, ciphertext, passphrase, function(out, err)
		if not out then
			vim.notify("Déchiffrement échoué : " .. (err or ""), vim.log.levels.ERROR)
			return
		end
		on_done(out)
	end)
end

-- --------------------------------------------------------------------
-- 🔒 Chiffrement asynchrone
-- --------------------------------------------------------------------
function M.encrypt_async(plaintext, on_done)
	if not plaintext or type(plaintext) ~= "table" then
		return
	end
	local content = table.concat(plaintext, "\n")

	local recipient = get_file_recipient()
	if not recipient then
		vim.notify("Chiffrement annulé : destinataire inconnu", vim.log.levels.WARN)
		return
	end

	local cmd = { "--encrypt", "--armor", "-r", recipient }
	run_gpg_cmd_async(cmd, content, nil, function(out, err)
		if not out then
			vim.notify("Chiffrement échoué : " .. (err or ""), vim.log.levels.ERROR)
			return
		end
		on_done(out)
	end)
end

-- --------------------------------------------------------------------
-- 🔁 Toggle automatique (asynchrone)
-- --------------------------------------------------------------------
function M.toggle()
	local start_line, end_line = Block.find_block()
	local content = Block.get_content(start_line, end_line)
	if not content then
		return
	end

	local first_line = content[1]
	if string.match(first_line, "BEGIN%sPGP%sMESSAGE") then
		M.decrypt_async(content, function(plaintext)
			if plaintext then
				Block.set_content(start_line, end_line, plaintext)
				vim.notify("Bloc déchiffré 🔓", vim.log.levels.INFO)
			end
		end)
	else
		M.encrypt_async(content, function(ciphertext)
			if ciphertext then
				Block.set_content(start_line, end_line, ciphertext)
				vim.notify("Bloc chiffré 🔒", vim.log.levels.INFO)
			end
		end)
	end
end

return M
