local M = {}

-- niveau par défaut
M.log_level = vim.log.levels.INFO

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
    if lvl >= M.log_level then
      vim.notify(msg, lvl)
    end
  end
end

-- changer le niveau dynamiquement en utilisant LEVELS directement
function M.set_log_level(level_str)
  local lvl = LEVELS[level_str:lower()]
  if lvl then
    M.log_level = lvl
  else
    M.warn('Invalid log level: ' .. level_str)
  end
end

return M
