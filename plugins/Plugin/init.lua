--[[
-- A plugin for managing plugins
--]]

local m = {commands = {}}

local function pluginOp(args, op)
	local good, errMsg = bot[op.."Plugin"](bot, args.pluginName, args.persist)
	if not good then
		return ("Failed to %s plugin: %s"):format(op, errMsg:max(300)), false
	end
	return ("Plugin successfully %sed."):format(op), true
end


local loadArgs = {
	{"pluginName", "Plugin name", "word"},
	{"persist",    "Persist",     "boolean", default=true}
}
local loadPrivs = {"owner"}

m.commands.load = {
	args = loadArgs,
	description = "Load a plugin",
	privs = loadPrivs,
	action = function(conn, msg, args)
		return pluginOp(args, "load")
	end
}

m.commands.unload = {
	args = loadArgs,
	description = "Unload a plugin",
	privs = loadPrivs,
	action = function(conn, msg, args)
		return pluginOp(args, "unload")
	end
}

m.commands.reload = {
	args = loadArgs,
	description = "Reload a plugin",
	privs = loadPrivs,
	action = function(conn, msg, args)
		return pluginOp(args, "reload")
	end
}

return m

