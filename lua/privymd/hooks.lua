--- @module 'privymd.hooks'
--- High-level hooks providing user-facing commands and behaviors.
---
--- This module ties together the core and feature layers of PrivyMD:
--- it reacts to user actions, orchestrates encryption/decryption
--- of GPG code blocks, and manages session state (modified flag,
--- passphrase cache, and buffer saving).
---
--- None of the functions here are meant to be called directly from
--- other modules; they are invoked through user commands, keymaps,
--- or autocmds configured in the plugin setup.

local Block = require('privymd.core.block')
local Buffer = require('privymd.core.buffer')
local Decrypt = require('privymd.features.decrypt')
local Encrypt = require('privymd.features.encrypt')
local Front = require('privymd.core.frontmatter')
local List = require('privymd.utils.list')
local Passphrase = require('privymd.core.passphrase')
local log = require('privymd.utils.logger')

local M = {}

--- Toggle encryption state of the block under the cursor.
---
--- If the cursor is inside an encrypted block, it will be decrypted;
--- otherwise, the plaintext block will be encrypted using the front-matter
--- recipient.
--- Returns a numeric code when no encryption/decryption occurs.
---
--- Return codes:
--- - `1`: no GPG blocks found
--- - `2`: cursor not inside a GPG block
--- - `3`: missing GPG recipient in front-matter
---
--- @return nil|1|2|3
function M.toggle_encryption()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local blocks = Block.find_blocks(text)
  if #blocks == 0 then
    log.trace('No GPG blocks found.')
    return 1
  end

  -- Locate block under cursor
  local target
  for _, block in ipairs(blocks) do
    if cursor_line >= block.start and cursor_line <= block.end_ then
      target = block
      break
    end
  end
  if not target then
    log.warn('Cursor not inside a GPG block.')
    return 2
  end

  if Block.is_encrypted(target) then
    local passphrase = Passphrase.get()
    Decrypt.decrypt_block(target, passphrase)
  else
    local recipient = Front.get_file_recipient()
    if not recipient then
      log.info('No GPG recipient defined — encryption impossible.')
      return 3
    end
    Encrypt.encrypt_block(target, recipient)
  end
end

--- Decrypt every encrypted block in the current buffer.
---
--- Sequentially decrypts all detected GPG code fences. Each block is
--- processed in order to avoid index desynchronization while updating
--- the buffer.
--- Returns an informational message when no encrypted blocks are found.
---
--- @return nil
--- @return string? message  present only if nothing was decrypted.
function M.decrypt_buffer()
  log.trace('Decrypting buffer…')
  local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local blocks = Block.find_blocks(text)

  local cipher_blocks = List.filter(blocks, Block.is_encrypted)
  if #cipher_blocks == 0 then
    local message = 'No encrypted GPG blocks found.'
    log.trace(message)
    return nil, message
  end

  local passphrase = Passphrase.get()

  for _, block in ipairs(cipher_blocks) do
    Decrypt.decrypt_block(block, passphrase)
  end
  log.trace(('Decrypted %d GPG block(s) successfully.'):format(#cipher_blocks))
  return nil
end

--- Encrypt the current buffer
---
--- Reads the entire buffer, encrypts any GPG blocks if a recipient is
--- defined, and writes the resulting ciphertext.
---
--- @return nil
--- @return string? message present on informational or error cases.
function M.encrypt_buffer()
  log.trace('Encrypting buffer…')
  local plaintext = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local recipient = Front.get_file_recipient()
  if not recipient then
    local message =
      "⚠️ No GPG recipient found in the front matter.\nThe buffer can't be processed."
    log.info(message)
    return nil, message
  end

  local blocks = Block.find_blocks(plaintext)
  local plain_blocks = List.filter(blocks, function(block)
    return not Block.is_encrypted(block)
  end)
  if #plain_blocks == 0 then
    local message = 'No GPG blocks to encrypt found.'
    log.info(message)
    return nil, message
  end

  for _, block in ipairs(plain_blocks) do
    Encrypt.encrypt_block(block, recipient)
  end
  log.trace(('Encrypted %d GPG block(s) successfully.'):format(#plain_blocks))
  return nil
end

--- Encrypts and saves the current buffer to disk.
---
--- Reads the entire buffer, encrypts any GPG blocks if a recipient is
--- defined, and writes the resulting ciphertext. If no recipient is
--- found, the user is prompted to confirm saving the plaintext file.
---
--- @return nil
--- @return string? message present on informational or error cases.
function M.encrypt_and_save_buffer()
  local plaintext = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local recipient = Front.get_file_recipient()
  local blocks = Block.find_blocks(plaintext)

  local plain_blocks = List.filter(blocks, function(block)
    return not Block.is_encrypted(block)
  end)

  if #plain_blocks == 0 then
    local _, err = Buffer.save_buffer(plaintext)
    if err then
      return nil, err
    end
    return nil, 'Saved without anything to encrypt.'
  elseif #plain_blocks > 0 and not recipient then
    local choice = vim.fn.confirm(
      '⚠️ No GPG recipient found in the front matter.\n'
        .. 'The file will be saved unencrypted.\n\n'
        .. 'Do you want to continue?',
      '&Yes\n&No',
      2 -- default: No
    )

    if choice ~= 1 then
      log.info('Save cancelled.')
      return nil, 'Save cancelled.'
    end

    -- Continue without encryption
    local _, err = Buffer.save_buffer(plaintext)
    if err then
      return nil, err
    end
    return nil, 'Saved without encryption.'
  end

  -- Normal encryption
  local ciphertext = Encrypt.encrypt_text(plaintext, assert(recipient))
  if not ciphertext then
    log.debug('Encryption failed.')
    return nil, 'Encryption failed.'
  end

  local _, err = Buffer.save_buffer(ciphertext)
  if err then
    return nil, err
  end
end

--- Clear the cached passphrase from memory.
---
--- ⚠️ **Security note**:
--- This only clears PrivyMD’s in-memory cache.
--- Your system’s GPG agent may still keep the key unlocked.
---
--- @return nil
function M.clear_passphrase()
  Passphrase.wipeout()
  log.info('Passphrase wiped from session cache.')
end

return M
