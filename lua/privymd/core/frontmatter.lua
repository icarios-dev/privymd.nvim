--- @module 'privymd.core.frontmatter'
--- Utility functions for parsing YAML front-matter to extract GPG configuration.
--- In PrivyMD, the `gpg-recipient` key is used to define the encryption target.
---
--- Example:
--- ```yaml
--- ---
--- title: Private Notes
--- gpg-recipient: john@example.com
--- ---
--- ```
local log = require('privymd.utils.logger')

local M = {}

--- Retrieve the GPG recipient from YAML front-matter located
--- at the top of the current buffer (first 50 lines).
---
--- - The function searches for a `gpg-recipient:` key (case-insensitive).
--- - Returns `nil` if no YAML block is found or if the block is malformed.
--- - Returns the recipient string otherwise.
---
--- @return string|nil recipient GPG recipient identifier, or `nil` if not found.
function M.get_file_recipient()
  log.trace('Looking for recipient (strict YAML front-matter)…')

  -- Read only the first 50 lines — no need to parse the entire file
  local lines = vim.api.nvim_buf_get_lines(0, 0, 50, false)
  if #lines == 0 or not lines[1]:match('^%-%-%-%s*$') then
    log.debug("No YAML front-matter detected (missing opening '---').")
    return nil
  end

  local recipient = nil
  local has_closing_marker = false

  for i = 2, #lines do
    local line = lines[i]

    -- End of front-matter
    if line:match('^%-%-%-%s*$') then
      has_closing_marker = true
      break
    end

    -- Look for the gpg-recipient key
    local key, value = line:match('^%s*([%w%-]+):%s*(.-)%s*$')
    if key and key:lower() == 'gpg-recipient' and value ~= '' then
      recipient = value
    end
  end

  -- Ignore front-matter if it is not properly closed
  if not has_closing_marker then
    log.debug("Front-matter not properly closed with '---'. Ignoring.")
    return nil
  end

  if not recipient then
    log.trace('No GPG recipient found in front-matter.')
    return nil
  end

  log.trace('Recipient found: ' .. recipient)
  return recipient
end

return M
