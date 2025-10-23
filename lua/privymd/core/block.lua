--- @module 'privymd.core.block'
--- Utilities for detecting, manipulating, and inspecting GPG Markdown blocks.
--- These fenced blocks use the syntax:
--- ````
--- ````gpg
--- <content>
--- ````
--- ````
local log = require('privymd.utils.logger')

local M = {}

local FENCE_OPENING = '````gpg'
local FENCE_CLOSING = '````'

--- Find all GPG code blocks within a list of text lines.
--- A valid block starts with ````gpg and ends with ````.
---
--- ⚠️ Returned blocks are listed in **reverse order (bottom-to-top)**.
--- This ensures correct index preservation when encrypting multiple
--- blocks in sequence: since ciphertext length may differ from plaintext,
--- processing from bottom to top prevents shifting subsequent indices.
---
--- @param text string[] List of text lines to inspect.
--- @return GpgBlock[] blocks List of detected GPG blocks.
function M.find_blocks(text)
  log.trace('Looking for blocks…')
  local blocks = {}

  local in_block = false
  local start_line, content

  for line_number, value in ipairs(text) do
    if value:match('^' .. FENCE_OPENING .. '$') then
      if in_block then
        -- Previous block not closed → reset detection
        log.warn(
          string.format(
            'Unclosed GPG block detected before line %d — restarting detection.',
            line_number
          )
        )
        -- On repart à zéro avec le nouveau bloc
        start_line = line_number
        content = {}
      else
        in_block = true
        start_line = line_number
        content = {}
        log.trace('Fence opening : ' .. start_line)
      end
    elseif in_block and value:match('^' .. FENCE_CLOSING .. '$') then
      in_block = false
      local end_line = line_number

      -- Reverse collection to preserve valid indices
      table.insert(blocks, 1, { start = start_line, end_ = end_line, content = content })
      log.debug(string.format('Block found between : %d and %d', start_line, end_line))
    elseif in_block then
      table.insert(content, value)
    end
  end

  log.debug(#blocks .. ' blocks found.')
  return blocks
end

--- Build a GPG Markdown block including its fences.
--- @param content string[] Inner lines of the block.
--- @return string[] gpg_block Full block with opening/closing fences.
local function build_gpg_block(content)
  local gpg_block = { FENCE_OPENING }
  vim.list_extend(gpg_block, content)
  table.insert(gpg_block, FENCE_CLOSING)

  return gpg_block
end

--- Replace a GPG block’s content within a text list (out-of-buffer operation).
--- Returns a **new table** with the specified block replaced by its new content.
---
--- @param lines string[] Entire text content of the file.
--- @param block GpgBlock Block to replace (must include `.content`).
--- @return string[] new_lines Updated text content.
function M.set_block_content(lines, block)
  if type(lines) ~= 'table' then
    return lines
  end
  if type(block) ~= 'table' or type(block.content) ~= 'table' then
    log.error("Invalid block format: expected table with field 'content'.")
    return lines
  end

  local block_lines = build_gpg_block(block.content)

  local new_lines = {}
  vim.list_extend(new_lines, vim.list_slice(lines, 1, block.start - 1))
  vim.list_extend(new_lines, block_lines)
  vim.list_extend(new_lines, vim.list_slice(lines, block.end_ + 1, #lines))

  return new_lines
end

--- Replace the content of a GPG block **inside the current Neovim buffer**.
--- Explicit side effect: modifies the buffer content directly.
---
--- @param block GpgBlock The block to update within the current buffer.
function M.set_block_in_buffer(block)
  log.trace(' -> entry in set_block_in_buffer()')
  if type(block) ~= 'table' or type(block.content) ~= 'table' then
    log.error("Invalid block format: expected table with field 'content'.")
    return
  end

  local block_lines = build_gpg_block(block.content)

  vim.api.nvim_buf_set_lines(0, block.start - 1, block.end_, false, block_lines)
end

--- Print a summary of all detected GPG blocks in the current buffer.
--- Used for development and debugging.
function M.debug_list_blocks()
  local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local blocks = M.find_blocks(text)
  for index, block in ipairs(blocks) do
    print(
      string.format(
        'Block %d : lines %d-%d, %d lines',
        index,
        block.start,
        block.end_,
        #block.content
      )
    )
  end
end

--- Check whether a block’s content begins with an armored PGP header.
---
--- @param block GpgBlock
--- @return boolean is_encrypted True if block appears to contain PGP data.
function M.is_encrypted(block)
  if not block or not block.content or #block.content == 0 then
    return false
  end
  local first_line = block.content[1]
  return first_line:match('BEGIN%sPGP%sMESSAGE') ~= nil
end

return M
