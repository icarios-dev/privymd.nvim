--- @module 'privymd.gpg.helpers'
--- Low-level GPG utilities for process and pipe handling.
--- Provides helper functions to create libuv pipes, spawn GPG, and ensure proper cleanup.
local log = require('privymd.utils.logger')

local uv = vim.uv

local M = {}

--- Check whether GPG is available in the current PATH.
--- Shows an error notification if not found.
---
--- @return boolean available True if GPG executable is available, false otherwise.
function M.check_gpg()
  local availability = vim.fn.executable('gpg') == 1
  if not availability then
    vim.notify('gpg not found in PATH.', vim.log.levels.ERROR, { title = 'PrivyMD' })
  end
  return availability
end

--- Create a table of libuv pipes for stdin/stdout/stderr (and optionally passphrase input).
--- @param with_pass boolean? If true, include an extra pipe for passphrase input (fd 3).
--- @return uv_pipes pipes Table containing the created pipes.
function M.make_pipes(with_pass)
  local pipes = {
    stdin = assert(uv.new_pipe(false)),
    stdout = assert(uv.new_pipe(false)),
    stderr = assert(uv.new_pipe(false)),
  }
  if with_pass then
    pipes.pass = assert(uv.new_pipe(false))
  end
  return pipes
end

--- Properly close all pipes and the process handle.
--- @param pipes uv_pipes The table returned by make_pipes().
--- @param handle? uv_process_t Optional process handle to close.
function M.close_all(pipes, handle)
  for _, p in pairs(pipes) do
    if p and not p:is_closing() then
      p:close()
    end
  end
  if handle and not handle:is_closing() then
    handle:close()
  end
end

--- Spawn a GPG process and collect stdout/stderr asynchronously.
--- Handles both encryption and decryption operations.
---
--- @async
--- @param args string[] Command-line arguments passed to GPG.
--- @param pipes uv_pipes Active pipes created by make_pipes().
--- @param on_exit fun(code: integer, stdout_str: string, stderr_str: string) Callback called when the process exits.
--- @return uv_process_t|nil handle Process handle if successful, or nil if failed.
--- @return string|nil err Error message when spawn fails.
function M.spawn_gpg(args, pipes, on_exit)
  log.trace(' -> entry in spawn_gpg()')
  if not M.check_gpg() then
    return nil, 'gpg command not available in PATH.'
  end
  local stdout_chunks, stderr_chunks = {}, {}

  ---@type uv_process_t|nil, integer|nil
  local handle, spawn_err
  ---@diagnostic disable-next-line: missing-fields
  handle, spawn_err = uv.spawn('gpg', {
    -- NOTE: uid/gid/cwd intentionally omitted (valid on Unix systems)
    args = args,
    stdio = { pipes.stdin, pipes.stdout, pipes.stderr, pipes.pass },
    env = { 'LANG=C', 'LC_ALL=C' }, -- avoid localized GPG messages breaking error matching
  }, function(code)
    -- On termine la lecture et on ferme tout proprement
    M.close_all(pipes, handle)
    on_exit(code, table.concat(stdout_chunks), table.concat(stderr_chunks))
  end)

  if not handle then
    return nil, tostring(spawn_err)
  end

  -- Capture stdout
  uv.read_start(pipes.stdout, function(err, data)
    if err then
      table.insert(stderr_chunks, 'stdout err: ' .. err)
    elseif data then
      table.insert(stdout_chunks, data)
    end
  end)

  -- Capture stderr
  uv.read_start(pipes.stderr, function(err, data)
    if err then
      table.insert(stderr_chunks, 'stderr err: ' .. err)
    elseif data then
      table.insert(stderr_chunks, data)
    end
  end)

  return handle
end

--- Write data into a libuv pipe and close it properly once the write completes.
--- Ensures the pipe is not already closing before writing.
---
--- @async
--- @param pipe uv_pipe_t The libuv pipe handle to write into.
--- @param data string The data to send through the pipe.
function M.write_and_close(pipe, data)
  if not pipe or pipe:is_closing() then
    return
  end
  pipe:write(data)
  pipe:shutdown(function()
    if not pipe:is_closing() then
      pipe:close()
    end
  end)
end

--- Normalize GPG command output by ensuring a consistent double newline
--- separation between headers and message body. This prevents parsing issues
--- when GPG omits blank lines or uses inconsistent newline sequences.
---
--- Example:
--- ```text
--- -----BEGIN PGP MESSAGE-----
--- Version: GnuPG v2
---
--- <ciphertext>
--- ```
---
--- @param out string The raw output text returned by GPG.
--- @return string normalized The normalized string with enforced blank line separation.
function M.normalize_output(out)
  if not out:match('\n\n') then
    out = out:gsub('(\r?\n\r?\n)', '\n\n')
  end
  return out
end

--- Run gpg with args
--- Send to the stdandard input and return standard output.
---
--- @param args string[]
--- @param input? string
--- @return string|nil output output of gpg
--- @return string? err error message
function M.run_gpg(args, input)
  local pipes = M.make_pipes(false)

  --- @class Result
  --- @field code integer
  --- @field stdout string
  --- @field stderr string
  ---@type Result
  local result = { code = 0, stdout = '', stderr = '' }
  local done = false

  local handle, spawn_err = M.spawn_gpg(args, pipes, function(code, stdout_str, stderr_str)
    result.code, result.stdout, result.stderr = code, stdout_str, stderr_str
    done = true
  end)
  if not handle then
    log.error('GPG spawn failed: ' .. tostring(spawn_err or 'unknown error'))
    M.close_all(pipes)
    return nil, spawn_err or 'spawn failed'
  end

  if input == nil or input == '' then
    if pipes.stdin and not pipes.stdin:is_closing() then
      pipes.stdin:close()
    end
  else
    -- Send input to gpg stdin
    M.write_and_close(pipes.stdin, input)
  end

  -- Wait for process completion
  while not done do
    vim.uv.run('once')
  end

  if result.stdout and result.stdout ~= '' then
    return result.stdout
  end

  if result.code ~= 0 then
    local err_msg = ('gpg (exit %d): %s'):format(result.code, result.stderr)
    return nil, err_msg
  end
end

return M
