local Block = require('privymd.core.block')
local Gpg = require('privymd.core.gpg')
local log = require('privymd.utils.logger')

local function ask_passphrase()
  return vim.fn.inputsecret('Passphrase GPG : ')
end

--- @class Decrypt
local M = {}

M._cached_passphrase = nil

--- Renvoie la passphrase stockée en cache
--- @return string
function M.get_passphrase()
  return M._cached_passphrase
end
--- Stocke une passphrase en cache
--- @param passphrase string|nil
function M.set_passphrase(passphrase)
  M._cached_passphrase = passphrase
end

---@param block GpgBlock
---@param passphrase string|nil
---@param on_done any
---@return nil
function M.decrypt_block(block, passphrase, on_done)
  if not block or not Block.is_encrypted(block) then
    -- Nothing to do
    if on_done then
      on_done()
    end
    return
  end

  if passphrase and #passphrase > 0 then
    -- Update cached passphrase
    M.set_passphrase(passphrase)
  end

  Gpg.decrypt_async(block.content, passphrase, function(plaintext)
    vim.schedule(function()
      if plaintext then
        block.content = plaintext
        Block.set_block_in_buffer(block)
        if on_done then
          on_done()
        end
      else
        log.debug(('Decrypt failed for block starting at %d'):format(block.start))
        if not passphrase then
          log.debug('Retrying decryption after prompting for passphrase…')
          M.decrypt_block(block, ask_passphrase(), on_done)
          return
        end
        log.debug('Decryption aborted: incorrect passphrase or unreadable block. Process stopped.')
        log.info('Decryption aborted. Please try again later with :PrivyDecrypt command')
        M.set_passphrase(nil)
        return
      end
    end)
  end)
end

return M
