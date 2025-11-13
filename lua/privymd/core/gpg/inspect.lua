--- Inspect encrypted block to extract encryption keys info
--- @module 'privymd.core.gpg.inspect'

local H = require('privymd.core.gpg.helpers')
local I = require('privymd.core.gpg.inspect_helpers')
local log = require('privymd.utils.logger')

local M = {}

--- @class InfoKey
--- @field keyid string
--- @field uid string?

--- Finds the recipients of an encrypted block.
---
--- @param ciphertext string[]
--- @return InfoKey[]|nil results table of { keyid = string, uid = string? }
--- @return string? err error message
function M.inspect(ciphertext)
  local keyids, err = I.keys_of_block(ciphertext)
  if not keyids then
    local err_mess = 'Failure to identify the block encryption keys. ' .. err
    return nil, err_mess
  end

  local results = {}
  for _, keyid in ipairs(keyids) do
    local args = { '--batch', '--quiet', '--with-colons', '--list-keys', keyid }

    local gpg_output = H.run_gpg(args)
    local uid = gpg_output and I.parse_first_uid(gpg_output) or nil

    table.insert(results, { keyid = keyid, uid = uid })
  end

  return results
end

--- Helper to log recipients (for debug or UX).
---
--- @param ciphertext string[]
function M.log_recipients(ciphertext)
  local recipients, err = M.inspect(ciphertext)
  if not recipients then
    log.debug('Failed to inspect recipients: ' .. tostring(err))
    return
  end
  if #recipients == 0 then
    log.info('No recipient key found in ciphertext')
    return
  end

  for _, r in ipairs(recipients) do
    if r.uid then
      log.info(string.format('Encrypted for: %s (%s)', r.uid, r.keyid))
    else
      log.info(string.format('Encrypted for key: %s', r.keyid))
    end
  end
end

return M
