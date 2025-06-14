-- Start-of-file--
-- Auto-setup commands and API
if vim.g.loaded_plugman then
	return
end
vim.g.loaded_plugman = 1
-- Global API
_G.Plugman = require("plugman")
if vim.g.plugman_no_auto_setup == nil then
	vim.g.plugman_no_auto_setup = true
end
-- Auto-setup with sensible defaults
if not vim.g.plugman_no_auto_setup then
	_G.Plugman = require("plugman")
	Plugman.setup()
end
-- Commands
vim.api.nvim_create_user_command("Plugman", function(opts)
	local cmd = opts.args

	if cmd == "show" or cmd == "" then
		_G.Plugman.show()
	elseif cmd == "update" then
		_G.Plugman.update()
	elseif cmd:match("^add ") then
		local source = cmd:match("^add (.+)$")
		_G.Plugman.add(source)
	elseif cmd:match("^remove ") then
		local name = cmd:match("^remove (.+)$")
		_G.Plugman.remove(name)
	else
		vim.notify("Unknown command: " .. cmd, vim.log.levels.ERROR)
	end
end, {
	nargs = "*",
	complete = function(arglead, cmdline, cursorpos)
		local commands = { "show", "update", "add", "remove" }
		return vim.tbl_filter(function(cmd)
			return cmd:match("^" .. arglead)
		end, commands)
	end,
})
-- Shorter alias
vim.api.nvim_create_user_command("Pm", function(opts)
	vim.cmd("Plugman " .. opts.args)
end, {
	nargs = "*",
	complete = function(arglead, cmdline, cursorpos)
		-- Reuse Plugman completion
		return vim.fn.getcompletion("Plugman " .. arglead, "cmdline")
	end,
})
--End-of-file--
