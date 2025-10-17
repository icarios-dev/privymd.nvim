--- @class Logger
--- @field trace function(msg: string)
--- @field debug function(msg: string)
--- @field info function(msg: string)
--- @field warn function(msg: string)
--- @field error function(msg: string)
local M = {}

-- niveau par défaut
local log_level = vim.log.levels.INFO

local LEVELS = {
  trace = vim.log.levels.TRACE,
  debug = vim.log.levels.DEBUG,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

-- génère une fonction par niveau
for name, lvl in pairs(LEVELS) do
  M[name] = function(msg)
    if lvl >= log_level then
      vim.notify(msg, lvl)
    end
  end
end

--- changer le niveau dynamiquement en utilisant LEVELS directement
--- @param level_str string
function M.set_log_level(level_str)
  local lvl = LEVELS[level_str:lower()]
  if lvl then
    log_level = lvl
  else
    M.warn('Invalid log level: ' .. level_str)
  end
end

return M
