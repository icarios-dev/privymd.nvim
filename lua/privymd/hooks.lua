local Block = require('privymd.core.block')
local Buffer = require('privymd.core.buffer')
local Decrypt = require('privymd.features.decrypt')
local Encrypt = require('privymd.features.encrypt')
local Front = require('privymd.core.frontmatter')
local Gpg = require('privymd.core.gpg')
local List = require('privymd.utils.list')
local log = require('privymd.utils.logger')

-- cache local de la passphrase pour la session
local _cached_passphrase = nil

local function ensure_passphrase(passphrase)
  if passphrase and passphrase ~= '' then
    return passphrase
  end
  return vim.fn.inputsecret('Passphrase GPG : ')
end

--@class Hooks
--@field toggle_encryption fun()
--@field decrypt_buffer fun()
--@field encrypt_and_save_buffer fun()
--@field clear_passphrase fun()

--@type Hooks
local M = {}

function M.toggle_encryption()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local text = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = Block.find_blocks(text)
  if #blocks == 0 then
    log.trace('No GPG blocks found.')
    return
  end

  -- find the block under cursor
  local target
  for _, block in ipairs(blocks) do
    if cursor_line >= block.start and cursor_line <= block.end_ then
      target = block
      break
    end
  end
  if not target then
    log.warn('Cursor not inside a GPG block.')
    return
  end

  local modified_before = vim.bo[bufnr].modified
  vim.bo[bufnr].modified = false

  if Block.is_encrypted(target) then
    local passphrase = ensure_passphrase(_cached_passphrase)
    Decrypt.decrypt_block(target, passphrase)
  else
    local recipient = Front.get_file_recipient()
    if not recipient then
      return
    end
    Encrypt.encrypt_block(target, recipient)
  end

  vim.bo[bufnr].modified = modified_before
end

function M.decrypt_buffer()
  if not Gpg.is_gpg_available() then
    log.warn('GPG non disponible — déchiffrement annulé.')
    return
  end
  log.trace('Decrypting buffer...')
  local bufnr = vim.api.nvim_get_current_buf()
  local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local blocks = Block.find_blocks(text)
  local cipher_blocks = List.filter(blocks, Block.is_encrypted)

  if #cipher_blocks == 0 then
    log.trace('No encrypted GPG blocks found.')
    return
  end

  local passphrase = ensure_passphrase(_cached_passphrase)
  local modified_before = vim.bo.modified
  vim.bo[bufnr].modified = false

  local i = 1

  local function decrypt_next()
    local block = cipher_blocks[i]
    if not block then
      vim.bo[bufnr].modified = modified_before
      log.info('All blocks decrypted')
      return
    end

    Decrypt.decrypt_block(block, passphrase, function()
      i = i + 1
      decrypt_next()
    end)
  end

  decrypt_next()
end

--- Chiffre et sauvegared le buffer courant
function M.encrypt_and_save_buffer()
  -- Crée une copie du buffer pour construire le texte chiffré
  local plaintext = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local recipient = Front.get_file_recipient()
  local blocks = Block.find_blocks(plaintext)
  local ciphertext

  if #blocks == 0 then
    Buffer.save_buffer(plaintext)
    return
  elseif #blocks > 0 and not recipient then
    -- ⚠️ Warning and confirmation prompt
    local choice = vim.fn.confirm(
      '⚠️ No GPG recipient found in the front matter.\n'
        .. 'The file will be saved unencrypted.\n\n'
        .. 'Do you want to continue?',
      '&Yes\n&No',
      2 -- default: No
    )

    if choice ~= 1 then
      log.info('Save cancelled.')
      return
    end

    -- Continue without encryption
    Buffer.save_buffer(plaintext)
    return
  end

  -- Normal encryption
  ciphertext = Encrypt.encrypt_text(plaintext, assert(recipient))
  if not ciphertext then
    log.debug('Échec du chifrement')
    return
  end
  Buffer.save_buffer(ciphertext)
  log.info('Fichier chiffré écrit, buffer conservé en clair.')
end

--- Retire la passphrase de la mémoire
function M.clear_passphrase()
  _cached_passphrase = nil
  log.info('Passphrase oubliée de la session.')
end

return M
