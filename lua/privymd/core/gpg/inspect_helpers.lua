local H = require('privymd.core.gpg.helpers')
local log = require('privymd.utils.logger')

local M = {}

--- Parse :pubkey lines from --list-packets output
---
--- @param data string
--- @return string[] keyids
function M.parse_keyids(data)
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
function M.parse_first_uid(data)
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
function M.keys_of_block(ciphertext)
  local args =
    { '--batch', '--quiet', '--pinentry-mode', 'error', '--with-colons', '--list-packets' }
  local input = table.concat(ciphertext, '\n')

  local stdout, stderr = H.run_gpg(args, input)
  if not stdout or stdout == '' then
    return nil, 'No output from gpg: ' .. (stderr or 'unknown error')
  end

  local keyids = M.parse_keyids(stdout)
  if not keyids or #keyids == 0 then
    return {}
  end

  return keyids
end

return M
