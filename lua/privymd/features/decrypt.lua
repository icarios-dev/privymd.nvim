--- @module 'privymd.features.decrypt'
--- Handles decryption of GPG-encrypted blocks.
--- Manages the cached passphrase, user prompting, and interaction
--- with GPG and Block modules

local Block = require('privymd.core.block')
local Gpg = require('privymd.core.gpg.gpg')
local Key = require('privymd.core.gpg.inspect')
local Passphrase = require('privymd.core.passphrase')
local log = require('privymd.utils.logger')

--- Prompt the user for a GPG passphrase.
---
--- @param ciphertext string[]
--- @return string? passphrase entered by the user
--- null if no key is found in the ciphertext or no match with the keys
--- available in the keyring
local function ask_passphrase(ciphertext)
  local recipients, err = Key.inspect(ciphertext)
  if not recipients then
    log.debug('Failed to inspect recipients: ' .. tostring(err))
    return nil
  end
  if #recipients == 0 then
    log.info('No recipient key found in ciphertext')
    return nil
  end

  for _, key in ipairs(recipients) do
    if key.uid then
      local prompt = ('Passphrase for key\n : %s\n ? '):format(key.uid)
      local result

      -- Allow a delay for the UI (Noice) to finish initializing before the call
      vim.defer_fn(function()
        result = vim.fn.inputsecret(prompt)
      end, 50)
      while result == nil do
        vim.wait(10)
      end

      return result
    end
  end

  return nil
end

local M = {}

--- Decrypt a GPG block.
--- Invokes Gpg.decrypt() and updates the buffer content.
---
--- Behavior:
--- - If a passphrase is provided, updates the cached value.
--- - On success: replaces the block content with plaintext and updates the buffer.
--- - On failure:
---   - If no passphrase was given, prompts the user and retries once.
---   - Otherwise logs the failure, clears the cache, and notifies the user.
---
--- @param block GpgBlock block to decrypt
--- @param passphrase? string optional passphrase
--- @param target_text? string[] Optional text table; if provided, a new table with
--- the encrypted block replaced is returned instead of modifying the buffer.
--- @return string[]|nil updated_text Returns the updated text if `text` was given,
--- or `nil` when operating directly on the active buffer.
--- @return error? err error message
function M.decrypt_block(block, passphrase, target_text)
  if not block then
    return nil, 'No block provided.'
  end

  if not Block.is_encrypted(block) then
    log.trace('Block is not encrypted - skipping.')
    return target_text
  end

  if passphrase and #passphrase > 0 then
    -- Update cached passphrase
    Passphrase.set(passphrase)
  end

  local plaintext, err = Gpg.decrypt(block.content, passphrase)

  if err and err ~= '' then
    log.info(('Decrypt failed for block starting at %d'):format(block.start))
    log.debug('Decryption aborted: ' .. err)
    Passphrase.wipeout()
    return nil, err
  end

  if not plaintext and not passphrase then
    log.debug('Retrying decryption after prompting for passphrase…')
    local pass = ask_passphrase(block.content)
    if pass and pass ~= '' then
      return M.decrypt_block(block, pass, target_text)
    end
  end

  block.content = plaintext or block.content

  if not target_text then
    local _, set_err = Block.set_block_in_buffer(block)
    if set_err then
      return nil, set_err
    end
  else
    local new_text, set_err = Block.set_block_content(target_text, block)
    if not new_text then
      return nil, set_err
    end
    return new_text
  end
end

--- Decrypt all GPG code blocks within a text table.
--- This is the high-level function typically called by user-facing commands
--- to process a whole Markdown document or any string list.
---
--- @param text string[]
--- @param passphrase string|nil
--- @return string[] decrypted_text Updated text table if decryption occurred
--- @nodiscard
function M.decrypt_text(text, passphrase)
  local blocks = Block.find_blocks(text)

  --- @param text_to_update string[]
  --- @return string[]
  --- @nodiscard
  local function update(text_to_update)
    for _, block in ipairs(blocks) do
      local new_text, err = M.decrypt_block(block, passphrase, text_to_update)
      if not new_text then
        log.error(('Skipping block %d: decryption failed. '):format(block.start) .. err)
      else
        text_to_update = new_text
      end
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
