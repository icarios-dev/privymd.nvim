local log = require("privymd.utils.logger")
log.set_log_level("trace")

local uv = vim.uv
local M = {}

---------------------------------------------------------------------
-- 🧠 Exécuter gpg de façon asynchrone avec pipes mémoire
---------------------------------------------------------------------
local function run_gpg_async(gpg_args, stdin_data, passphrase, on_exit)
	local pipes = {
		stdin = assert(uv.new_pipe(false)),
		stdout = assert(uv.new_pipe(false)),
		stderr = assert(uv.new_pipe(false)),
		pass = assert(uv.new_pipe(false)),
	}

	local stdout_chunks, stderr_chunks = {}, {}

	local handle, spawn_err = uv.spawn("gpg", {
		args = gpg_args,
		stdio = { pipes.stdin, pipes.stdout, pipes.stderr, pipes.pass },
		cwd = "",
		env = {},
		uid = "",
		gid = "",
		verbatim = false,
		detached = false,
		hide = true,
	}, function(code)
		for _, p in pairs(pipes) do
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

	-- stdout/stderr
	uv.read_start(pipes.stdout, function(err, data)
		if err then
			table.insert(stderr_chunks, "stdout err: " .. err)
		elseif data then
			table.insert(stdout_chunks, data)
		end
	end)

	uv.read_start(pipes.stderr, function(err, data)
		if err then
			table.insert(stderr_chunks, "stderr err: " .. err)
		elseif data then
			table.insert(stderr_chunks, data)
		end
	end)

	-- passphrase sur fd3
	pipes.pass:write((passphrase or "") .. "\n")
	pipes.pass:shutdown(function()
		if not pipes.pass:is_closing() then
			pipes.pass:close()
		end
	end)

	-- entrée principale
	if stdin_data and #stdin_data > 0 then
		pipes.stdin:write(stdin_data)
	end
	pipes.stdin:shutdown(function()
		if not pipes.stdin:is_closing() then
			pipes.stdin:close()
		end
	end)
end

---------------------------------------------------------------------
-- 🔓 Déchiffrement asynchrone (à l’ouverture)
---------------------------------------------------------------------
function M.decrypt_async(ciphertext, passphrase, callback)
	if not ciphertext or #ciphertext == 0 then
		callback(nil, "vide")
		return
	end

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

	run_gpg_async(gpg_args, table.concat(ciphertext, "\n"), passphrase, callback)
end

---------------------------------------------------------------------
-- 🔒 Chiffrement synchrone (à la sauvegarde)
---------------------------------------------------------------------
function M.encrypt_sync(plaintext, recipient)
	log.trace("Chiffrement d'un bloc…")
	if not plaintext or #plaintext == 0 then
		return nil
	end

	local gpg_args = {
		"--batch",
		"--yes",
		"--armor",
		"--encrypt",
		"-r",
		recipient,
	}

	local pipes = {
		stdin = assert(uv.new_pipe(false)),
		stdout = assert(uv.new_pipe(false)),
		stderr = assert(uv.new_pipe(false)),
	}

	local stdout_chunks, stderr_chunks = {}, {}
	local done, exit_code = false, nil

	local handle, spawn_err = uv.spawn("gpg", {
		args = gpg_args,
		stdio = { pipes.stdin, pipes.stdout, pipes.stderr },
		cwd = "",
		env = {},
		uid = "",
		gid = "",
		verbatim = false,
		detached = false,
		hide = true,
	}, function(code)
		exit_code, done = code, true
	end)

	if not handle then
		log.error("Erreur lancement GPG (encrypt): " .. tostring(spawn_err))
		return nil
	end

	uv.read_start(pipes.stdout, function(err, data)
		if err then
			table.insert(stderr_chunks, "stdout err: " .. err)
		elseif data then
			table.insert(stdout_chunks, data)
		end
	end)

	uv.read_start(pipes.stderr, function(err, data)
		if err then
			table.insert(stderr_chunks, "stderr err: " .. err)
		elseif data then
			table.insert(stderr_chunks, data)
		end
	end)

	pipes.stdin:write(table.concat(plaintext, "\n"))
	pipes.stdin:shutdown(function()
		if not pipes.stdin:is_closing() then
			pipes.stdin:close()
		end
	end)

	while not done do
		uv.run("once")
	end

	for _, p in pairs(pipes) do
		uv.read_stop(p)
		if not p:is_closing() then
			p:close()
		end
	end
	if handle and not handle:is_closing() then
		handle:close()
	end

	local result = table.concat(stdout_chunks)
	local stderr_str = table.concat(stderr_chunks)
	if exit_code ~= 0 or result == "" then
		log.error("Échec chiffrement : " .. stderr_str)
		return nil
	end

	if not result:match("\n\n") then
		result = result:gsub("(\r?\n\r?\n)", "\n\n")
	end

	log.trace("Renvoi du bloc chiffré.")
	return vim.split(result, "\n", { trimempty = true })
end

return M
