--- @module 'privymd.core.buffer'
--- Utility for safely writing the current buffer to disk.
--- Handles error logging, ensures the buffer content is valid,
--- and resets the modified flag upon success.

local log = require('privymd.utils.logger')

local M = {}

--- Write the given buffer lines to the current file.
--- Uses `vim.fn.writefile` under the hood and performs error handling.
---
--- Behavior:
--- - Logs an error if the input is invalid or empty.
--- - Writes all lines to the file returned by `nvim_buf_get_name(0)`.
--- - On success, marks the buffer as unmodified (`vim.bo.modified = false`).
---
--- @param buf_lines string[] List of lines to write to disk.
--- @return nil, string?  err message if save failed, or nil on success
function M.save_buffer(buf_lines)
  if type(buf_lines) ~= 'table' or #buf_lines == 0 then
    log.debug('type: ' .. type(buf_lines))
    log.debug('Number of lines to write: ' .. #buf_lines)
    return nil, 'No data to write (empty or invalid buffer).'
  end

  local filename = vim.api.nvim_buf_get_name(0)
  local ok, err = pcall(vim.fn.writefile, buf_lines, filename)

  if not ok then
    return nil, 'Write error: ' .. tostring(err)
  end

  log.trace('Saved file.')
  -- Mark buffer as clean
  vim.bo.modified = false
end

return M
