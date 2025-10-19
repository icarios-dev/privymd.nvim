local Block = require('privymd.core.block')
local Gpg = require('privymd.core.gpg')
local log = require('privymd.utils.logger')

--- @class Encrypt
local M = {}

--- Chiffre un bloc à l'intérieur d'un texte
--- @async
--- @param block GpgBlock
--- @param recipient string
--- @param text string[]?
--- @return string[]?
function M.encrypt_block(block, recipient, text)
  if not block then
    log.error('Aucun bloc transmis.')
    return
  end

  if not Block.is_encrypted(block) then
    local ciphertext = Gpg.encrypt_sync(block.content, recipient)
    if not ciphertext then
      log.error('Encryption failed for current block.')
      return
    end
    block.content = ciphertext
  end

  if text then
    return Block.set_block_content(text, block)
  else
    Block.set_block_in_buffer(block)
  end
end

--- Chiffre tous les blocs à l'intérieur d'un texte
--- @param text string[]
--- @param recipient string
--- @return string[]?
function M.encrypt_text(text, recipient)
  if not Gpg.is_gpg_available() then
    log.warn('GPG non disponible — chiffrement annulé.')
    return
  end
  log.trace('Chiffrement du buffer…')
  local blocks = Block.find_blocks(text)

  if #blocks == 0 then
    log.trace('Aucun bloc GPG détecté.')
    return
  end

  if not recipient then
    log.trace('Pas de destinataire de chiffrement défini.')
    return
  end

  for _, block in ipairs(blocks) do
    local new_text = M.encrypt_block(block, recipient, text)
    if not new_text then
      log.error(('Skipping block %d: encryption failed.'):format(block.start))
    else
      text = new_text
    end
  end

  log.info('Encryption complete ✔')
  return text
end

return M
