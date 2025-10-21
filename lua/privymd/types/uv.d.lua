--- @meta
--- Type definitions for minimal libuv handles used within PrivyMD.
--- These declarations allow static analysis and autocompletion in LSPs
--- without requiring the full Neovim or libuv bindings.

--- Minimal libuv pipe handle.
--- Represents a unidirectional stream used for IPC or I/O redirection.
---
--- @class uv_pipe_t : uv.uv_stream_t
--- @field close fun(self: uv_pipe_t) Closes the pipe handle and releases its resources.
--- @field is_closing fun(self: uv_pipe_t): boolean Returns true if the handle is in the process of closing.

--- Minimal libuv process handle.
--- Represents a spawned process managed by Neovim's libuv wrapper.
---
--- @class uv_process_t
--- @field pid integer Process identifier (PID) of the spawned process.
--- @field close fun(self: uv_process_t) Closes the handle associated with the process.
--- @field is_closing fun(self: uv_process_t): boolean Returns true if the process handle is closing.
--- @field kill fun(self: uv_process_t, signum?: integer): integer|nil Sends a signal to the process (if supported).

--- Grouped pipe handles structure used for process I/O redirection.
--- These are typically passed to uv.spawn() when interacting with GPG or other commands.
---
--- @alias uv_pipes
--- | { stdin: uv_pipe_t, stdout: uv_pipe_t, stderr: uv_pipe_t, pass?: uv_pipe_t }
