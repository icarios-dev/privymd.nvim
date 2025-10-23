require('plenary')

local Buffer = require('privymd.core.buffer')

describe('core.buffer.save_buffer()', function()
  before_each(function()
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.api.nvim_buf_get_name = function()
      return 'file.md'
    end
    vim.bo.modified = true
  end)

  it('marks buffer clean on success', function()
    vim.fn = {
      writefile = function(_, _)
        return true
      end,
    }

    local _, err = Buffer.save_buffer({ 'ok' })
    assert.are_nil(err)

    assert.is_false(vim.bo.modified)
  end)

  it('keeps buffer modified on write failure', function()
    vim.fn = {
      writefile = function()
        error('error message')
      end,
    }

    Buffer.save_buffer({ 'oops' })

    assert.is_true(vim.bo.modified)
  end)

  it('returns early on empty buffer', function()
    vim.fn = {
      writefile = function(_, _)
        return true
      end,
    }

    Buffer.save_buffer({})

    assert.is_true(vim.bo.modified)
  end)
end)
