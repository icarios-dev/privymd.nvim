--- @module 'privymd.core.gpg'
--- High-level GPG interface for encryption and decryption operations.
--- Uses libuv pipes (see privymd.core.gpg.helpers) for asynchronous communication with GPG.

local H = require('privymd.core.gpg.helpers')
local log = require('privymd.utils.logger')

--- @class gpg
local M = {}

--- Decrypt an armored PGP message asynchronously.
--- Spawns a GPG process, writes the ciphertext and passphrase to its
--- respective pipes, and invokes the callback once finished.
---
--- Handles "blank passphrase" attempts gracefully by logging a silent debug message.
---
--- @async
--- @param ciphertext string[] Lines of the encrypted content block.
--- @param passphrase string|nil Optional passphrase to unlock the private key.
--- @param callback fun(result: string[]|nil, err?: string) Callback invoked upon decryption completion.
---        - `result`: decrypted plaintext lines, or nil on error.
---        - `err`: optional error message returned by GPG.
function M.decrypt_async(ciphertext, passphrase, callback)
  log.trace(' -> entry in decrypt_async()')
  if not ciphertext or #ciphertext == 0 then
    log.debug(' - nothing to decrypt')
    callback(nil, 'empty')
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
    log.trace(' -> entry in spawn_gpg/callback')
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
    local err_msg = 'Failed to start gpg: ' .. tostring(err)
    vim.schedule(function()
      log.error(err_msg)
      callback(nil, err_msg)
    end)
    return
  end

  -- Send passphrase (fd3)
  H.write_and_close(pipes.pass, (passphrase or '') .. '\n')

  -- Send ciphertext to GPG stdin
  H.write_and_close(pipes.stdin, table.concat(ciphertext, '\n'))
end

--- Encrypt plaintext lines for a given recipient.
--- Runs synchronously until GPG finishes and returns the armored ciphertext.
---
--- @async
--- @param plaintext string[] Plaintext lines to encrypt.
--- @param recipient string GPG key identifier of the recipient.
--- @return string[]|nil ciphertext Encrypted lines, or nil if encryption failed.
function M.encrypt_sync(plaintext, recipient)
  log.trace('Encrypting block…')

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

  local result = { code = 0, stdout = '', stderr = '' }
  local done = false

  local handle, spawn_err = H.spawn_gpg(gpg_args, pipes, function(code, stdout_str, stderr_str)
    result.code, result.stdout, result.stderr = code, stdout_str, stderr_str
    done = true
  end)

  if not handle then
    log.error('Failed to start GPG (encrypt): ' .. tostring(spawn_err))
    return nil
  end

  -- Send plaintext to gpg stdin
  H.write_and_close(pipes.stdin, table.concat(plaintext, '\n'))

  -- Wait for process completion
  while not done do
    vim.uv.run('once')
  end

  if result.code ~= 0 or result.stdout == '' then
    log.error('Échec chiffrement : ' .. result.stderr)
    return nil
  end

  -- Normalize and return encrypted output
  local out = H.normalize_output(result.stdout)
  log.trace('Renvoi du bloc chiffré.')
  return vim.split(out, '\n', { trimempty = true })
end

--- Check whether GPG is available in the current PATH.
--- Shows an error notification if not found.
---
--- @return boolean available True if GPG executable is available, false otherwise.
function M.is_gpg_available()
  local availability = vim.fn.executable('gpg') == 1
  if not availability then
    vim.notify('GPG non trouvé dans le PATH.', vim.log.levels.ERROR, { title = 'PrivyMD' })
  end
  return availability
end

return M
