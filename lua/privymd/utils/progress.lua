local log = require("privymd.utils.logger")

local M = {}

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local timer
local notif
local spinner_index = 1
local total_blocks = 0
local message = ""
local done_blocks = 0

---------------------------------------------------------------------
-- 🌀 Start spinner with message and total count
---------------------------------------------------------------------
function M.start(total, msg)
	total_blocks = total or 0
	message = msg or "Processing..."
	done_blocks = 0
	spinner_index = 1

	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end

	timer = vim.uv.new_timer()
	if not timer then
		log.error("Failed to create timer for progress indicator")
		return
	end
	timer:start(
		0,
		100,
		vim.schedule_wrap(function()
			local spinner = spinner_frames[spinner_index]
			spinner_index = (spinner_index % #spinner_frames) + 1

			local text = string.format("%s %s %d/%d", spinner, message, done_blocks, total_blocks)
			local opts = {
				title = "PrivyMD",
				icon = spinner,
				timeout = 300,
				replace = notif, -- si nvim-notify est présent, met à jour la même notif
			}

			notif = vim.notify(text, vim.log.levels.INFO, opts)
		end)
	)
end

---------------------------------------------------------------------
-- 🔁 Update progress (increment or set explicitly)
---------------------------------------------------------------------
function M.update(done)
	if not timer then
		return
	end
	if done ~= nil then
		done_blocks = done
	else
		done_blocks = done_blocks + 1
	end
end

---------------------------------------------------------------------
-- 🛑 Stop spinner and show completion message
---------------------------------------------------------------------
function M.stop(final_msg)
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end

	local msg = final_msg or string.format("Done (%d blocks)", done_blocks)
	vim.notify(msg, vim.log.levels.INFO, { title = "PrivyMD", icon = "✔" })
	notif = nil
end

return M
