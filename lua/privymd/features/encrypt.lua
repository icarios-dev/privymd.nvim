--- @module 'privymd.features.encrypt'
---
--- Feature-level module handling encryption of GPG code blocks.
---
--- This module provides high-level functions for encrypting one or several
--- fenced GPG code blocks inside a Markdown buffer or any text content.
--- It relies on lower-level utilities from `privymd.core.block` and
--- `privymd.core.gpg` for block manipulation and GPG process handling.
---
--- The encryption process is transparent for the user: encrypted blocks
--- replace their plaintext content directly in the buffer or in-memory text.
---
--- Example:
--- ```lua
--- local Encrypt = require('privymd.features.encrypt')
--- local text = {
---   '````gpg',
---   'my secret note',
---   '````',
--- }
---
--- local recipient = 'user@example.com'
--- local result = Encrypt.encrypt_text(text, recipient)
--- vim.print(result)
--- ```
---
--- Each block detected as a GPG code fence will be encrypted using the
--- configured recipient. The function automatically updates the buffer or
--- returns a new text table, depending on the call context.

local Block = require('privymd.core.block')
local Gpg = require('privymd.core.gpg')
local log = require('privymd.utils.logger')

local M = {}

--- Encrypt a single fenced block within text.
--- Replaces the plaintext content of the block with its encrypted form.
---
--- @async
--- @param block GpgBlock Block to encrypt
--- @param recipient string GPG recipient identifier (email, key ID, etc.)
--- @param text? string[] Optional text table; if provided, a new table with
--- the encrypted block replaced is returned instead of modifying the buffer.
--- @return string[]? updated_text Returns the updated text if `text` was given,
--- or `nil` when operating directly on the active buffer.
function M.encrypt_block(block, recipient, text)
  if not block then
    log.error('No block provided.')
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

--- Encrypt all GPG code blocks within a text table.
--- This is the high-level function typically called by user-facing commands
--- to process a whole Markdown document or any string list.
---
--- @async
--- @param text string[] Plaintext lines to process
--- @param recipient string GPG recipient identifier (email, key ID, etc.)
--- @return string[]? encrypted_text Updated text table if encryption occurred,
--- or `nil` when no block was encrypted or GPG is unavailable.
function M.encrypt_text(text, recipient)
  if not Gpg.is_gpg_available() then
    log.warn('gpg comamnd not available — encryption aborted.')
    return
  end
  log.trace('Encrypting buffer content…')
  local blocks = Block.find_blocks(text)

  if #blocks == 0 then
    log.trace('No GPG block detected.')
    return
  end

  if not recipient then
    log.trace('No GPG recipient defined.')
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
