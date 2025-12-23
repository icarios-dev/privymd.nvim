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

--- Build a fresh GPG argument list for decryption.
---
--- This function returns a new table on each call to avoid
--- side effects caused by shared mutable tables.
---
--- @return string[] args GPG arguments for decryption
local function decrypt_args()
  return { unpack(ARGS_DECRYPT) }
end

--- Build a fresh GPG argument list for encryption.
---
--- The recipient is appended as the final argument. A new table
--- is returned on each call to prevent accidental mutation of
--- the base argument list.
---
--- @param recipient string GPG key identifier of the recipient
--- @return string[] args GPG arguments for encryption
--- @error Throws if recipient is missing or empty-
local function encrypt_args(recipient)
  assert(type(recipient) == 'string' and recipient ~= '', 'recipient required')
  return { unpack(ARGS_ENCRYPT), recipient }
end

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

  local result, err = H.run_gpg(decrypt_args(), input, passphrase)

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

  local result, err = H.run_gpg(encrypt_args(recipient), input)

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
