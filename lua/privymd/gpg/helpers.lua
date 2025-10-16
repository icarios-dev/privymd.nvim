local uv = vim.uv

local M = {}

---------------------------------------------------------------------
-- 🧩 Helpers
---------------------------------------------------------------------

--- Crée une table de pipes (stdin, stdout, stderr[, pass])
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

--- Ferme proprement tous les pipes et handle
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

--- Lance un processus gpg (async ou sync) et renvoie les buffers stdout/stderr
function M.spawn_gpg(args, pipes, on_exit)
  local stdout_chunks, stderr_chunks = {}, {}

  local handle, spawn_err
  -- NOTE: uid/gid/cwd intentionally omitted (not needed on Unix, nil is valid)
  ---@diagnostic disable-next-line: missing-fields
  handle, spawn_err = uv.spawn('gpg', {
    args = args,
    stdio = { pipes.stdin, pipes.stdout, pipes.stderr, pipes.pass },
    env = {},
    verbatim = false,
    detached = false,
    hide = true,
  }, function(code)
    M.close_all(pipes, handle)
    on_exit(code, table.concat(stdout_chunks), table.concat(stderr_chunks))
  end)

  if not handle then
    return nil, spawn_err
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

return M
