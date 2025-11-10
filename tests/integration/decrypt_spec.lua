require('plenary')
local Decrypt = require('privymd.features.decrypt')
local H = require('privymd.core.gpg.helpers')
local Passphrase = require('privymd.core.passphrase')

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
      '```gpg',
      'BEGIN PGP MESSAGE',
      'Encrypted block',
      'END PGP MESSAGE',
      '```',
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
    it('should leave untouched if the block is not encrypted', function()
      block = {
        start = 1,
        end_ = 5,
        content = { 'clear text' },
      }
      local target = { 'should not be modified' }

      local result, err = Decrypt.decrypt_block(block, nil, target)

      assert.are_equals(target, result)
      assert.is_nil(err)
      assert.are_equals(flag_before, vim.bo.modified)
    end)

    it('should not update buffer content and clear passphrase if gpg fail', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        on_exit(1, '', '')
        return { pid = 1234, close = function() end }, nil
      end

      Decrypt.decrypt_block(block, 'secret')

      local result = vim.api.nvim_buf_get_lines(buf, 1, 4, false)

      assert.are_same(block.content, result)
      assert.is_nil(Passphrase.get())
      assert.are_equals(flag_before, vim.bo.modified)
    end)

    it('should updates buffer content and set passphrase in cache', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        on_exit(0, 'PLAINTEXT LINE\n', '')
        return { pid = 1234, close = function() end }, nil
      end

      Decrypt.decrypt_block(block, 'secret')

      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      assert.are_same({ '```gpg', 'PLAINTEXT LINE', '```' }, result)
      assert.are_equals('secret', Passphrase.get())
      assert.are_equals(flag_before, vim.bo.modified)
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
        on_exit(0, 'PLAINTEXT LINE\n', '')
        return { pid = 1234, close = function() end }, nil
      end

      Decrypt.decrypt_block(block, 'secret')

      assert.equals(flag_before, vim.bo.modified)
    end)

    it('and decrypt_block fail', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        on_exit(1, 'PLAINTEXT LINE\n', '')
        return { pid = 1234, close = function() end }, nil
      end

      Decrypt.decrypt_block(block, 'secret')

      assert.equals(flag_before, vim.bo.modified)
    end)
  end)

  describe('decrypt_text()', function()
    local text, passphrase

    before_each(function()
      -- minimal process simulation
      --- @diagnostic disable-next-line: duplicate-set-field
      H.spawn_gpg = function(_, _, on_exit)
        on_exit(0, 'PLAINTEXT LINE\n', '')
        return { pid = 1234, close = function() end }, nil
      end

      text = {
        '```gpg',
        'BEGIN PGP MESSAGE',
        'Encrypted block',
        'END PGP MESSAGE',
        '```',
        '```gpg',
        'BEGIN PGP MESSAGE',
        'Second encrypted block',
        'END PGP MESSAGE',
        '```',
      }

      passphrase = 'password'
    end)

    it('should decrypt all crypted blocks in text', function()
      local result

      result = Decrypt.decrypt_text(text, passphrase)

      assert.is_table(result)
      assert.True(#result > 0)
      assert.is_equal('PLAINTEXT LINE', result[2])
      assert.equals(flag_before, vim.bo.modified)
    end)
  end)
end)
