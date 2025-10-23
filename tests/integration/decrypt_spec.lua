require('plenary')
local Decrypt = require('privymd.features.decrypt')
local H = require('privymd.core.gpg.helpers')
local Passphrase = require('privymd.core.passphrase')
local log = require('privymd.utils.logger')

describe('Decrypt features module', function()
  local buf, block, flag_before

  before_each(function()
    -- Mock
    --- @diagnostic disable-next-line: duplicate-set-field
    H.write_and_close = function(_, _) end

    -- create a buffer and set it current
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      '````gpg',
      'BEGIN PGP MESSAGE',
      'Encrypted block',
      'END PGP MESSAGE',
      '````',
    })

    -- define our GpgBlock
    block = {
      start = 1,
      end_ = 5,
      content = { 'BEGIN PGP MESSAGE', 'Encrypted block', 'END PGP MESSAGE' },
    }

    vim.bo.modified = false
    flag_before = vim.bo.modified
  end)

  describe('Passphrase', function()
    it('should be able to update passphrase in cache and get it back', function()
      local passphrase = 'Big secret'
      local cached_passphrase = Passphrase.get()

      Passphrase.set(passphrase)
      local result = Passphrase.get()

      assert.not_equals(cached_passphrase, result)
      assert.are_equals(passphrase, result)
    end)
  end)

  describe('decrypt_block()', function()
    it('should updates buffer content and set passphrase in cache', function()
      -- minimal process simulation
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        log.trace(' -> entry in spawn_gpg() (mock)')
        vim.defer_fn(function()
          on_exit(0, 'PLAINTEXT LINE\n', '')
        end, 10)
        return { pid = 1234, close = function() end }, nil
      end

      local done = false
      Decrypt.decrypt_block(block, 'secret', function()
        done = true
      end)

      -- Laisse le temps au temps
      vim.wait(300, function()
        return done
      end, 10)

      -- Lit le résultat
      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      assert.same({ '````gpg', 'PLAINTEXT LINE', '````' }, result)
      assert.are_equal('secret', Passphrase.get())
      assert.is_true(done)
      assert.equals(flag_before, vim.bo.modified)
    end)

    it('should not update buffer content and clear passphrase if gpg fail', function()
      -- minimal process simulation
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        log.trace(' -> entry in spawn_gpg() (mock)')
        vim.defer_fn(function()
          on_exit(1, '', '')
        end, 10)
        return { pid = 1234, close = function() end }, nil
      end

      local done = false
      Decrypt.decrypt_block(block, 'secret', function()
        done = true
      end)

      -- Laisse le temps au temps
      vim.wait(300, function()
        return done
      end, 10)

      -- Lit le résultat
      local result = vim.api.nvim_buf_get_lines(buf, 1, 4, false)

      assert.same(block.content, result)
      assert.are_nil(Passphrase.get())
      assert.is_falsy(done)
      assert.equals(flag_before, vim.bo.modified)
    end)
  end)

  describe('modified flag should not flip when it start dirty', function()
    before_each(function()
      vim.bo.modified = true
      flag_before = vim.bo.modified
    end)

    it('and decrypt_block is successufl', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        log.trace(' -> entry in spawn_gpg() (mock)')
        vim.defer_fn(function()
          on_exit(0, 'PLAINTEXT LINE\n', '')
        end, 10)
        return { pid = 1234, close = function() end }, nil
      end

      local done = false
      Decrypt.decrypt_block(block, 'secret', function()
        done = true
      end)

      -- Laisse le temps au temps
      vim.wait(300, function()
        return done
      end, 10)

      assert.is_true(done)
      assert.equals(flag_before, vim.bo.modified)
    end)

    it('and decrypt_block fail', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        log.trace(' -> entry in spawn_gpg() (mock)')
        vim.defer_fn(function()
          on_exit(1, 'PLAINTEXT LINE\n', '')
        end, 10)
        return { pid = 1234, close = function() end }, nil
      end

      local done = false
      Decrypt.decrypt_block(block, 'secret', function()
        done = true
      end)

      -- Laisse le temps au temps
      vim.wait(300, function()
        return done
      end, 10)

      assert.is_false(done)
      assert.equals(flag_before, vim.bo.modified)
    end)
  end)
end)
