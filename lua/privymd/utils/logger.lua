--- @module 'privymd.utils.logger'
--- Simple logging utility using `vim.notify` for unified plugin messages.
--- Provides five log levels (trace → error) and allows dynamic configuration.

local M = {}

--- @type integer
--- Current log level (default: `vim.log.levels.INFO`)
M.log_level = vim.log.levels.INFO

--- Mapping of level names to `vim.log.levels` constants.
local LEVELS = {
  trace = vim.log.levels.TRACE,
  debug = vim.log.levels.DEBUG,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

---------------------------------------------------------------------
-- 🪵 Public logging API
---------------------------------------------------------------------

--- Internal helper to notify a message if its level is >= current log level.
--- @param lvl integer The vim log level constant.
--- @param msg string Message to display.
local function log(lvl, msg)
  if lvl >= M.log_level then
    vim.notify(msg, lvl, { title = 'PrivyMD' })
  end
end

--- Log a trace message (lowest priority).
--- @param msg string
function M.trace(msg)
  log(LEVELS.trace, msg)
end

--- Log a debug message.
--- @param msg string
function M.debug(msg)
  log(LEVELS.debug, msg)
end

--- Log an informational message.
--- @param msg string
function M.info(msg)
  log(LEVELS.info, msg)
end

--- Log a warning message.
--- @param msg string
function M.warn(msg)
  log(LEVELS.warn, msg)
end

--- Log an error message.
--- @param msg string
function M.error(msg)
  log(LEVELS.error, msg)
end

---------------------------------------------------------------------
-- ⚙️ Configuration
---------------------------------------------------------------------

--- Change the current log level dynamically.
--- @param level_str string One of: "trace" | "debug" | "info" | "warn" | "error".
function M.set_log_level(level_str)
  local lvl = LEVELS[level_str:lower()]
  if lvl then
    M.log_level = lvl
    M.info('Log level set to: ' .. level_str)
  else
    M.warn('Invalid log level: ' .. level_str)
  end
end

return M
