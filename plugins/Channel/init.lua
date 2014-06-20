
local m = {commands = {}}

local channelPrivs = {"#op"}

m.commands.join = {
	description = "Join a channel",
	args = {{"channel", "Channel",      "channel"},
		{"key",     "Key/Password", "word", optional=true}},
	privs = channelPrivs,
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
	args = {{"channel", "Channel",      "channel"},
		{"message", "Part message", "text", optional=true}},
	description = "Part a channel",
	privs = channelPrivs,
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


local modeSetterArgs = {
	{"channel", "Channel",  "channel"},
	{"nick",    "Nickname", "nick"},
}
local function modeSetter(modeString, desc)
	return {
		args = modeSetterArgs,
		description = desc,
		privs = channelPrivs,
		IRCOnly = true,
		action = function(conn, msg, args)
			conn:queue(irc.Message({
				command = "MODE",
				args = {args.channel, modeString, args.nick},
			}))
			return true
		end,
	}
end

m.commands.op      = modeSetter("+o", "Promote a channel member to channel operator status.")
m.commands.deop    = modeSetter("-o", "Remove channel operator status from a channel member.")
m.commands.voice   = modeSetter("+v", "Give a channel member voice.")
m.commands.devoice = modeSetter("-v", "Remove a channel member's voice.")

return m

