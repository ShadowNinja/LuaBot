
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


function bot.hooks:preregister()
	self:queue(irc.msgs.cap("LS", "3.2"))
end


function bot.hooks:caplist()
	if not self.authed and not self.LuaBot_want_sasl then
		self:queue(irc.msgs.cap("END"))
	end
end


function bot.hooks:capavail(cap, value)
	local netConf = bot.config.networks[self.network]
	if cap == "sasl" and
			netConf.sasl and
			netConf.sasl.username and
			netConf.sasl.password then
		self.LuaBot_want_sasl = true
		return true
	elseif cap == "multi-prefix" then
		return true
	end
end


function bot.hooks:capset(name, enabled)
	if not enabled then
		return
	end
	local netConf = bot.config.networks[self.network]
	if enabled and name == "sasl" then
		local authString = base64e(
			("%s\x00%s\x00%s"):format(
				netConf.sasl.username,
				netConf.sasl.username,
				netConf.sasl.password
			)
		)
		self:queue(irc.Message({command="AUTHENTICATE", args={"PLAIN"}}))
		self:queue(irc.Message({command="AUTHENTICATE", args={authString}}))
		self:queue(irc.msgs.cap("END"))
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
	self:hook("OnCapabilityList", bot.hooks.caplist)
	self:hook("OnCapabilityAvailable", bot.hooks.capavail)
	self:hook("OnCapabilitySet", bot.hooks.capset)
	self:hook("DoPrivmsg", bot.hooks.privmsg)
	self:hook("OnCTCP", bot.hooks.ctcp)

	self:hook("OnRaw", debugHook("RECV"))
	self:hook("OnSend", debugHook("SEND"))
end

