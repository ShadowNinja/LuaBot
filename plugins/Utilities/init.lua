--[[
-- Utility commands
--]]

bot:registerCommand("ping", {
	description = "Check lag",
	action = function(conn, msg, args)
		return "Pong", true
	end
})


local starttime = os.time()
bot:registerCommand("uptime", {
	description = "Tell how long the bot has been running",
	action = function(conn, msg, args)
		local diff = os.difftime(os.time(), starttime)
		return ("Up %dd, %d:%02d:%02d"):format(
			math.floor(diff / 60 / 60 / 24),
			math.floor(diff / 60 / 60) % 24,
			math.floor(diff / 60) % 60,
			math.floor(diff) % 60
		), true
	end
})


bot:registerCommand("quit", {
	args = {{"message", "Quit message", "text", optional=true}},
	description = "Disconnect from the current network",
	privs = {owner=true},
	action = function(conn, msg, args)
		-- Wait for our response to get through before disconnecting
		local reason = args.message or ("Disconnect requested by %s.")
				:format(msg.user.nick)
		bot.schedule:add(1, bot.disconnect, bot, conn.network, reason)
		return "Disconnecting...", true
	end
})


bot:registerCommand("shutdown", {
	description = "Disconnect from all networks and shut down",
	privs = {owner=true},
	action = function(conn, msg, args)
		bot.kill = true
		return "Shutting down...", true
	end
})


bot:registerCommand("config show", {
	args = {{"value", "Configuration value", "word"}},
	description = "Show the value of a configuration variable",
	privs = {owner=true},
	action = function(conn, msg, args)
		local cur = bot.config
		if args.value ~= "." then
			for x in args.value:gmatch("([^%.]+)") do
				if type(cur) ~= "table" then
					return ("Tried to index non-table value with %s."):format(x), false
				end
				cur = cur[x]
			end
		end
		local tp = type(cur)
		local val = dump(cur, "")
		return ("%s (%s): %s"):format(args.value, tp, val), true
	end
})

