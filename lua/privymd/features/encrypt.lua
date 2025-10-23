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
local Gpg = require('privymd.core.gpg.gpg')
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
--- @return error? err error message
function M.encrypt_block(block, recipient, text)
  if not block then
    return nil, 'No block provided.'
  end

  if not recipient then
    return nil, 'No GPG recipient provided.'
  end

  if not Block.is_encrypted(block) then
    local ciphertext, err = Gpg.encrypt_sync(block.content, recipient)
    if not ciphertext then
      return nil, err
    end
    block.content = ciphertext
  end

  if text then
    local new_text, err = Block.set_block_content(text, block)
    if not new_text then
      return nil, err
    end
    return new_text
  else
    local _, err = Block.set_block_in_buffer(block)
    if err then
      log.error(err)
    end
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
--- or `nil` when no block was encrypted
function M.encrypt_text(text, recipient)
  log.trace('Encrypting buffer content…')
  local blocks = Block.find_blocks(text)

  --- @param text_to_update string[]
  --- @return string[]
  local function update(text_to_update)
    for _, block in ipairs(blocks) do
      local new_text, err = M.encrypt_block(block, recipient, text_to_update)
      if not new_text then
        log.error(('Skipping block %d: encryption failed. '):format(block.start) .. err)
      end
      text_to_update = assert(new_text)
    end
    return text_to_update
  end

  if #blocks ~= 0 then
    text = update(text)
  else
    log.trace('No GPG block detected.')
  end

  return text
end

return M
