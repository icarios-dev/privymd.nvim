require('plenary')

local Block = require('privymd.block')

describe('privymd.block', function()
  describe('find_blocks()', function()
    it('detects no blocks when none exist', function()
      local lines = { 'plain text', 'nothing here' }
      local blocks = Block.find_blocks(lines)
      assert.are.same({}, blocks)
    end)

    it('detects a single gpg block', function()
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

    it('detects multiple gpg blocks in reverse order', function()
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
      -- find_blocks insère les blocs à la position 1 → ordre inversé
      assert.are.equal(2, #blocks)
      assert.are.equal(5, blocks[1].start)
      assert.are.equal(7, blocks[1].end_)
      assert.are.equal(1, blocks[2].start)
      assert.are.equal(3, blocks[2].end_)
    end)

    it('ignores incomplete or malformed blocks', function()
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

    -- Le comportement attendu : 1 seul bloc détecté (le second)
    assert.are.equal(1, #blocks)
    assert.are.equal(4, blocks[1].start)
    assert.are.equal(6, blocks[1].end_)
    assert.are.same({ 'second block' }, blocks[1].content)
  end)

  describe('set_block_content()', function()
    it('replaces the content of a block within a list of lines', function()
      local original_lines = {
        'intro',
        '````gpg',
        'old line',
        '````',
        'outro',
      }
      local new_lines = assert(Block.set_block_content(2, 4, { 'new', 'content' }, original_lines))
      assert.is_true(vim.tbl_contains(new_lines, 'new'))
      assert.is_true(vim.tbl_contains(new_lines, 'content'))
      assert.are.equal('````gpg', new_lines[2])
      assert.are.equal('````', new_lines[5])
    end)

    it('returns the same lines if new_content is invalid', function()
      local original_lines = { 'a', '````gpg', 'b', '````', 'c' }
      local result = Block.set_block_content(2, 4, 'not a table', original_lines)
      assert.are.same(original_lines, result)
    end)
  end)

  describe('set_block_content() in buffer mode', function()
    it('updates lines directly in the active buffer', function()
      -- Crée un buffer temporaire (non listé, non nommé)
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)

      -- Contenu initial
      local original_lines = {
        'start',
        '````gpg',
        'original content',
        '````',
        'end',
      }
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, original_lines)

      -- Exécute set_block_content sans passer de table (→ mode buffer)
      Block.set_block_content(2, 4, { 'new line 1', 'new line 2' })

      -- Vérifie que le buffer a été modifié
      local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.same('````gpg', result[2])
      assert.are.same('new line 1', result[3])
      assert.are.same('new line 2', result[4])
      assert.are.same('````', result[5])
    end)
  end)

  describe('is_encrypted()', function()
    it('returns true for a valid PGP header', function()
      local block = {
        content = {
          '-----BEGIN PGP MESSAGE-----',
          'some data',
          '-----END PGP MESSAGE-----',
        },
      }
      assert.is_true(Block.is_encrypted(block))
    end)

    it('returns false for plaintext block', function()
      local block = { content = { 'no header here' } }
      assert.is_false(Block.is_encrypted(block))
    end)

    it('returns false for empty or invalid input', function()
      assert.is_false(Block.is_encrypted(nil))
      assert.is_false(Block.is_encrypted({ content = {} }))
    end)
  end)
end)
