require('plenary')
local Block = require('privymd.core.block')
local Encrypt = require('privymd.features.encrypt')
local H = require('privymd.core.gpg.helpers')

describe('Encrypt features module', function()
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

    local cipher_out = '-----BEGIN PGP MESSAGE-----\nEncrypted block\n-----END PGP MESSAGE-----'
    --- @diagnostic disable-next-line: duplicate-set-field
    H.spawn_gpg = function(_, _, on_exit)
      on_exit(0, cipher_out, '')
      return {}, nil
    end
  end)

  describe('encrypt_block()', function()
    it('encrypts a plaintext block and updates its content', function()
      local block = { start = 1, end_ = 3, content = { 'secret line' } }
      assert.False(Block.is_encrypted(block))

      Encrypt.encrypt_block(block, 'user@example.com')

      assert.True(Block.is_encrypted(block))
      assert.match('BEGIN PGP MESSAGE', block.content[1])
    end)

    it('does not re-encrypt an already encrypted block', function()
      local block = {
        start = 1,
        end_ = 3,
        content = { '-----BEGIN PGP MESSAGE-----', 'cipher', '-----END PGP MESSAGE-----' },
      }

      local original = vim.deepcopy(block.content)
      Encrypt.encrypt_block(block, 'user@example.com')
      assert.same(original, block.content)
    end)

    it('returns nil when recipient is missing', function()
      local block = { start = 1, end_ = 3, content = { 'plain text' } }
      ---@diagnostic disable-next-line: param-type-mismatch
      local result = Encrypt.encrypt_block(block, nil)
      assert.is_nil(result)
    end)
  end)

  describe('encrypt_text()', function()
    it('encrypts all plaintext GPG blocks in text', function()
      local text = {
        '````gpg',
        'top secret',
        '````',
        'other text',
        '````gpg',
        'another secret',
        '````',
      }

      local result = Encrypt.encrypt_text(text, 'user@example.com')
      assert.is_table(result)
      assert.True(#result > 0)
      assert.truthy(result and result[2]:match('BEGIN PGP MESSAGE'))
    end)

    it('returns nil when no block was encrypted', function()
      --- @diagnostic disable-next-line: duplicate-set-field
      H.check_gpg = function()
        return false
      end

      local result = Encrypt.encrypt_text({ 'foo' }, 'user@example.com')
      assert.is_nil(result)
    end)
  end)
end)
