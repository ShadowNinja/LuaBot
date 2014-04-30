
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
			def = self.commands[cmd]
			if def then
				break
			end
		end
	else
		cmd = line
		args = ""
		def = self.commands[cmd]
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


function bot:processArgs(args, str)
	local a = {}
	for _, arg in ipairs(args) do
		local val
		val, str = self:checkArg(arg, str)
		if val then
			a[arg.id] = val
		elseif not arg.optional then
			return nil, "Required argument missing"
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

		if arg.optional then s = '['
		else s = '<' end

		s = s..arg.name

		if arg.optional then s = s..']'
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
	text = function(args)
		return args ~= "" and args or nil, ""
	end,
}

function bot:checkArg(arg, str)
	assert(converters[arg.type], "No converter for "..arg.type)
	local val, str = converters[arg.type](str)
	if val == nil then
		if arg.required and arg.default then
			val = arg.default
		end
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
	bot.mores[name] = splitLen(text, 400)
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
		text = text .. irc.bold(" (%u more)"):format(#bot.mores[name])
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
	local textList = splitRe(text, "[^\r\n]+")

	text = table.concat(textList, " \\n ")
	local textLen = #text

	if textLen > 400 then
		self:addMore(text, msg.user.nick)
		text = self:getMore(msg.user.nick)
	end
	conn:queue(irc.msgs.notice(replyTo, text))
end


function bot:registerCommand(name, def)
	def.args = def.args or {}
	for _, arg in pairs(def.args) do
		arg.id   = arg.id   or arg[1]
		arg.name = arg.name or arg[2]
		arg.type = arg.type or arg[3]
	end
	self.commands[name] = def
end


--[[
-- Built-in commands
--]]

bot:registerCommand("help", {
	args = {{"command", "Command", "text", optional=true}},
	description = "Get help with a command or list commands",
	action = function(conn, msg, args)
		if not args.command then
			local cmdlist = "Commands: "
			for name, def in pairs(bot.commands) do
				cmdlist = cmdlist..name..", "
			end
			return cmdlist.."-- Use 'help <command name>' to get"
					.." help with a specific command.", true
		end

		local cmd = bot.commands[args.command]
		if not cmd then
			return ("Unknown command '%s'."):format(args.command), false
		end

		return  ("Usage: %s %s -- %s"):format(
				args.command,
				bot:humanArgs(cmd.args),
				cmd.description), true
	end
})


bot:registerCommand("more", {
	args = {{"name", "Name", "word", optional=true}},
	description = "Return more output from a previous command",
	action = function(conn, msg, args)
		local name = args.name or msg.user.nick
		local to = bot:replyTo(conn, msg)
		local text = bot:getMore(name)
		if text then
			return text, true
		else
			return "No more!", false
		end
	end
})


bot:registerCommand("raw", {
	args = {{"message", "IRC message", "text"}},
	description = "Send a raw message to the IRC server",
	privs = {owner=true},
	action = function(conn, msg, args)
		conn:queue(args.message)
		return "Sent.", true
	end
})


bot:registerCommand("eval", {
	args = {{"code", "Lua code", "text"}},
	description = "Evaluate a chunk of Lua code",
	privs = {owner=true},
	action = function(conn, msg, args)
		local f, err = loadstring(args.code)
		if f == nil then
			return err, false
		end
		local good, err = pcall(f)
		if not good then
			return err, false
		end
		return "Code run successfully.", true
	end
})

