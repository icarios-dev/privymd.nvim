--- @module 'privymd.core.decrypt'
--- Handles decryption of GPG-encrypted blocks within the buffer.
--- Manages the cached passphrase, user prompting, and interaction
--- with GPG and Block modules

local Block = require('privymd.core.block')
local Gpg = require('privymd.core.gpg')
local Passphrase = require('privymd.core.passphrase')
local log = require('privymd.utils.logger')

--- Prompt the user for a GPG passphrase.
--- @return string passphrase entered by the user
local function ask_passphrase()
  return vim.fn.inputsecret('Passphrase GPG : ')
end

local M = {}

--- Decrypt a GPG block asynchronously.
--- Invokes Gpg.decrypt_async() and updates the buffer content.
---
--- Behavior:
--- - If the block is not encrypted, calls `on_done` immediately.
--- - If a passphrase is provided, updates the cached value.
--- - On success: replaces the block content with plaintext and updates the buffer.
--- - On failure:
---   - If no passphrase was given, prompts the user and retries once.
---   - Otherwise logs the failure, clears the cache, and notifies the user.
---
--- @async
--- @param block GpgBlock block to decrypt
--- @param passphrase string|nil optional passphrase
--- @param on_done fun()|nil callback executed after completion
--- @return nil
function M.decrypt_block(block, passphrase, on_done)
  log.trace(' -> entry into decrypt_block()…')
  if not block or not Block.is_encrypted(block) then
    -- Nothing to decrypt
    if on_done then
      on_done()
    end
    log.trace('<- exit from decrypt_block()')
    return
  end

  if passphrase and #passphrase > 0 then
    -- Update cached passphrase
    Passphrase.set(passphrase)
  end

  Gpg.decrypt_async(block.content, passphrase, function(plaintext)
    log.trace(' -> entry into decrypt_async/callback')
    vim.schedule(function()
      if plaintext then
        -- Successful decryption
        block.content = plaintext
        log.trace(' - send plaintext to set_block_in_buffer()…')
        Block.set_block_in_buffer(block)
        if on_done then
          on_done()
        end
      else
        -- Decryption failed
        log.debug(('Decrypt failed for block starting at %d'):format(block.start))

        if not passphrase then
          log.debug('Retrying decryption after prompting for passphrase…')
          M.decrypt_block(block, ask_passphrase(), on_done)
          return
        end

        log.debug('Decryption aborted: incorrect passphrase or unreadable block. Process stopped.')
        log.info('Decryption aborted. Please try again later with :PrivyDecrypt command')
        Passphrase.wipeout()
        return
      end
    end)
  end)
end

return M
