--- Inspect encrypted block to extract encryption keys info
--- @module 'privymd.core.gpg.inspect'

local H = require('privymd.core.gpg.helpers')
local log = require('privymd.utils.logger')

local M = {}

--- Parse :pubkey lines from --list-packets output
---
--- @param data string
--- @return string[] keyids
local function parse_keyids(data)
  log.debug(data)
  local keys, seen = {}, {}
  for line in data:gmatch('[^\r\n]+') do
    if line:match('^:pubkey') then
      local cols = vim.split(line, ' ')
      local keyid = cols[9]
      if keyid and #keyid > 0 and not seen[keyid] then
        table.insert(keys, keyid)
        seen[keyid] = true
      end
    end
  end

  return keys
end

--- Parse uid lines from --list-keys output.
---
--- @param data string
--- @return string|nil first_uid
local function parse_first_uid(data)
  log.debug(data)
  for line in data:gmatch('[^\r\n]+') do
    if line:match('^uid:') then
      local cols = vim.split(line, ':')

      return cols[10] or cols[#cols]
    end
  end
  return nil
end

--- Identifies the encryption keys of the block
---
--- @param ciphertext string[] path or lines
--- @return string[]|nil keys
--- @return string? err error message
local function keys_of_block(ciphertext)
  local args =
    { '--batch', '--quiet', '--pinentry-mode', 'error', '--with-colons', '--list-packets' }
  local input = table.concat(ciphertext, '\n')

  local stdout, stderr = H.run_gpg(args, input)
  if not stdout or stdout == '' then
    return nil, 'No output from gpg: ' .. (stderr or 'unknown error')
  end

  local keyids = parse_keyids(stdout)
  if not keyids or #keyids == 0 then
    return {}
  end

  return keyids
end

--- @class InfoKey
--- @field keyid string
--- @field uid string?

--- Finds the recipients of an encrypted block.
---
--- @param ciphertext string[]
--- @return InfoKey[]|nil results table of { keyid = string, uid = string? }
--- @return string? err error message
function M.inspect(ciphertext)
  local keyids, err = keys_of_block(ciphertext)
  if not keyids then
    local err_mess = 'Failure to identify the block encryption keys. ' .. err
    return nil, err_mess
  end

  local results = {}
  for _, keyid in ipairs(keyids) do
    local args = { '--batch', '--quiet', '--with-colons', '--list-keys', keyid }

    local gpg_output = H.run_gpg(args)
    local uid = gpg_output and parse_first_uid(gpg_output) or nil

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
