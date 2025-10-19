require('plenary')

local helpers = require('privymd.core.gpg.helpers')

describe('GPG helpers', function()
  it('creates all expected pipes', function()
    local pipes = helpers.make_pipes(true)
    assert.is_table(pipes)
    assert(pipes.stdin)
    assert(pipes.stdout)
    assert(pipes.stderr)
    assert(pipes.pass)
    helpers.close_all(pipes)
  end)

  it('spawns a dummy process and captures output', function()
    local pipes = helpers.make_pipes(false)
    local done = false
    local stdout, stderr

    helpers.spawn_gpg({ '--version' }, pipes, function(_, out, err)
      stdout, stderr, done = out, err, true
    end)

    vim.wait(1000, function()
      return done
    end)
    assert.is_true(done)
    assert.truthy(stdout:match('GnuPG') or stdout ~= '')
    assert.is_string(stderr)
  end)

  it('write_and_close executes safely on an open pipe', function()
    local pipe = assert(vim.uv.new_pipe(false))

    local ok, err = pcall(function()
      helpers.write_and_close(pipe, 'dummy-data')
    end)
    -- The call should not raise an error
    assert(ok, 'write_and_close() threw an error: ' .. tostring(err))
  end)
end)
