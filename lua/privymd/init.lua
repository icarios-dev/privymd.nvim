local Block = require('privymd.block')
local Gpg = require('privymd.gpg')
local Hooks = require('privymd.hooks')

local M = {}

M.config = {
  ft_pattern = '*.md',
  auto_decrypt = true,
  auto_encrypt = true,
}

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  if not Gpg.is_gpg_available() then
    vim.notify(
      'PrivyMD: GPG introuvable. Le plugin est désactivé.',
      vim.log.levels.ERROR,
      { title = 'PrivyMD' }
    )
    return
  end

  local pattern = opts.ft_pattern or M.config.ft_pattern

  -- Définition des autocommands
  if M.config.auto_decrypt then
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWinEnter' }, {
      pattern = pattern,
      callback = function()
        Hooks.decrypt_buffer()
      end,
    })
  end

  if M.config.auto_encrypt then
    vim.api.nvim_create_autocmd('BufWriteCmd', {
      pattern = pattern,
      callback = function()
        Hooks.encrypt_and_save_buffer()
      end,
    })
  end

  -- Commandes utilisateur

  -- Force manual decryption of current buffer
  vim.api.nvim_create_user_command('PrivyDecrypt', function()
    Hooks.decrypt_buffer()
  end, {})

  -- Force manual encryption and save
  vim.api.nvim_create_user_command('PrivyEncrypt', function()
    Hooks.encrypt_and_save_buffer()
  end, {})

  -- Toggle decrypt/encrypt in memory (without saving)
  vim.api.nvim_create_user_command('PrivyToggle', function()
    Hooks.toggle_encryption()
  end, {})

  -- Debugging tools
  vim.api.nvim_create_user_command('PrivyShowBlocks', function()
    Block.debug_list_blocks()
  end, {})

  vim.api.nvim_create_user_command('PrivyClearPass', function()
    Hooks.clear_passphrase()
  end, {})
end

return M
