require('plenary')

describe('privymd.frontmatter', function()
  local Front

  before_each(function()
    Front = require('privymd.core.frontmatter')
  end)

  -- No YAML front-matter at all
  it('returns nil when file has no YAML front-matter', function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'plain text',
      'no YAML section',
    })
    assert.is_nil(Front.get_file_recipient())
  end)

  -- Unclosed front-matter
  it('returns nil when front-matter is unclosed', function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      '---',
      'gpg-recipient: missing@end',
      '# no closing ---',
    })
    assert.is_nil(Front.get_file_recipient())
  end)

  -- Invalid closing marker (...)
  it('returns nil when front-matter is closed with dots', function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      '---',
      'gpg-recipient: with@dots',
      '...',
    })
    assert.is_nil(Front.get_file_recipient())
  end)

  -- Front-matter not at top of file
  it('returns nil when front-matter does not start at first line', function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'title: Wrong position',
      '---',
      'gpg-recipient: should@be.ignored',
      '---',
    })
    assert.is_nil(Front.get_file_recipient())
  end)

  -- Front-matter without recipient key
  it('returns nil when front-matter has no gpg-recipient key', function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      '---',
      'title: Something',
      'author: Foo',
      '---',
    })
    assert.is_nil(Front.get_file_recipient())
  end)

  -- Empty recipient key
  it('returns nil when gpg-recipient key is empty', function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      '---',
      'gpg-recipient:    ',
      '---',
    })
    assert.is_nil(Front.get_file_recipient())
  end)

  -- Valid front-matter with recipient
  it('extracts the GPG recipient when found in front-matter', function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      '---',
      'title: Secrets',
      'gpg-recipient: user@example.com',
      '---',
      '# markdown',
    })

    local recipient = Front.get_file_recipient()
    assert.are.equal('user@example.com', recipient)
  end)

  -- Recipient key with indentation or case variation
  it('extracts the GPG recipient even with indentation or case differences', function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      '---',
      '   GPG-Recipient:  INDENTED@example.com  ',
      '---',
    })

    local recipient = Front.get_file_recipient()
    assert.are.equal('INDENTED@example.com', recipient)
  end)
end)
