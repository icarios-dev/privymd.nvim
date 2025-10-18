local uv = vim.uv

--- @class GpgHelpers
local M = {}

--- Create a set of libuv pipes (stdin, stdout, stderr[, pass])
--- @param with_pass? boolean include a 'pass' pipe (fd3)
--- @return uv_pipes
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

--- Close all pipes and an optional process handle
--- @param pipes uv_pipes
--- @param handle? uv_process_t
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

--- Launch a GPG process (async or sync) and return the handle.
--- Automatically closes all pipes and the handle at the end.
---
--- @param args string[] Command-line arguments passed to gpg.
--- @param pipes uv_pipes  Set of libuv pipes.
--- @param on_exit fun(code: integer, stdout: string, stderr: string) Callback triggered when the process exits.
--- @return uv_process_t|nil handle Process handle on success, or nil if spawn failed.
--- @return string? err Error message if spawn failed.
function M.spawn_gpg(args, pipes, on_exit)
  local stdout_chunks, stderr_chunks = {}, {}

  local handle, spawn_err
  ---@diagnostic disable-next-line: missing-fields
  handle, spawn_err = uv.spawn('gpg', {
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

  -- redirections
  uv.read_start(pipes.stdout, function(err, data)
    if err then
      table.insert(stderr_chunks, 'stdout err: ' .. err)
    elseif data then
      table.insert(stdout_chunks, data)
    end
  end)

  uv.read_start(pipes.stderr, function(err, data)
    if err then
      table.insert(stderr_chunks, 'stderr err: ' .. err)
    elseif data then
      table.insert(stderr_chunks, data)
    end
  end)

  return handle
end

--- Écrit du texte dans un pipe et le ferme proprement.
--- @param pipe uv_pipe_t
--- @param data string
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

--- Normalise le format de sortie de GPG (évite les doublons de sauts de ligne)
--- @param out string
--- @return string
function M.normalize_output(out)
  if not out:match('\n\n') then
    out = out:gsub('(\r?\n\r?\n)', '\n\n')
  end
  return out
end

return M
