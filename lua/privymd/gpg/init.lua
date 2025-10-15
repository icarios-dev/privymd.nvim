local Gpg_helpers = require("privymd.gpg.helpers")
local log = require("privymd.utils.logger")
-- log.set_log_level("trace")

local uv = vim.uv
local make_pipes = Gpg_helpers.make_pipes
local close_all = Gpg_helpers.close_all
local spawn_gpg = Gpg_helpers.spawn_gpg

local M = {}

---------------------------------------------------------------------
-- 🔓 Déchiffrement asynchrone
---------------------------------------------------------------------
function M.decrypt_async(ciphertext, passphrase, callback)
	if not ciphertext or #ciphertext == 0 then
		callback(nil, "vide")
		return
	end

	local pipes = make_pipes(true)
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

	local handle, err
	handle, err = spawn_gpg(gpg_args, pipes, function(code, out, errstr)
		vim.schedule(function()
			if not handle then
				vim.notify("Échec du lancement de gpg: " .. tostring(err), vim.log.levels.ERROR)
				callback(nil, err)
			elseif code ~= 0 then
				local msg = ("gpg (exit %d): %s"):format(code, errstr)
				vim.notify(msg, vim.log.levels.ERROR)
				callback(nil, msg)
			else
				callback(vim.split(out, "\n", { trimempty = true }))
			end
		end)
	end)

	if not handle then
		vim.schedule(function()
			vim.notify("Échec du lancement de gpg: " .. tostring(err), vim.log.levels.ERROR)
			callback(nil, err)
		end)
		return
	end

	-- envoie passphrase (fd3)
	pipes.pass:write((passphrase or "") .. "\n")
	pipes.pass:shutdown(function()
		if not pipes.pass:is_closing() then
			pipes.pass:close()
		end
	end)

	-- texte chiffré sur stdin
	local input = table.concat(ciphertext, "\n")
	pipes.stdin:write(input)
	pipes.stdin:shutdown(function()
		if not pipes.stdin:is_closing() then
			pipes.stdin:close()
		end
	end)
end

---------------------------------------------------------------------
-- 🔒 Chiffrement synchrone
---------------------------------------------------------------------
function M.encrypt_sync(plaintext, recipient)
	log.trace("Chiffrement d'un bloc…")
	if not plaintext or #plaintext == 0 then
		return nil
	end

	local pipes = make_pipes(false)
	local gpg_args = {
		"--batch",
		"--yes",
		"--armor",
		"--encrypt",
		"-r",
		recipient,
	}

	local done, exit_code, out, errstr = false, 0, "", ""

	local handle, spawn_err = spawn_gpg(gpg_args, pipes, function(code, stdout_str, stderr_str)
		exit_code, out, errstr, done = code, stdout_str, stderr_str, true
	end)

	if not handle then
		log.error("Erreur lancement GPG (encrypt): " .. tostring(spawn_err))
		return nil
	end

	-- envoi du texte en clair
	pipes.stdin:write(table.concat(plaintext, "\n"))
	pipes.stdin:shutdown(function()
		if not pipes.stdin:is_closing() then
			pipes.stdin:close()
		end
	end)

	-- attente de fin
	while not done do
		uv.run("once")
	end

	close_all(pipes, handle)

	if exit_code ~= 0 or out == "" then
		log.error("Échec chiffrement : " .. errstr)
		return nil
	end

	-- normalise double saut de ligne après header
	if not out:match("\n\n") then
		out = out:gsub("(\r?\n\r?\n)", "\n\n")
	end

	log.trace("Renvoi du bloc chiffré.")
	return vim.split(out, "\n", { trimempty = true })
end

---------------------------------------------------------------------
-- 🧭 Vérifie la disponibilité de gpg dans le PATH
---------------------------------------------------------------------
function M.is_gpg_available()
	local ok = vim.fn.executable("gpg") == 1
	if not ok then
		vim.notify("GPG non trouvé dans le PATH.", vim.log.levels.ERROR, { title = "PrivyMD" })
	end
	return ok
end

return M
