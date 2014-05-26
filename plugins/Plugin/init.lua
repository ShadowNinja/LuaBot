--[[
-- A plugin for managing plugins
--]]

local m = {commands = {}}

local function pluginOp(args, op)
	if not args.pluginName then
		return false, "No plugin name provided"
	end
	local good, errMsg = bot[op.."Plugin"](bot, args.pluginName, args.persist)
	if not good then
		bot:log("error", errMsg)
		return false, ("Failed to %s plugin: %s"):format(op, errMsg:max(300))
	end
	return true, ("Plugin successfully %sed."):format(op)
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

m.commands.plugins = {
	description = "List all loaded plugins",
	action = function(conn, msg, args)
		local names = {}
		for name, _ in pairs(bot.plugins) do
			table.insert(names, name)
		end
		return true, table.concat(names, ", ")
	end,
}

return m

