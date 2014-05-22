
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

	local answer, success = self:handleCommand(command, {conn=conn, msg=msg})

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
		return ("Unknown command %q. Try \"help\"."):format(cmd), false
	end

	if def.IRCOnly and not (opts.conn and opts.msg) then
		return "This command can only be used from IRC.", false
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
			return "Insuficient privileges", false
		end
	end

	local err
	args, err = self:processArgs(def.args, args)
	if err then
		return err, false
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


-- Call a command, evaluating nesting and quotes.
-- The findClose argument is for internal use only.
function bot:handleCommand(text, opts, findClose)
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
			-- Handle the command, passing findClose as true so
			-- than it will find it's nesting closer.  This is
			-- done so that quoted strings and escaped nesting
			-- closers are skipped over properly.
			local res, good, endPos = self:handleCommand(
					text:sub(pos + 1), opts, true)
			if not good then
				return res, good
			end
			-- Only add the result to the buffer.  This allows you
			-- to concatenate the result of multiple commands, and
			-- regular arguments, into one argument.  For example:
			-- > echo a<echo b>c <echo foo><echo bar>
			-- abc foobar
			argBuffer = argBuffer .. res
			pos = pos + endPos  -- Incremented below
		elseif c == nestingClose then
			if findClose then
				foundClose = true
				break
			else
				return "Unexpected nested command closer.", false
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
					return "No end to quoted string.", false
				end
			until #slashes % 2 == 0

			-- Try to unescape the string.
			local str = unescape(text:sub(pos + 1, endPos - 1))
			if not str then
				return ("Unable to read string \"%s\"")
					:format(text:sub(pos + 1, endPos - 1)), false
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
		return "Missing nested command closer.", false
	end
	save()
	local msg, good = self:runCommand(args, opts)
	return msg, good, pos
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


function bot:processArgs(args, argList)
	local a = {}
	for _, arg in ipairs(args) do
		local val = self:checkArg(arg, argList)
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

-- Converters return the processed argument, or nil on failure
local converters = {
	string  = function(args) return           table.remove(args, 1)  end,
	number  = function(args) return tonumber (table.remove(args, 1)) end,
	boolean = function(args) return toboolean(table.remove(args, 1)) end,
	word = function(args)
		local text = table.remove(args, 1)
		if text:find("[\t\n\r%z ]") then return nil end
		return text
	end,
	text = function(args)
		if not args[1] then return nil end
		local text = table.concat(args, ' ')
		for k in ipairs(args) do args[k] = nil end
		return text
	end,
}

function bot:checkArg(arg, argList)
	assert(converters[arg.type], "No converter for "..arg.type)
	local val = converters[arg.type](argList)
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
		print(("WARNING: No description provided for command %q."):format(name))
	end
	def.args = def.args or {}
	for _, arg in pairs(def.args) do
		arg.id   = arg.id   or arg[1]
		arg.name = arg.name or arg[2]
		arg.type = arg.type or arg[3]
	end
end

