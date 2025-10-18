local H = require('privymd.core.gpg.helpers')
local log = require('privymd.utils.logger')
-- log.set_log_level("trace")

--- @class Gpg
local M = {}

--- Déchiffrement asynchrone
---@param ciphertext string[]
---@param passphrase string|nil
---@param callback fun(result: string[]|nil, err?: string)
function M.decrypt_async(ciphertext, passphrase, callback)
  if not ciphertext or #ciphertext == 0 then
    callback(nil, 'vide')
    return
  end

  local pipes = H.make_pipes(true)
  local gpg_args = {
    '--batch',
    '--yes',
    '--quiet',
    '--pinentry-mode',
    'loopback',
    '--passphrase-fd',
    '3',
    '--decrypt',
  }

  local handle, err = H.spawn_gpg(gpg_args, pipes, function(code, out, errstr)
    vim.schedule(function()
      if code ~= 0 then
        local is_blank_try = (not passphrase or passphrase == '')
        -- stylua: ignore
        local is_expected = is_blank_try
          and errstr:match('No passphrase given')

        if is_expected then
          -- Silent fail: it's a blank passphrase test, not a real error
          log.debug('Silent GPG failure (expected: missing passphrase or locked key).')
        else
          local err_msg = ('gpg (exit %d): %s'):format(code, errstr)
          log.error(err_msg)
        end

        callback(nil, errstr)
      else
        callback(vim.split(out, '\n', { trimempty = true }))
      end
    end)
  end)

  if not handle then
    local err_msg = 'Échec du lancement de gpg: ' .. tostring(err)
    vim.schedule(function()
      log.error(err_msg)
      callback(nil, err_msg)
    end)
    return
  end

  -- Envoie la passphrase (fd3)
  H.write_and_close(pipes.pass, (passphrase or '') .. '\n')

  -- Envoie le texte chiffré sur l'entrée standard de gpg
  H.write_and_close(pipes.stdin, table.concat(ciphertext, '\n'))
end

--- Chiffrement synchrone
--- @param plaintext string[]
--- @param recipient string
--- @return string[]|nil ciphertext encrypted block, or nil on failure
function M.encrypt_sync(plaintext, recipient)
  log.trace("Chiffrement d'un bloc…")

  if not plaintext or #plaintext == 0 then
    return nil
  end

  local pipes = H.make_pipes(false)
  local gpg_args = {
    '--batch',
    '--yes',
    '--armor',
    '--encrypt',
    '-r',
    recipient,
  }

  -- 1) spawn non-bloquant (auto_close = false)
  local result = { code = 0, stdout = '', stderr = '' }
  local done = false
  local handle, spawn_err = H.spawn_gpg(gpg_args, pipes, function(code, stdout_str, stderr_str)
    result.code, result.stdout, result.stderr = code, stdout_str, stderr_str
    done = true
  end)

  if not handle then
    log.error('Erreur lancement GPG (encrypt): ' .. tostring(spawn_err))
    return nil
  end

  -- Envoie du texte en clair sur l'entrée standard de gpg
  H.write_and_close(pipes.stdin, table.concat(plaintext, '\n'))

  -- 3) attendre la fin du process
  while not done do
    vim.uv.run('once')
  end

  if result.code ~= 0 or result.stdout == '' then
    log.error('Échec chiffrement : ' .. result.stderr)
    return nil
  end

  -- Nettoyage et retour du texte chiffré
  local out = H.normalize_output(result.stdout)
  log.trace('Renvoi du bloc chiffré.')
  return vim.split(out, '\n', { trimempty = true })
end

--- Vérifie la disponibilité de gpg dans le PATH
--- @return boolean
function M.is_gpg_available()
  local availability = vim.fn.executable('gpg') == 1
  if not availability then
    vim.notify('GPG non trouvé dans le PATH.', vim.log.levels.ERROR, { title = 'PrivyMD' })
  end
  return availability
end

return M
