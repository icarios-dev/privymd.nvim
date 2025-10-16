local log = require('privymd.utils.logger')
log.set_log_level = 'trace'

local M = {}

---------------------------------------------------------------------
-- 🔍 Retrieve the GPG recipient from YAML front-matter (strict mode)
---------------------------------------------------------------------
function M.get_file_recipient()
  log.trace('Looking for recipient (strict YAML front-matter)…')

  local lines = vim.api.nvim_buf_get_lines(0, 0, 50, false)
  if #lines == 0 or not lines[1]:match('^%-%-%-%s*$') then
    log.debug("No YAML front-matter detected (missing opening '---').")
    return nil
  end

  local recipient = nil
  local has_closing_marker = false

  for i = 2, #lines do
    local line = lines[i]

    -- fin du front-matter
    if line:match('^%-%-%-%s*$') then
      has_closing_marker = true
      break
    end

    -- recherche de la clé gpg-recipient
    local key, value = line:match('^%s*([%w%-]+):%s*(.-)%s*$')
    if key and key:lower() == 'gpg-recipient' and value ~= '' then
      recipient = value
    end
  end

  -- Frontmatter non fermé : on ignore
  if not has_closing_marker then
    log.debug("Front-matter not properly closed with '---'. Ignoring.")
    return nil
  end

  if not recipient then
    log.warn('⚠️ No GPG recipient found in front-matter.')
    return nil
  end

  log.trace('Recipient found: ' .. recipient)
  return recipient
end

return M
