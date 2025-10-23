--- @module 'privymd'
--- Main entry point for the PrivyMD plugin.
---
--- This module provides the setup routine and global configuration
--- for PrivyMD. It binds user commands and autocommands that manage
--- automatic encryption and decryption of GPG code blocks inside
--- Markdown files.
---
--- Example:
--- ```lua
--- require('privymd').setup({
---   ft_pattern = '*.md',
---   auto_decrypt = true,
---   auto_encrypt = true,
--- })
--- ```
---
--- Once configured, PrivyMD will:
---  - Automatically decrypt GPG blocks when opening Markdown buffers
---  - Automatically encrypt them when saving
---  - Provide user commands such as :PrivyEncrypt, :PrivyDecrypt, and :PrivyToggle
---
--- The plugin depends on GPG being available in the system PATH.

local Block = require('privymd.core.block')
local Gpg = require('privymd.core.gpg.gpg')
local Hooks = require('privymd.hooks')

local M = {}

--- Default configuration.
--- @type PrivyConfig
M.config = {
  ft_pattern = '*.md',
  auto_decrypt = true,
  auto_encrypt = true,
}

--- Setup PrivyMD and define autocommands and user commands.
---
--- @param opts PrivyConfig? Optional configuration table.
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  if not Gpg.is_gpg_available() then
    vim.notify(
      'PrivyMD: GPG not found. Plugin disabled.',
      vim.log.levels.ERROR,
      { title = 'PrivyMD' }
    )
    return
  end

  local pattern = opts.ft_pattern or M.config.ft_pattern

  ---------------------------------------------------------------------------
  -- Autocommands
  ---------------------------------------------------------------------------
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

  ---------------------------------------------------------------------------
  -- User Commands
  ---------------------------------------------------------------------------

  --- Manually decrypt all GPG blocks in the current buffer.
  vim.api.nvim_create_user_command('PrivyDecrypt', function()
    Hooks.decrypt_buffer()
  end, {})

  --- Manually encrypt all GPG blocks in the current buffer and save to disk.
  vim.api.nvim_create_user_command('PrivyEncrypt', function()
    Hooks.encrypt_and_save_buffer()
  end, {})

  --- Toggle decryption/encryption of the GPG block under the cursor (in memory).
  vim.api.nvim_create_user_command('PrivyToggle', function()
    Hooks.toggle_encryption()
  end, {})

  --- Show a list of all detected GPG blocks in the current buffer (debug tool).
  vim.api.nvim_create_user_command('PrivyShowBlocks', function()
    Block.debug_list_blocks()
  end, {})

  --- Clear the cached passphrase for the current session.
  vim.api.nvim_create_user_command('PrivyClearPass', function()
    Hooks.clear_passphrase()
  end, {})
end

return M
