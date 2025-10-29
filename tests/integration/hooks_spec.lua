require('plenary')

local H = require('privymd.core.gpg.helpers')
local Hooks = require('privymd.hooks')
local Passphrase = require('privymd.core.passphrase')
local log = require('privymd.utils.logger')

--- create a buffer and set it current
---
--- @param lines? string[]
--- @return number buffer
local function make_test_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
  return buf
end

describe('Hooks', function()
  local gpg

  before_each(function()
    --- @diagnostic disable-next-line: duplicate-set-field
    H.write_and_close = function(_, _) end

    gpg = {
      decrypt = function(_, _, on_exit)
        log.trace(' -> entry in spawn_gpg() (mock)')
        vim.defer_fn(function()
          on_exit(0, 'decrypted block\n', '')
        end, 10)
        return { pid = 1234, close = function() end }, nil
      end,
      encrypt = function(_, _, on_exit)
        on_exit(0, '-----BEGIN PGP MESSAGE-----\nEncrypted block\n-----END PGP MESSAGE-----', '')
        return {}, nil
      end,
    }
  end)

  describe('clear_passphrase', function()
    it('should wipe passphrase from memory', function()
      math.randomseed(os.time())
      local new_secret = tostring(math.random())

      Passphrase.set(new_secret)
      local cached_passphrase = Passphrase.get()

      assert.is_equals(cached_passphrase, new_secret)
      Hooks.clear_passphrase()
      cached_passphrase = Passphrase.get()

      assert.is_nil(cached_passphrase)
    end)
  end)

  describe('toggle_encryption', function()
    local buf
    before_each(function()
      buf = make_test_buffer({
        '---',
        'gpg-recipient: user@test',
        '---',
        '````gpg',
        '-----BEGIN PGP MESSAGE-----',
        'Encrypted block',
        '-----END PGP MESSAGE-----',
        '````',
        'clear text',
        '````gpg',
        'secret block',
        '````',
      })
    end)

    it('should detect if outside a block', function()
      -- outside block
      --- @diagnostic disable-next-line: duplicate-set-field
      vim.api.nvim_win_get_cursor = function(_)
        return { 9, 0 }
      end

      local result = Hooks.toggle_encryption()
      assert.are_equal(2, result)
    end)

    it('should notify if no recipient to the encryption', function()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        '---',
        'gpg-recipient: ',
        '---',
        '````gpg',
        'secret block',
        '````',
      })
      -- outside block
      --- @diagnostic disable-next-line: duplicate-set-field
      vim.api.nvim_win_get_cursor = function(_)
        return { 5, 0 }
      end

      local result = Hooks.toggle_encryption()
      assert.are_equal(3, result)
    end)

    it('should decrypt the encrypted block contents', function()
      H.spawn_gpg = gpg.decrypt

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        '---',
        'gpg-recipient: user@test',
        '---',
        '````gpg',
        '-----BEGIN PGP MESSAGE-----',
        'Encrypted block',
        '-----END PGP MESSAGE-----',
        '````',
      })
      --- @diagnostic disable-next-line: duplicate-set-field
      vim.api.nvim_win_get_cursor = function(_)
        return { 5, 0 }
      end

      local result = Hooks.toggle_encryption()

      vim.wait(300, function()
        local line = vim.api.nvim_buf_get_lines(buf, 4, 5, true)
        return line[1] == 'decrypted block'
      end, 10)

      local out = vim.api.nvim_buf_get_lines(buf, 4, 5, true)
      assert.are_equals('decrypted block', out[1])
      assert.is_nil(result)
    end)

    it('should encrypt the clear block contents', function()
      H.spawn_gpg = gpg.encrypt

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        '---',
        'gpg-recipient: user@test',
        '---',
        '````gpg',
        'secret to hide',
        '````',
      })
      --- @diagnostic disable-next-line: duplicate-set-field
      vim.api.nvim_win_get_cursor = function(_)
        return { 5, 0 }
      end

      local result = Hooks.toggle_encryption()

      vim.wait(300, function()
        local line = vim.api.nvim_buf_get_lines(buf, 4, 5, true)
        return line[1] == '-----BEGIN PGP MESSAGE-----'
      end, 10)

      local out = vim.api.nvim_buf_get_lines(buf, 4, 5, true)
      assert.are_equals('-----BEGIN PGP MESSAGE-----', out[1])
      assert.is_nil(result)
    end)
  end)

  describe('decrypt_buffer', function()
    before_each(function()
      make_test_buffer({
        '---',
        'gpg-recipient: user@test',
        '---',
        '````gpg',
        '-----BEGIN PGP MESSAGE-----',
        'Encrypted block',
        '-----END PGP MESSAGE-----',
        '````',
        'clear text',
        '````gpg',
        'secret block',
        '````',
      })
    end)

    it('should leave buffer untouched if no encrypted blocks', function()
      local plain_buffer = {
        '---',
        'gpg-recipient: user@test',
        '---',
        'clear text',
        '````gpg',
        'secret block',
        '````',
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, plain_buffer)

      local _, mess = Hooks.decrypt_buffer()

      vim.wait(300, function()
        return mess == 'No encrypted GPG blocks found.'
      end, 10)

      local out = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      assert.are_same(plain_buffer, out)
    end)

    it('should decrypt buffer', function()
      H.spawn_gpg = gpg.decrypt

      Hooks.decrypt_buffer()

      local decrypted
      vim.wait(300, function()
        decrypted = vim.api.nvim_buf_get_lines(0, 4, 5, false)
        return decrypted[1] == 'decrypted block'
      end, 10)
      local untouched = vim.api.nvim_buf_get_lines(0, 8, 9, false)

      assert.is_equal('decrypted block', decrypted[1])
      assert.is_equal('secret block', untouched[1])
    end)
  end)

  describe('encrypt_and_save_buffer', function()
    before_each(function()
      make_test_buffer()
    end)
    describe('if no recipient', function()
      before_each(function()
        -- create a buffer and set it current
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          '---',
          'gpg-recipient: ',
          '---',
          '````gpg',
          'secret block',
          '````',
        })
      end)
      it('should not save if not ok', function()
        --- @diagnostic disable-next-line: duplicate-set-field
        vim.fn.confirm = function()
          return 2
        end
        local _, mess = Hooks.encrypt_and_save_buffer()

        assert.is_equal('Save cancelled.', mess)
      end)

      it('should save plaintext if ok', function()
        --- @diagnostic disable-next-line: duplicate-set-field
        vim.fn.writefile = function(_, _)
          return 'ok'
        end
        --- @diagnostic disable-next-line: duplicate-set-field
        vim.fn.confirm = function()
          return 1
        end
        local _, mess = Hooks.encrypt_and_save_buffer()

        assert.is_equal('Saved without encryption.', mess)
      end)
    end)

    describe('if no GPG blocks', function()
      before_each(function()
        --- @diagnostic disable-next-line: duplicate-set-field
        vim.fn.writefile = function(_, _)
          return 'ok'
        end
        H.spawn_gpg = gpg.encrypt
      end)
      it('should save plaintext', function()
        local plain_buffer = {
          '---',
          'gpg-recipient: user@test',
          '---',
          'clear text',
          '````gpg',
          '-----BEGIN PGP MESSAGE-----',
          'Encrypted block',
          '-----END PGP MESSAGE-----',
          '````',
        }
        vim.api.nvim_buf_set_lines(0, 0, -1, false, plain_buffer)

        local _, mess = Hooks.encrypt_and_save_buffer()

        assert.is_equal('Saved without anything to encrypt.', mess)
      end)
    end)

    it('should encrypt and save buffer', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      vim.fn.writefile = function(_, _)
        return 'ok'
      end
      local plain_buffer = {
        '---',
        'gpg-recipient: user@test',
        '---',
        'clear text',
        '````gpg',
        'secret block',
        '````',
      }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, plain_buffer)

      local _, mess = Hooks.encrypt_and_save_buffer()
      assert.is_nil(mess)
    end)
  end)
end)
