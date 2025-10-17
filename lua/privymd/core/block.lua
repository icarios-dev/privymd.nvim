local log = require('privymd.utils.logger')

--- @class Block
local M = {}

local fence_opening = '````gpg'
local fence_closing = '````'

--- Trouve tous les blocs code gpg d'un texte donné
--- @param text string[]
--- @return GpgBlock[]
function M.find_blocks(text)
  log.trace('Looking for blocks…')
  local blocks = {}

  local in_block = false
  local start_line, content

  for line_number, value in ipairs(text) do
    if value:match('^' .. fence_opening .. '$') then
      if in_block then
        -- ⚠️ Bloc précédent mal fermé → on le réinitialise
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
    elseif in_block and value:match('^' .. fence_closing .. '$') then
      in_block = false
      local end_line = line_number

      --[[ Reverse block collection to preserve line indices
      En insérant chaque bloc à la position 1, on garantit que les
      nouveaux blocs s’ajoutent avant les précédents. La liste finale
      est donc ordonnée du dernier au premier bloc dans le fichier.

      C’est crucial lors du remplacement : le texte chiffré n’ayant
      pas la même longueur que le texte en clair, les indices
      `start_line` et `end_line` deviendraient obsolètes dès le
      deuxième bloc si on traitait le fichier du haut vers le bas.
      ]]
      table.insert(blocks, 1, { start = start_line, end_ = end_line, content = content })
      log.debug(string.format('Block found between : %d and %d', start_line, end_line))
    elseif in_block then
      table.insert(content, value)
    end
  end

  log.debug(#blocks .. ' blocks found.')
  return blocks
end

--- Construit un nouveau bloc code prêt à être inséré
--- @param content string[]
--- @return string[] content with added fences
local function build_gpg_block(content)
  local gpg_block = { fence_opening }
  vim.list_extend(gpg_block, content)
  table.insert(gpg_block, fence_closing)

  return gpg_block
end

--- Remplace le contenu d’un bloc : plain <=> cipher
--- @param lines string[]
--- @param block GpgBlock
--- @return string[]
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

-- explicit side-effect: modifies the active buffer
--- @param block GpgBlock
function M.set_block_in_buffer(block)
  if type(block) ~= 'table' or type(block.content) ~= 'table' then
    log.error("Invalid block format: expected table with field 'content'.")
    return
  end

  local block_lines = build_gpg_block(block.content)

  vim.api.nvim_buf_set_lines(0, block.start - 1, block.end_, false, block_lines)
end

--- Affiche la liste des blocs détectés dans le buffer (débug)
function M.debug_list_blocks()
  local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local blocks = M.find_blocks(text)
  for index, block in ipairs(blocks) do
    print(
      string.format(
        'Bloc %d : lignes %d-%d, %d lignes',
        index,
        block.start,
        block.end_,
        #block.content
      )
    )
  end
end

--- Vérifie si un bloc est chiffré (PGP)
--- @param block GpgBlock
--- @return boolean
function M.is_encrypted(block)
  if not block or not block.content or #block.content == 0 then
    return false
  end
  local first_line = block.content[1]
  return first_line:match('BEGIN%sPGP%sMESSAGE') ~= nil
end

return M
