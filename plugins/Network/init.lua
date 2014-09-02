
local m = {commands = {}}


local function decodePortString(str)
	local secure = str:sub(1, 1) == "+"
	local port = secure and str:sub(2) or str
	port = tonumber(port)
	if not port then
		return nil
	end
	return port, secure
end


m.commands.connect = {
	args = {{"net", "Network", "word"},
		{"nick", "Nick name", "word", optional=true},
		{"user", "User name", "word", optional=true},
		{"real", "Real name", "string", optional=true},
		{"host", "Address", "word", optional=true},
		{"port", "Port", "word", optional=true},
		{"autoconn", "Auto-connect", "boolean", default=true}},
	description = "Connect to an IRC network.",
	privs = {owner=true},
	action = function(conn, msg, args)
		local oldConn = bot.conns[args.net]
		local isConnected = oldConn and oldConn.connected
		if isConnected then
			return false, ("Already connected to %s.")
					:format(args.net)
		end

		local conf = bot.config.networks[args.net]
		if conf then
			-- Update network configuration from arguments
			if args.nick then conf.nick     = args.nick end
			if args.user then conf.username = args.user end
			if args.real then conf.realname = args.real end
			if args.host then conf.host     = args.host end
			if args.port then
				local port, secure = decodePortString(args.port)
				if not port then
					return false, "Invalid port."
				end
				conf.port = port
				conf.secure = secure
			end
			if args.autoconn then conf.autoConnect = args.autoConnect end
			-- Save config if it was changed
			if args.nick then
				bot:saveConfig()
			end

			-- Delay connection so that we reply quickly
			bot:schedule(1, false, bot.connect, bot, args.net, conf)
		elseif not conf and args.host then
			local port, secure = 6667, false
			if args.port then
				port, secure = decodePortString(args.port)
			end
			if not port then
				return false, "Invalid port."
			end
			local opts = {
				autoConnect = args.autoconn,
				nick     = args.nick,
				username = args.username,
				realname = args.realname,
				host     = args.host,
				port     = port,
				secure   = secure,
			}
			bot.config.networks[args.net] = opts
			bot:saveConfig()
			-- Delay connection so that we reply quickly
			bot:schedule(1, false, bot.connect, bot, args.net, opts)
		else
			return false, "No address specified for new network."
		end
		return true, ("Connecting to %s...."):format(args.net)
	end,
}

m.commands.disconnect = {
	args = {{"net", "Network", "word"}},
	description = "Disconnect from an IRC network.",
	privs = {owner=true},
	action = function(conn, msg, args)
		if not bot.conns[args.net] then
			return false, ("Network %s does not exist.")
					:format(args.net)
		end
		-- Delay to allow response to get through
		bot:schedule(1, false, bot.disconnect, bot, args.net,
				("Disconnect requested by %s.")
					:format(bot:getActor(conn, msg)))
		return true, ("Disconnecting from %s..."):format(args.net)
	end,
}

m.commands.networks = {
	description = "List connected and configured networks.",
	privs = {admin=true},
	action = function(conn, msg, args)
		local connected, configured = {}, {}
		for name in pairs(bot.conns) do
			table.insert(connected, name)
		end
		for name in pairs(bot.config.networks) do
			table.insert(configured, name)
		end
		return true, "Connected ("..(#connected).."): "..
				table.concat(connected, ", ")..
				" | Configured ("..(#configured).."): "..
				table.concat(configured, ", ")
	end,
}

return m

