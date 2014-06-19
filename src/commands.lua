
local tablex = require("pl.tablex")

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

	local success, answer = self:handleCommand(command, {conn=conn, msg=msg})

	if answer then
		self:reply(conn, msg, answer)
	end
	return true
end


-- Run a single command
function bot:runCommand(parts, opts)
	opts = opts or {}
	-- Milti-word commands work with quotes.  For example:
	-- > "command with spaces" args
	local cmd = table.remove(parts, 1)
	local args = parts
	local def = self:getCommand(cmd)

	if not def then
		return false, ("Unknown command %q. Try \"help\"."):format(cmd)
	end

	if def.IRCOnly and not (opts.conn and opts.msg) then
		return false, "This command can only be used from IRC."
	end

	if def.privs then
		local privs
		if opts.privs then
			privs = opts.privs
		elseif opts.msg and opts.msg.user then
			privs = self:getPrivs(opts.msg.user)
		else
			privs = {}
		end
		if not self:checkPrivs(def.privs, privs) then
			return false, "Insuficient privileges"
		end
	end

	local err
	args, err = self:processArgs(opts.conn, opts.msg, def.args, args)
	if err then
		return false, err
	end

	return def.action(opts.conn, opts.msg, args)
end


function bot:getCommand(name)
	name = name:lower()
	for pluginName, plugin in pairs(self.plugins) do
		if plugin.commands and plugin.commands[name] then
			return plugin.commands[name]
		end
	end
end


local nesting = bot.config.nesting or "<>"
local nestingOpen, nestingClose = nesting:sub(1, 1), nesting:sub(2, 2)


function bot:parseCommand(text, findClose)
	local args = {}
	-- This holds the argument that is currently being read,
	-- before being save()d into args.
	local argBuffer = ""
	local pos = 1
	local textLen = #text
	local foundClose = false
	local function save()
		-- Empty arguments are supported with quotes
		if argBuffer ~= "" then
			table.insert(args, argBuffer)
			argBuffer = ""
		end
	end
	while pos <= textLen do
		local c = text:sub(pos, pos)
		if c == "\\" then
			pos = pos + 1
			argBuffer = argBuffer .. text:sub(pos, pos)
		elseif c == nestingOpen then
			save()
			-- Parse the nested command, passing findClose as true
			-- so that it will find it's nesting closer.  This is
			-- done so that quoted strings and escaped nesting
			-- closers are skipped over properly.
			local res, endPos = self:parseCommand(
					text:sub(pos + 1), true)
			if not res then
				return res, endPos
			end
			table.insert(args, res)
			pos = pos + endPos  -- Incremented below
		elseif c == nestingClose then
			if findClose then
				foundClose = true
				break
			else
				return false, "Unexpected nested command closer."
			end
		elseif c == '"' then
			save()
			-- Find the end of the quote.  A quote is ended by a
			-- double-quote character preceded by an even number
			-- (including 0) of backslashes.
			local endPos = pos
			local _, slashes
			repeat
				_, endPos, slashes = text:find("(\\*)\"", endPos + 1)
				if not endPos then
					return false, "No end to quoted string."
				end
			until #slashes % 2 == 0

			-- Try to unescape the string.
			local str = unescape(text:sub(pos + 1, endPos - 1))
			if not str then
				return false, ("Unable to read string \"%s\"")
					:format(text:sub(pos + 1, endPos - 1))
			end

			table.insert(args, str)
			pos = endPos  -- Incremented below
		elseif c == " " then
			save()
		else
			argBuffer = argBuffer .. c
		end
		pos = pos + 1
	end
	if findClose and not foundClose then
		return false, "Missing nested command closer."
	end
	save()
	return args, pos
end


function bot:evalCommand(args, opts)
	for i, arg in ipairs(args) do
		if type(arg) == "table" then
			args[i] = select(2, self:evalCommand(arg, opts))
		end
	end
	return self:runCommand(args, opts)
end


function bot:handleCommand(text, opts)
	local args, msg = self:parseCommand(text)
	if not args then return false, msg end
	return self:evalCommand(args, opts)
end


function bot:getPrivs(user)
	local privs = {}
	for mask, privSet in pairs(self.config.privs) do
		local matchStr = ("%s@%s"):format(user.user, user.host)
		if matchStr:find(mask) then
			for _, priv in pairs(privSet) do
				table.insert(privs, priv)
			end
		end
	end
	return privs
end


function bot:checkPrivs(needs, has, ignoreOwner, needOnlyOne)
	if not ignoreOwner and tablex.find(has, "owner") then
		return true
	end
	for _, needPriv in pairs(needs) do
		local hasCurrent = false
		if type(needPriv) == "table" then
			-- List of privs, of which only one is needed
			hasCurrent = self:checkPrivs(needPriv, has,
					ignoreOwner, not needOnlyOne)
		elseif tablex.find(has, needPriv) then
			hasCurrent = true
		end
		if needOnlyOne and hasCurrent then
			return true
		elseif not needOnlyOne and not hasCurrent then
			return false
		end
	end
	if needOnlyOne then
		return false
	else
		return true
	end
end


function bot:processArgs(conn, msg, args, argList)
	local a = {}
	for _, arg in ipairs(args) do
		local val = self:checkArg(conn, msg, arg, argList)
		if val ~= nil then
			a[arg.id] = val
		elseif not arg.optional then
			return nil, ("Required argument %s missing"):format(arg.name)
		end
	end
	if argList and argList[1] then
		return nil, "Too many arguments."
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

-- Converters are functions that process a command argument.
-- They are passed the Connection, Message, and argument list.
-- The Connection and Message may be nil.
-- The argument list must be modified in-place to remove any processed arguments.
-- Converters return the processed argument, or nil on failure
local converters = {
	string  = function(conn, msg, args) return           table.remove(args, 1)  end,
	number  = function(conn, msg, args) return tonumber (table.remove(args, 1)) end,
	boolean = function(conn, msg, args) return toboolean(table.remove(args, 1)) end,
	channel = function(conn, msg, args)
		if args[1] and bot:isChannel(args[1], conn) then
			return table.remove(args, 1)
		elseif msg and bot:isChannel(msg.args[1], conn) then
			return msg.args[1]
		end
	end,
	nick = function(conn, msg, args)
		if args[1] and bot:isNick(args[1]) then
			return table.remove(args, 1)
		elseif msg then
			return msg.user.nick
		end
	end,
	word = function(conn, msg, args)
		if not args[1] or args[1]:find("[\t\n\r%z ]") then
			return nil
		end
		return table.remove(args, 1)
	end,
	text = function(conn, msg, args)
		if not args[1] then return nil end
		local text = table.concat(args, ' ')
		for k in ipairs(args) do args[k] = nil end
		return text
	end,
}

function bot:checkArg(conn, msg, arg, argList)
	assert(converters[arg.type], "No converter for "..arg.type)
	local val = converters[arg.type](conn, msg, argList)
	if val == nil and arg.default ~= nil then
		val = arg.default
	end
	return val
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
	assert(def.action, ("No action provided for command %q."):format(name))
	if not def.description then
		self:log("warning",
			("No description provided for command %q.")
				:format(name))
	end
	def.args = def.args or {}
	for _, arg in pairs(def.args) do
		arg.id   = arg.id   or arg[1]
		arg.name = arg.name or arg[2]
		arg.type = arg.type or arg[3]
	end
end

