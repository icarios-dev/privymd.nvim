--- @meta

--- Minimal libuv pipe handle
--- @class uv_pipe_t : uv.uv_stream_t
--- @field close fun(self: uv_pipe_t)
--- @field is_closing fun(self: uv_pipe_t): boolean

--- Minimal libuv process handle
--- @class uv_process_t
--- @field close fun(self: uv_process_t)
--- @field is_closing fun(self: uv_process_t): boolean

--- @alias uv_pipes { stdin: uv_pipe_t, stdout: uv_pipe_t, stderr: uv_pipe_t, pass?: uv_pipe_t }
