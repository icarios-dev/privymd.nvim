--- @module 'privymd.core.gpg'
--- High-level GPG interface for encryption and decryption operations.
--- Uses libuv pipes for inter-process communication with GPG,
--- but the exposed functions (`decrypt` and `encrypt`) run
--- synchronously and block until GPG completes.

local H = require('privymd.core.gpg.helpers')
local log = require('privymd.utils.logger')

--- @class gpg
local M = {}

--- Decrypt an armored PGP message.
--- Spawns a GPG process, writes the ciphertext and passphrase to its
--- respective pipes
---
--- @param ciphertext string[] Lines of the encrypted content block.
--- @param passphrase string|nil Optional passphrase to unlock the private key.
--- @return string[]|nil plaintext Plaintext lines, or nil if encryption failed.
--- @return error? error message
function M.decrypt(ciphertext, passphrase)
  if not ciphertext or #ciphertext == 0 then
    return nil
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

  local result = { code = 0, stdout = '', stderr = '' }
  local done = false

  local handle, spawn_err = H.spawn_gpg(gpg_args, pipes, function(code, stdout, stderr)
    result.code, result.stdout, result.stderr = code, stdout, stderr
    done = true
  end)
  if not handle then
    return nil, 'Failed to start GPG (decrypt): ' .. tostring(spawn_err)
  end

  -- Send passphrase (fd3)
  H.write_and_close(pipes.pass, (passphrase or '') .. '\n')

  -- Send ciphertext to gpg stdin
  H.write_and_close(pipes.stdin, table.concat(ciphertext, '\n'))

  -- Wait for process completion
  while not done do
    vim.uv.run('once')
  end

  if result.code ~= 0 or result.stdout == '' then
    local is_blank_try = (not passphrase or passphrase == '')
    local is_expected = is_blank_try and result.stderr:match('No passphrase given')
    if is_expected then
      -- Silent fail: it's a blank passphrase test, not a real error
      log.debug('Silent GPG failure (expected: missing passphrase or locked key).')
      return nil
    end
    local err_msg = ('gpg (exit %d): %s'):format(result.code, result.stderr)
    return nil, err_msg
  end

  -- Normalize and return encrypted output
  local out = H.normalize_output(result.stdout)
  log.trace('Renvoi du bloc déchiffré.')
  return vim.split(out, '\n', { trimempty = true })
end

--- Encrypt plaintext lines for a given recipient.
--- Runs synchronously until GPG finishes and returns the armored ciphertext.
---
--- @param plaintext string[] Plaintext lines to encrypt.
--- @param recipient string GPG key identifier of the recipient.
--- @return string[]|nil ciphertext Encrypted lines, or nil if encryption failed.
--- @return error? error message
function M.encrypt(plaintext, recipient)
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
    return nil, 'Failed to start GPG (encrypt): ' .. tostring(spawn_err)
  end

  -- Send plaintext to gpg stdin
  H.write_and_close(pipes.stdin, table.concat(plaintext, '\n'))

  -- Wait for process completion
  while not done do
    vim.uv.run('once')
  end

  if result.code ~= 0 or result.stdout == '' then
    return nil, 'Échec chiffrement : ' .. result.stderr
  end

  -- Normalize and return encrypted output
  local out = H.normalize_output(result.stdout)
  log.trace('Renvoi du bloc chiffré.')
  return vim.split(out, '\n', { trimempty = true })
end

--- Alias of `privymd.gpg.helpers.is_gpg_available()`.
--- @see privymd.gpg.helpers.check_gpg
M.is_gpg_available = H.check_gpg

return M
