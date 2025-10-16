require('plenary')

local Block = require('privymd.block')

describe('privymd.block', function()
  -- find_blocks()
  describe('find_blocks()', function()
    it('returns an empty list when no GPG blocks exist', function()
      local lines = { 'plain text', 'nothing here' }
      local blocks = Block.find_blocks(lines)
      assert.are.same({}, blocks)
    end)

    it('detects a single GPG block', function()
      local lines = {
        'header',
        '````gpg',
        'secret line',
        'another',
        '````',
        'footer',
      }

      local blocks = Block.find_blocks(lines)
      assert.are.equal(1, #blocks)
      assert.are.equal(2, blocks[1].start)
      assert.are.equal(5, blocks[1].end_)
      assert.are.same({ 'secret line', 'another' }, blocks[1].content)
    end)

    it('detects multiple GPG blocks and returns them in reverse order', function()
      local lines = {
        '````gpg',
        'A',
        '````',
        'middle',
        '````gpg',
        'B',
        '````',
      }

      local blocks = Block.find_blocks(lines)
      -- find_blocks inserts blocks in reverse order
      assert.are.equal(2, #blocks)
      assert.are.equal(5, blocks[1].start)
      assert.are.equal(7, blocks[1].end_)
      assert.are.equal(1, blocks[2].start)
      assert.are.equal(3, blocks[2].end_)
    end)

    it('returns an empty list when a block is incomplete or malformed', function()
      local lines = {
        'intro',
        '````gpg',
        'missing closing fence',
        'still missing',
        'footer',
      }

      local blocks = Block.find_blocks(lines)
      assert.are.same({}, blocks)
    end)

    it('recovers from an unclosed block followed by a new valid one', function()
      local lines = {
        '````gpg',
        'incomplete block',
        'should be clear',
        '````gpg',
        'second block',
        '````',
        'after',
      }

      local blocks = Block.find_blocks(lines)
      -- Only the second block should be detected
      assert.are.equal(1, #blocks)
      assert.are.equal(4, blocks[1].start)
      assert.are.equal(6, blocks[1].end_)
      assert.are.same({ 'second block' }, blocks[1].content)
    end)
  end)

  -- set_block_content()
  describe('set block', function()
    local original, new_block, destination

    before_each(function()
      original = {
        'start',
        '````gpg',
        'original content',
        '````',
        'end',
      }
      new_block = { start = 2, end_ = 4, content = { 'new', 'content' } }
      destination = {
        'start',
        '````gpg',
        'new',
        'content',
        '````',
        'end',
      }
    end)

    -- section set_block_content()
    describe('set_block_content()', function()
      it('returns a new table where the given block is replaced', function()
        local updated = Block.set_block_content(original, new_block)

        assert.are.same(destination, updated)
      end)

      it('returns the same table when new_content is invalid', function()
        original = { 'a', '````gpg', 'b', '````', 'c' }
        local invalid_block = { start = 2, end_ = 4, content = 'bad_content' }
        local result = Block.set_block_content(original, invalid_block)

        assert.are.same(original, result)
      end)
    end)

    -- section update_buffer()
    describe('set_block_in_buffer()', function()
      it('replaces lines in the current buffer with the given block', function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, original)

        Block.set_block_in_buffer(new_block)
        local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

        assert.are.same(destination, result)
      end)
    end)
  end)

  -- is_encrypted()
  describe('is_encrypted()', function()
    it('returns true when block content starts with a valid PGP header', function()
      local block = {
        content = {
          '-----BEGIN PGP MESSAGE-----',
          'some data',
          '-----END PGP MESSAGE-----',
        },
      }
      assert.is_true(Block.is_encrypted(block))
    end)

    it('returns false when block content is plaintext', function()
      local block = { content = { 'no header here' } }
      assert.is_false(Block.is_encrypted(block))
    end)

    it('returns false when block content is empty or invalid', function()
      assert.is_false(Block.is_encrypted(nil))
      assert.is_false(Block.is_encrypted({ content = {} }))
    end)
  end)
end)
