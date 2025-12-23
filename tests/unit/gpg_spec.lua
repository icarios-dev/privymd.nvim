require('plenary')

local H = require('privymd.core.gpg.helpers')
local gpg = require('privymd.core.gpg.gpg')

describe('GPG core module', function()
  before_each(function()
    -- Mock helpers to avoid real GPG calls
    --- @diagnostic disable-next-line: duplicate-set-field
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

    --- @diagnostic disable-next-line: duplicate-set-field
    H.write_and_close = function(_, _) end

    --- @diagnostic disable-next-line: duplicate-set-field
    H.normalize_output = function(out)
      return out:gsub('\r', '')
    end
  end)

  describe('decrypt', function()
    it('should return nil on empty input', function()
      assert.is_nil(gpg.decrypt({}, 'test'))
    end)

    it('should return nil on fail and empty passphrase', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        on_exit(1, '', 'error message')
        return {}, nil
      end

      assert.is_nil(gpg.decrypt({ 'test' }, ''))
    end)

    it('should return nil and error mesasge on failure', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        on_exit(1, '', 'error message')
        return {}, nil
      end

      local result, err = gpg.decrypt({ 'test' }, '')
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it('should return split output on success', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        on_exit(0, 'line1\nline2', '')
        return {}, nil
      end

      local result, err = gpg.decrypt({ 'ENCRYPTED' }, 'secret')
      assert.is_nil(err)
      assert.is_same({ 'line1', 'line2' }, result)
    end)
  end)

  describe('encrypt', function()
    it('should return nil on empty input', function()
      assert.is_nil(gpg.encrypt({}, 'recipient'))
    end)

    it('should return nil and error mesasge on failure', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        on_exit(2, '', 'error message')
        return {}, nil
      end

      local result, err = gpg.encrypt({ 'Plaintext' }, 'recipient')
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it('should return split output on success', function()
      local expected_out = '-----BEGIN PGP MESSAGE-----\nEncrypted block\n-----END PGP MESSAGE-----'

      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        on_exit(0, expected_out, '')
        return {}, nil
      end

      local result = gpg.encrypt({ 'Plaintext' }, 'recipient')
      assert.same(vim.split(expected_out, '\n', { trimempty = true }), result)
    end)

    it('should not duplicate recipient in gpg args across calls', function()
      local expected_out = '-----BEGIN PGP MESSAGE-----\nEncrypted block\n-----END PGP MESSAGE-----'
      local call_count = 0

      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(args, _, on_exit)
        call_count = call_count + 1
        assert.is_equal('recipient', args[#args], 'last argument passed to gpg should be recipient')
        assert.is_falsy(
          'recipient' == args[#args - 1],
          'second-to-last argument passed to gpg should not be recipient'
        )
        on_exit(0, expected_out, '')
        return {}, nil
      end

      -- 1er appel
      gpg.encrypt({ 'Plaintext' }, 'recipient')

      -- 2e appel (c'est celui qui cassait avant le fix)
      gpg.encrypt({ 'Plaintext' }, 'recipient')

      assert.is_equal(2, call_count, 'spawn_gpg should be called twice')
    end)
  end)

  describe('is_gpg_available', function()
    it('should return true if gpg executable found', function()
      vim.fn = {
        executable = function()
          return 1
        end,
      }
      assert.is_true(gpg.is_gpg_available())
    end)

    it('should return false if gpg executable missing', function()
      vim.fn = {
        executable = function()
          return 0
        end,
      }
      local ok = gpg.is_gpg_available()
      assert.is_false(ok)
    end)
  end)
end)
