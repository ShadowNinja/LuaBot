
bot:registerCommand("join", {
	params = "<channel> [key]",
	description = "Join a channel",
	privs = {admin=true},
	action = function(conn, msg, args)
		if not args[1] then
			return "No channel specified.", false
		end
		conn:join(args[1], args[2])
		local chans = bot.config.networks[conn.network].channels
		chans[args[1]] = {
			autoJoin = true,
			key = args[2]
		}
		bot:saveConfig()
		return ("Joining %s..."):format(args[1]), true
	end
})


bot:registerCommand("part", {
	params = "<channel> [reason]",
	description = "Part a channel",
	privs = {admin=true},
	action = function(conn, msg, args)
		local channel = table.remove(args, 1)
		if not channel then
			return "No channel specified.", false
		end
		conn:part(channel, table.concat(args, " "))
		local chan = bot.config.networks[conn.network].channels[channel]
		if chan then
			chan.autoJoin = false
		end
		bot:saveConfig()
		return ("Parting %s..."):format(channel), true
	end
})

