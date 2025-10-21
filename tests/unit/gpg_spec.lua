local H = require('privymd.core.gpg.helpers')
local gpg = require('privymd.core.gpg')

describe('GPG core module', function()
  before_each(function()
    -- Mock helpers to avoid real GPG calls
    H.make_pipes = function()
      return {
        stdin = {
          write = function() end,
          shutdown = function(cb)
            if cb then
              cb()
            end
          end,
          is_closing = function()
            return false
          end,
          close = function() end,
        },
        pass = {
          write = function() end,
          shutdown = function(cb)
            if cb then
              cb()
            end
          end,
          is_closing = function()
            return false
          end,
          close = function() end,
        },
      }
    end

    H.write_and_close = function(_, _) end

    H.normalize_output = function(out)
      return out:gsub('\r', '')
    end
  end)

  ---------------------------------------------------------------------
  -- decrypt_async
  ---------------------------------------------------------------------
  it('decrypt_async should handle empty input gracefully', function()
    local called = false
    gpg.decrypt_async({}, 'test', function(result, err)
      called = true
      assert.is_nil(result)
      assert.equals('empty', err)
    end)
    assert(called)
  end)

  it('decrypt_async should invoke callback with decrypted output', function()
    local called = false

    H.spawn_gpg = function(_, _, on_exit)
      vim.defer_fn(function()
        on_exit(0, 'line1\nline2', '')
      end, 10)
      return {}, nil
    end

    gpg.decrypt_async({ 'ENCRYPTED' }, 'secret', function(result, err)
      called = true
      assert.is_nil(err)
      assert.same({ 'line1', 'line2' }, result)
    end)

    vim.wait(100, function()
      return called
    end)
    assert.is_true(called)
  end)

  it('decrypt_async should handle error code properly', function()
    local called = false

    H.spawn_gpg = function(_, _, on_exit)
      vim.defer_fn(function()
        on_exit(2, '', 'Decryption failed')
      end, 10)
      return {}, nil
    end

    gpg.decrypt_async({ 'ENCRYPTED' }, 'secret', function(result, err)
      called = true
      assert.is_nil(result)
      assert.matches('Decryption failed', err)
    end)

    vim.wait(100, function()
      return called
    end)
    assert.is_true(called)
  end)

  ---------------------------------------------------------------------
  -- encrypt_sync
  ---------------------------------------------------------------------
  it('encrypt_sync should return nil on empty input', function()
    assert.is_nil(gpg.encrypt_sync({}, 'recipient'))
  end)

  it('encrypt_sync should return split output on success', function()
    local expected_out = '-----BEGIN PGP MESSAGE-----\nEncrypted block\n-----END PGP MESSAGE-----'

    H.spawn_gpg = function(_, _, on_exit)
      on_exit(0, expected_out, '')
      return {}, nil
    end

    local result = gpg.encrypt_sync({ 'Plaintext' }, 'recipient')
    assert.same(vim.split(expected_out, '\n', { trimempty = true }), result)
  end)

  it('encrypt_sync should return nil on failure', function()
    H.spawn_gpg = function(_, _, on_exit)
      on_exit(2, '', 'error message')
      return {}, nil
    end

    local result = gpg.encrypt_sync({ 'Plaintext' }, 'recipient')
    assert.is_nil(result)
  end)

  ---------------------------------------------------------------------
  -- is_gpg_available
  ---------------------------------------------------------------------
  it('is_gpg_available should return true if gpg executable found', function()
    vim.fn = {
      executable = function()
        return 1
      end,
    }
    assert.is_true(gpg.is_gpg_available())
  end)

  it('is_gpg_available should return false if gpg executable missing', function()
    vim.fn = {
      executable = function()
        return 0
      end,
    }
    local ok = gpg.is_gpg_available()
    assert.is_false(ok)
  end)
end)
