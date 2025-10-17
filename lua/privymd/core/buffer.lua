local log = require('privymd.utils.logger')

--- @class Buffer
local M = {}

--- Save buffer
---@param buf_lines string[]
function M.save_buffer(buf_lines)
  if type(buf_lines) ~= 'table' or #buf_lines == 0 then
    log.error('Aucune donnée à écrire (buffer vide ou invalide).')
    log.debug('type : ' .. type(buf_lines))
    log.debug('Nbr de lignes à écrire : ' .. #buf_lines)
    return
  end

  local filename = vim.api.nvim_buf_get_name(0)
  local ok, err = pcall(vim.fn.writefile, buf_lines, filename)

  if not ok then
    log.error("Erreur d'écriture : " .. tostring(err))
    return
  end

  log.trace('Saved file.')
  -- Marque le buffer comme sauvegardé
  vim.bo.modified = false
end

return M
