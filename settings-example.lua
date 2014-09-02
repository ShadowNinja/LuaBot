{
	prefix = "!",
	nesting = "<>",  -- Opening and closing characters for command nesting
	flushInterval = 300,
	log = {
		color = true,
		filename = nil,
		-- Also "debug".  "important" is always printed.
		levels = {"error", "warning", "action", "info"},
	},
	privs = {
		["@Project/staff/BotManager$"] = {"owner"},
		["@Project/staff/"] = {"admin"}
	},
	networks = {
		IRCNet = {
			autoConnect = true,
			nick     = "LuaBot",  -- Required
			username = "LuaBot",
			realname = "LuaBot",
			host     = "irc.net",  -- Required
			port     = 6667,
			secure   = false,
			channels = {
				["#bots"] = {
					autoJoin = false,
				},
			},
		},
	},
	pluginPaths = {"plugins"},
	plugins = {
		Channel = true
		ExternalCommands = true,
		Network = true,
		Plugin = true,
		Tell = true,
		Utilities = true,
	},
}

