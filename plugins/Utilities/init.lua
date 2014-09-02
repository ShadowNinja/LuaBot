--[[
-- Utility commands
--]]

local m = {commands = {}}

m.commands.ping = {
	description = "Check lag",
	action = function(conn, msg, args)
		return true, "Pong"
	end
}


local starttime = os.time()
m.commands.uptime = {
	description = "Tell how long the bot has been running",
	action = function(conn, msg, args)
		local diff = os.difftime(os.time(), starttime)
		return true, ("Up %dd, %d:%02d:%02d"):format(
			math.floor(diff / 60 / 60 / 24),
			math.floor(diff / 60 / 60) % 24,
			math.floor(diff / 60) % 60,
			math.floor(diff) % 60
		)
	end
}


m.commands.quit = {
	args = {{"message", "Quit message", "text", optional=true}},
	description = "Disconnect from the current network",
	privs = {"admin"},
	IRCOnly = true,
	action = function(conn, msg, args)
		-- Wait for our response to get through before disconnecting
		local reason = args.message or ("Disconnect requested by %s.")
				:format(msg.user.nick)
		bot.schedule:add(1, false, bot.disconnect, bot, conn.network, reason)
		return true, "Disconnecting..."
	end
}


m.commands.shutdown = {
	description = "Disconnect from all networks and shut down",
	privs = {"admin"},
	action = function(conn, msg, args)
		bot.kill = true
		return true, "Shutting down..."
	end
}


m.commands.config = {
	args = {{"key",   "Setting key", "word"},
	        {"value", "Value",       "text", optional=true}},
	description = "View or set the value of a configuration variable",
	privs = {"owner"},
	action = function(conn, msg, args)
		-- We keep track of the last table we were in and the next key,
		-- rather than just navigating down the tree, because we need
		-- to in order to set values by reference.
		local last = bot
		local nextKey = "config"
		if args.key ~= "." then
			for key in args.key:gmatch("([^%.]+)") do
				last = last[nextKey]
				if type(last) ~= "table" then
					return true, ("Tried to index non-table"
						.." value with %q."):format(key)
				end
				nextKey = key
			end
		end
		if args.value then
			local f, err = load("return "..args.value)
			if not f then
				return false, err
			end
			local good, obj = pcall(f)
			if not good then
				return false, obj
			end
			last[nextKey] = obj
			bot:saveConfig()
		end
		local val = dump(last[nextKey], "")
		return true, ("%s = %s"):format(args.key, val)
	end
}


local function getCommandList()
	local text = ""
	for pluginName, plugin in pairs(bot.plugins) do
		if not plugin.commands then
			goto nextPlugin
		end
		for name, def in pairs(plugin.commands) do
			if text ~= "" then
				text = text..", "
			end
			text = text..name
		end
		::nextPlugin::
	end
	return text
end

m.commands.help = {
	args = {{"command", "Command", "text", optional=true}},
	description = "Get help with a command or list commands",
	action = function(conn, msg, args)
		if not args.command then
			return true, "Commands: "
				..getCommandList()
				.." -- Use 'help <command name>' to get"
				.." help with a specific command."
		end

		local cmd = bot:getCommand(args.command)
		if not cmd then
			return false, ("Unknown command %q.")
					:format(args.command)
		end

		return  true, ("Usage: %s %s -- %s"):format(
				args.command,
				bot:humanArgs(cmd.args),
				cmd.description)
	end
}


m.commands.more = {
	args = {{"name", "Name", "word", optional=true}},
	description = "Return more output from a previous command",
	IRCOnly = true,
	action = function(conn, msg, args)
		local name = args.name or msg.user.nick
		local to = bot:replyTo(conn, msg)
		local text = bot:getMore(name)
		if text then
			return true, text
		else
			return false, "No more!"
		end
	end
}


m.commands.raw = {
	args = {{"message", "IRC message", "text"}},
	description = "Send a raw message to the IRC server",
	privs = {"owner"},
	IRCOnly = true,
	action = function(conn, msg, args)
		conn:queue(args.message)
		return true, "Sent."
	end
}


m.commands.eval = {
	args = {{"code", "Lua code", "text"}},
	description = "Evaluate a chunk of Lua code",
	privs = {"owner"},
	action = function(conn, msg, args)
		if args.code:sub(1, 1) == "=" then
			args.code = "return "..args.code:sub(2)
		elseif not args.code:find("return", 1, true) then
			args.code = "return "..args.code
		end
		local f, err = load(args.code, nil, "t")
		if f == nil then
			return false, err
		end
		local ret = {pcall(f)}
		local good = table.remove(ret, 1)
		if not good then
			return false, table.remove(ret, 1)
		end
		local numret = table.maxn(ret)
		if numret > 0 then
			for i = 1, numret do
				ret[i] = dump(ret[i], "")
			end
			return true, table.concat(ret, ", ")
		else
			return true, "Code successfully executed with no results."
		end
	end
}


m.commands.echo = {
	args = {{"text", "Text", "text"}},
	description = "Say something",
	action = function(conn, msg, args)
		return true, args.text
	end
}

return m

