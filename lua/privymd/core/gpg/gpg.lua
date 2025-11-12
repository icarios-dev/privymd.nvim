--- @module 'privymd.core.gpg'
--- High-level GPG interface for encryption and decryption operations.
--- Uses libuv pipes for inter-process communication with GPG,
--- but the exposed functions (`decrypt` and `encrypt`) run
--- synchronously and block until GPG completes.

local H = require('privymd.core.gpg.helpers')
local log = require('privymd.utils.logger')

--- @class gpg
local M = {}

local ARGS_DECRYPT = {
  '--batch',
  '--yes',
  '--quiet',
  '--pinentry-mode',
  'loopback',
  '--passphrase-fd',
  '3',
  '--decrypt',
}
local ARGS_ENCRYPT = {
  '--batch',
  '--yes',
  '--armor',
  '--encrypt',
  '-r',
}

--- Spawns a GPG process, writes the ciphertext and passphrase to its
--- respective pipes
---
--- @param ciphertext string[] Lines of the encrypted content block.
--- @param passphrase? string Optional passphrase to unlock the private key.
--- @return string[]|nil plaintext Plaintext lines, or nil if encryption failed.
--- @return error? error message
function M.decrypt(ciphertext, passphrase)
  if not ciphertext or #ciphertext == 0 then
    return nil
  end
  local input = table.concat(ciphertext, '\n')
  passphrase = passphrase or ''

  local result, err = H.run_gpg(ARGS_DECRYPT, input, passphrase)

  if err then
    local is_blank_try = (not passphrase or passphrase == '')
    local is_expected = is_blank_try and err:match('No passphrase given')
    if is_expected then
      -- Silent fail: it's a blank passphrase test, not a real error
      log.debug('Silent GPG failure (expected: missing passphrase or locked key).')
      return nil
    end
    return nil, err
  end

  -- Normalize and return encrypted output
  local out = H.normalize_output(result)
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
  if not plaintext or #plaintext == 0 then
    return nil
  end
  local input = table.concat(plaintext, '\n')

  local gpg_args = ARGS_ENCRYPT
  table.insert(gpg_args, recipient)

  local result, err = H.run_gpg(gpg_args, input)

  if err or result == '' then
    return nil, 'Échec chiffrement : ' .. err
  end

  -- Normalize and return encrypted output
  local out = H.normalize_output(result)
  log.trace('Renvoi du bloc chiffré.')
  return vim.split(out, '\n', { trimempty = true })
end

--- Alias of `privymd.gpg.helpers.is_gpg_available()`.
--- @see privymd.gpg.helpers.check_gpg
M.is_gpg_available = H.check_gpg

return M
