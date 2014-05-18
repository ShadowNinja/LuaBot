
bot.commands = {}
bot.mores = {}


-- Removes prefixes from a command.  Returns nil if there are no prefixes
function bot:stripPrefix(conn, line)
	-- First check for a nick prefix
	local lnick = conn.nick:lower()
	local nicklen = #lnick
	local nickpart = line:sub(1, nicklen):lower()
	if nickpart == lnick and not line:sub(nicklen + 1, nicklen + 1):isNickChar() then
		local startPos = line:find("%S", nicklen + 2)
		if not startPos then
			return
		end
		return line:sub(startPos)
	end

	-- Then check for the configured prefix
	local prefix = self.config.prefix
	local prefixlen = #prefix
	if prefix and line:sub(1, prefixlen):lower() == prefix:lower() then
		return line:sub(prefixlen + 1)
	end
end


-- Check if a IRC message is a command, and call handleCommand if so
function bot:checkCommand(conn, msg)
	local line = msg.args[2]
	local command = self:stripPrefix(conn, line)
	if not command and msg.args[1] == conn.nick then
		-- PMs don't require a prefix
		command = line
	end

	if not command then
		return false
	end

	local answer, success = self:handleCommand(conn, msg, command)

	if answer then
		self:reply(conn, msg, answer)
	end
	return true
end


-- Split into command and args, then call
function bot:handleCommand(conn, msg, line, opts)
	opts = opts or {}
	-- Parse command
	local def, cmd, args
	local positions = line:findAll(' ', 1, true)
	local num_found = #positions
	if num_found > 0 then
		for i = num_found, 1, -1 do
			local pos = positions[i]
			local cmd = line:sub(1, pos - 1)
			args = line:sub(pos + 1)
			def = self:getCommand(cmd)
			if def then
				break
			end
		end
	else
		cmd = line
		args = ""
		def = self:getCommand(cmd)
	end

	if not def then
		return "Unknown command. Try 'help'.", false
	end

	if def.IRCOnly and not conn then
		return "This command can only be used from IRC.", false
	end

	if def.privs then
		local privs
		if conn and msg.user then
			privs = self:getPrivs(msg.user)
		end
		privs = privs or opts.privs or {}
		if not self:checkPrivs(def.privs, privs) then
			return "Insuficient privileges", false
		end
	end

	local err
	args, err = self:processArgs(def.args, args)
	if err then
		return err, false
	end

	return def.action(conn, msg, args)
end


function bot:getCommand(name)
	name = name:lower()
	for pluginName, plugin in pairs(self.plugins) do
		if plugin.commands and plugin.commands[name] then
			return plugin.commands[name]
		end
	end
end


function bot:getPrivs(user)
	local privs = {}
	for mask, privSet in pairs(self.config.privs) do
		local matchStr = ("%s@%s"):format(user.user, user.host)
		if matchStr:find(mask) then
			for _, priv in pairs(privSet) do
				privs[priv] = true
			end
		end
	end
	return privs
end


function bot:checkPrivs(needs, has, ignoreOwner)
	if not ignoreOwner and has.owner then
		return true
	end
	for priv, _ in pairs(needs) do
		if not has[priv] then
			return false
		end
	end
	return true
end


function bot:processArgs(args, str)
	local a = {}
	for _, arg in ipairs(args) do
		local val
		val, str = self:checkArg(arg, str)
		if val ~= nil then
			a[arg.id] = val
		elseif not arg.optional then
			return nil, ("Required argument %s missing"):format(arg.name)
		end
	end
	if str and str ~= "" then
		return nil, "Too many arguments"
	end
	return a
end


function bot:humanArgs(args)
	local t = {}
	for _, arg in ipairs(args) do
		local s

		if arg.optional or arg.default then s = '['
		else s = '<' end

		s = s..arg.name
		if arg.default then
			s = s.." = "..tostring(arg.default)
		end

		if arg.optional or arg.default then s = s..']'
		else s = s..'>' end

		table.insert(t, s)
	end
	return table.concat(t, ' ')
end

-- Converters return the processed argument and the remaining arguments
local converters = {
	word = function(args)
		return args:match("^(%S+)%s?(.*)$")
	end,
	number = function(args)
		local num, rest = args:match("^(%d+)%s?(.*)$")
		return tonumber(num), rest
	end,
	boolean = function(args)
		local word, rest = args:match("^(%S+)%s?(.*)$")
		if not word then
			return nil, rest
		end
		return toboolean(word), rest
	end,
	text = function(args)
		return args ~= "" and args or nil, ""
	end,
}

function bot:checkArg(arg, str)
	assert(converters[arg.type], "No converter for "..arg.type)
	local val
	val, str = converters[arg.type](str)
	if val == nil and arg.default ~= nil then
		val = arg.default
	end
	return val, str
end


local function splitLen(text, len)
	local t = {}
	while #text > 0 do
		table.insert(t, text:sub(1, len))
		text = text:sub(len + 1)
	end
	return t
end


function bot:addMore(text, name)
	bot.mores[name] = splitLen(text, 380)
end


function bot:getMore(name)
	if not bot.mores[name] then
		return false
	end
	local text = table.remove(bot.mores[name], 1)
	if not text then
		return false
	end
	local numMore = #bot.mores[name]
	if numMore > 0 then
		text = text .. irc.bold(" (%u more)"):format(numMore)
	end
	return text
end


function bot:replyTo(conn, msg)
	local to = msg.args[1]
	if to == conn.nick then
		to = msg.user.nick
	end
	return to
end


function bot:reply(conn, msg, text)
	local replyTo = self:replyTo(conn, msg)

	text = text:gsub("[\r\n%z]", " \\n ")

	local textLen = #text
	if textLen > 400 then
		self:addMore(text, msg.user.nick)
		text = self:getMore(msg.user.nick)
	end
	conn:queue(irc.msgs.notice(replyTo, text))
end


function bot:checkCommandRegistration(name, def)
	assert(def.action, ("No action provided for command '%s'."):format(name))
	if not def.description then
		print(("WARNING: No description provided for command '%s'."):format(name))
	end
	def.args = def.args or {}
	for _, arg in pairs(def.args) do
		arg.id   = arg.id   or arg[1]
		arg.name = arg.name or arg[2]
		arg.type = arg.type or arg[3]
	end
end

