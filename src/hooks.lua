
bot.hooks = {}
bot.registeredHooks = {}


function bot:hookup(conn)
	local counter = 1
	conn.LuaBot_hook_ids = {}
	for name, hooks in pairs(self.registeredHooks) do
		for _, func in pairs(hooks) do
			-- Wrap hooks to pass the Connection to them
			local wrappedFunc = function(...) return func(conn, ...) end
			-- We have to save the wrapped function so that we can unhook it later
			conn.LuaBot_hook_ids[name] = conn.LuaBot_hook_ids[name] or {}
			conn.LuaBot_hook_ids[name][func] = counter
			conn:hook(name, counter, wrappedFunc)
			counter = counter + 1
		end
	end
end


function bot:hook(name, func)
	self.registeredHooks[name] = self.registeredHooks[name] or {}
	table.insert(self.registeredHooks[name], func)
end


function bot:unhook(name, func)
	local registered = self.registeredHooks[name]
	if not registered then
		return
	end
	for i, f in pairs(registered) do
		if f == func then
			registered[i] = nil
		end
	end
	for _, conn in pairs(self.conns) do
		local ids = conn.LuaBot_hook_ids[name]
		if ids then
			local id = ids[func]
			if id then
				ids[func] = nil
				conn:unhook(name, id)
			end
		end
	end
end


function bot.hooks:preregister(conn)
	--self:queue(irc.Message("CAP", {"LS", "3.2"}))
end


function bot.hooks:caplist()
	if self.authed then
		return
	end
	local netConf = bot.config.networks[self.network]
	if netConf.sasl and
	   netConf.sasl.username and
	   netConf.sasl.password then
		if self.availableCapabilities.sasl then
			self:queue(irc.Message("CAP", {"REQ", "sasl"}))
		else
			bot:log("error", "SASL configured but not available!")
		end
	end
end


function bot.hooks:capset(name, enabled)
	if not enabled then
		return
	end
	local done = false
	local netConf = bot.config.networks[self.network]
	if enabled and name == "sasl" then
		done = true
		local authString = base64e(
			("%s\x00%s\x00%s"):format(
				netConf.sasl.username,
				netConf.sasl.username,
				netConf.sasl.password
			)
		)
		self:queue(irc.Message("AUTHENTICATE", {"PLAIN"}))
		self:queue(irc.Message("AUTHENTICATE", {authString}))
	end
	if done then
		self:queue(irc.Message("CAP", {"END"}))
	end
end


function bot.hooks:privmsg(msg)
	local c = string.char(1)
	if msg.args[2]:sub(1, 1) == c and
	   msg.args[2]:sub(-1)   == c then
		self:invoke("OnCTCP", msg)
		return
	end
	bot:checkCommand(self, msg)
end


function bot.hooks:ctcp(msg)
	local text = msg.args[2]:sub(2, -2)  -- Strip ^C
	local args = text:split(' ')
	local command = args[1]:upper()

	local function reply(s)
		self:queue(irc.msgs.notice(msg.user.nick,
				("\1%s %s\1"):format(command, s)))
	end

	if command == "VERSION" then
		reply(bot.versionString)
	elseif command == "PING" then
		reply(args[2])
	elseif command == "TIME" then
		reply(os.date())
	elseif command == "FINGER" then
		reply(self.realname)
	end
end


local function debugHook(name)
	return function(conn, line)
		bot:log("debug", ("%s (%s): %s"):format(
			name,
			conn.network,
			line
		))
	end
end


function bot:registerHooks()
	self:hook("PreRegister", bot.hooks.preregister)
	self:hook("OnCapList", bot.hooks.caplist)
	self:hook("OnCapSet", bot.hooks.capset)
	self:hook("DoPrivmsg", bot.hooks.privmsg)
	self:hook("OnCTCP", bot.hooks.ctcp)

	self:hook("OnRaw", debugHook("RECV"))
	self:hook("OnSend", debugHook("SEND"))
end

