require('plenary')

local logger = require('privymd.utils.logger')

describe('Logger utility', function()
  it('should change log level dynamically', function()
    logger.set_log_level('debug')
    assert.equals(vim.log.levels.DEBUG, logger.log_level)
  end)

  it('should ignore invalid log level strings', function()
    local previous = logger.log_level
    logger.set_log_level('invalid-level')
    assert.equals(previous, logger.log_level)
  end)

  it('should provide all log methods', function()
    for _, method in ipairs({ 'trace', 'debug', 'info', 'warn', 'error' }) do
      assert.is_function(logger[method])
    end
  end)
end)
