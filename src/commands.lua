
bot.commands = {}
bot.mores = {}


-- Check of a IRC message is a command, and call handleCommand if so
function bot:checkCommand(conn, msg)
	local prefix = self.config.prefix
	local nick = conn.nick:lower()
	local text = msg.args[2]
	local nickpart = text:sub(1, #nick + 2):lower()

	-- First check for a nick prefix
	if nickpart == nick..": " or nickpart == nick..", " then
		text = text:sub(#nick + 3)
	-- Then check for the configured prefix
	elseif prefix and text:sub(1, #prefix):lower() == prefix:lower() then
		text = text:sub(#prefix + 1)
	-- Finally, all PMs are commands
	elseif msg.args[1] == conn.nick then
		-- Fall through
	else
		return false
	end

	local answer, success = self:handleCommand(conn, msg, text)

	if answer then
		self:reply(conn, msg, answer)
	end
	return true
end


-- Split into command and args, then call
function bot:handleCommand(conn, msg, line, opts)
	opts = opts or {}
	-- Parse command
	local def, cmd, args, pos
	pos = 1
	repeat
		pos = line:find(" ", pos, true)
		if pos then
			cmd = line:sub(1, pos - 1)
			args = line:sub(pos + 1)
			-- Skip space so that we don't find the same one next run
			pos = pos + 1
		else
			cmd = line
			args = ""
		end
		def = self.commands[cmd]
	until def or not pos

	args = args:split()

	if not def then
		return ("Unknown command '%s'. Try 'help'."):format(cmd), false
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

	return self.commands[cmd].action(conn, msg, args)
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


function bot:registerCommand(name, desc)
	self.commands[name] = desc
end


--[[
-- Built-in commands
--]]

bot:registerCommand("help", {
	params = "[command]",
	description = "Get help with a command or list commands",
	action = function(conn, msg, args)
		if not args[1] then
			local cmdlist = "Commands: "
			for name, def in pairs(bot.commands) do
				cmdlist = cmdlist..name..", "
			end
			return cmdlist.."-- Use 'help <command name>' to get"
					.." help with a specific command.", true
		end

		local cmd = bot.commands[args[1]]
		if not cmd then
			return ("Unknown command '%s'."):format(args[1]), false
		end

		return  ("Usage: %s %s -- %s"):format(
				args[1],
				cmd.params or "<no parameters>",
				cmd.description), true
	end
})


bot:registerCommand("more", {
	params = "[name]",
	description = "Return more output from a previous command",
	action = function(conn, msg, args)
		local name = args[1] or msg.user.nick
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
	params = "<IRC message>",
	privs = {owner=true},
	description = "Send a raw line to the IRC server",
	action = function(conn, msg, args)
		if #args < 1 then
			return "Command required.", false
		end
		conn:queue(table.concat(args, " "))
		return "Sent.", true
	end
})


bot:registerCommand("eval", {
	params = "<Lua code>",
	description = "Evaluate a chunk of Lua code",
	privs = {owner=true},
	action = function(conn, msg, args)
		if not args[1] then
			return "No code!", false
		end
		local f, err = loadstring(table.concat(args, " "))
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

