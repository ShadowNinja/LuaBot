
local m = {commands = {}}

m.commands.join = {
	description = "Join a channel",
	args = {{"channel", "Channel",      "word"},
		{"key",     "Key/Password", "word", optional=true}},
	privs = {"admin"},
	IRCOnly = true,
	action = function(conn, msg, args)
		conn:join(args.channel, args.key)
		local chans = bot.config.networks[conn.network].channels
		chans[args.channel] = {
			autoJoin = true,
			key = args.key
		}
		bot:saveConfig()
		return true, ("Joining %s..."):format(args.channel)
	end
}

m.commands.part = {
	args = {{"channel", "Channel",      "word"},
		{"message", "Part message", "text", optional=true}},
	description = "Part a channel",
	privs = {"admin"},
	IRCOnly = true,
	action = function(conn, msg, args)
		conn:part(args.channel, args.message)
		local chan = bot.config.networks[conn.network].channels[args.channel]
		if chan then
			chan.autoJoin = false
		end
		bot:saveConfig()
		return true, ("Parting %s..."):format(args.channel)
	end
}

return m

