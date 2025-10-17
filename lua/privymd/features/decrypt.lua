local Block = require('privymd.core.block')
local Gpg = require('privymd.core.gpg')
local log = require('privymd.utils.logger')

--- @class Decrypt
local M = {}

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

return M
