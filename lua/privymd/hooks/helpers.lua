local Block = require('privymd.block')
local Gpg = require('privymd.gpg')
local log = require('privymd.utils.logger')

local M = {}

-- Demande la passphrase si aucune n'est fournie
function M.ensure_passphrase(passphrase)
  if passphrase and passphrase ~= '' then
    return passphrase
  end
  return vim.fn.inputsecret('Passphrase GPG : ')
end

---------------------------------------------------------------------
-- Decrypt a single block
---------------------------------------------------------------------
function M.decrypt_block(block, passphrase, on_done)
  if not block or not Block.is_encrypted(block) then
    if on_done then
      on_done()
    end
    return
  end

  Gpg.decrypt_async(block.content, passphrase, function(plaintext)
    vim.schedule(function()
      if not plaintext then
        log.error('Failed to decrypt block.')
        if on_done then
          on_done()
        end
        return
      end

      block.content = plaintext
      Block.set_block_in_buffer(block)
      if on_done then
        on_done()
      end
    end)
  end)
end

---------------------------------------------------------------------
-- Encrypt a single block
---------------------------------------------------------------------
function M.encrypt_block(block, recipient, text)
  if not block or Block.is_encrypted(block) then
    return
  end

  local ciphertext = Gpg.encrypt_sync(block.content, recipient)
  if not ciphertext then
    log.error('Encryption failed for current block.')
    return
  end
  block.content = ciphertext

  if text then
    return Block.set_block_content(text, block)
  else
    Block.set_block_in_buffer(block)
  end
end

return M
