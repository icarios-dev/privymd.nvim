local log = require("privymd.utils.logger")
log.set_log_level("trace")

local uv = vim.uv

local M = {}

---------------------------------------------------------------------
-- 🧠 Utilitaire : exécuter gpg avec des pipes mémoire
---------------------------------------------------------------------
local function run_gpg_async(gpg_args, stdin_data, passphrase, on_exit)
	local stdin_pipe = assert(uv.new_pipe(false))
	local stdout_pipe = assert(uv.new_pipe(false))
	local stderr_pipe = assert(uv.new_pipe(false))
	local pass_pipe = assert(uv.new_pipe(false))

	local stdout_chunks, stderr_chunks = {}, {}

	local handle, spawn_err = uv.spawn("gpg", {
		args = gpg_args,
		stdio = { stdin_pipe, stdout_pipe, stderr_pipe, pass_pipe },
		cwd = "",
		env = {},
		uid = "",
		gid = "",
		verbatim = false,
		detached = false,
		hide = true,
	}, function(code)
		uv.read_stop(stdout_pipe)
		uv.read_stop(stderr_pipe)

		for _, p in ipairs({ stdin_pipe, stdout_pipe, stderr_pipe, pass_pipe }) do
			if p and not p:is_closing() then
				p:close()
			end
		end

		local stdout_str = table.concat(stdout_chunks)
		local stderr_str = table.concat(stderr_chunks)

		vim.schedule(function()
			if code ~= 0 then
				local msg = ("gpg (exit %d): %s"):format(code or -1, stderr_str)
				vim.notify(msg, vim.log.levels.ERROR)
				on_exit(nil, msg)
			else
				on_exit(vim.split(stdout_str, "\n", { trimempty = true }))
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

	-- Lecture stdout/stderr
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

	-- Écriture passphrase sur fd3
	pass_pipe:write((passphrase or "") .. "\n")
	pass_pipe:shutdown(function()
		if not pass_pipe:is_closing() then
			pass_pipe:close()
		end
	end)

	-- Entrée (cipher/plaintext)
	if stdin_data and #stdin_data > 0 then
		stdin_pipe:write(stdin_data)
	end
	stdin_pipe:shutdown(function()
		if not stdin_pipe:is_closing() then
			stdin_pipe:close()
		end
	end)
end

---------------------------------------------------------------------
-- 🔓 Déchiffrement asynchrone (fluide à l’ouverture)
---------------------------------------------------------------------
function M.decrypt_async(ciphertext, passphrase, callback)
	if not ciphertext or #ciphertext == 0 then
		callback(nil, "vide")
		return
	end

	local input = table.concat(ciphertext, "\n")
	local gpg_args = {
		"--batch",
		"--yes",
		"--quiet",
		"--pinentry-mode",
		"loopback",
		"--passphrase-fd",
		"3",
		"--decrypt",
	}

	run_gpg_async(gpg_args, input, passphrase, callback)
end

---------------------------------------------------------------------
-- 🔒 Chiffrement synchrone (pour BufWritePre)
---------------------------------------------------------------------
function M.encrypt_sync(plaintext, recipient)
	log.trace("Chiffrement d'un bloc…")
	if not plaintext or #plaintext == 0 then
		return nil
	end

	local input = table.concat(plaintext, "\n")
	local gpg_args = {
		"--batch",
		"--yes",
		"--armor",
		"--encrypt",
		"-r",
		recipient,
	}

	local stdout_chunks, stderr_chunks = {}, {}

	-- création des pipes
	local stdin_pipe = assert(uv.new_pipe(false))
	local stdout_pipe = assert(uv.new_pipe(false))
	local stderr_pipe = assert(uv.new_pipe(false))

	local done = false
	local exit_code = nil

	local handle, spawn_err = uv.spawn("gpg", {
		args = gpg_args,
		stdio = { stdin_pipe, stdout_pipe, stderr_pipe },
		cwd = "",
		env = {},
		uid = "",
		gid = "",
		verbatim = false,
		detached = false,
		hide = true,
	}, function(code)
		exit_code = code
		done = true
	end)

	if not handle then
		log.error("Erreur lancement GPG (encrypt): " .. tostring(spawn_err))
		return nil
	end

	-- lecture stdout
	uv.read_start(stdout_pipe, function(err, data)
		if err then
			table.insert(stderr_chunks, "stdout err: " .. err)
		elseif data then
			table.insert(stdout_chunks, data)
		end
	end)

	-- lecture stderr
	uv.read_start(stderr_pipe, function(err, data)
		if err then
			table.insert(stderr_chunks, "stderr err: " .. err)
		elseif data then
			table.insert(stderr_chunks, data)
		end
	end)

	-- écriture stdin
	stdin_pipe:write(input)
	stdin_pipe:shutdown(function()
		if not stdin_pipe:is_closing() then
			stdin_pipe:close()
		end
	end)

	-- attente active jusqu'à la fin du processus
	while not done do
		uv.run("once")
	end

	-- arrêt des lectures
	uv.read_stop(stdout_pipe)
	uv.read_stop(stderr_pipe)
	for _, p in ipairs({ stdout_pipe, stderr_pipe, handle }) do
		if p and not p:is_closing() then
			p:close()
		end
	end

	-- concat des résultats
	local result = table.concat(stdout_chunks)
	local stderr_str = table.concat(stderr_chunks)

	if exit_code ~= 0 or result == "" then
		log.error("Échec chiffrement : " .. stderr_str)
		return nil
	end

	-- s’assurer qu’il y a une ligne vide après le header
	if not result:match("\n\n") then
		result = result:gsub("(\r?\n\r?\n)", "\n\n")
	end

	local ciphertext = vim.split(result, "\n", { trimempty = true })

	log.trace("Renvoi du bloc chiffré.")
	return ciphertext
end

return M
