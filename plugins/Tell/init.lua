
local m = {commands = {}, hooks = {}}

local path, conf = ...
local filename = type(conf) == "table" and conf.filename or "tell.lua"

local db = LuaDatabase(filename)
db:load()

local function countMessages(conn, lnick)
	local count = 0
	for i, entry in pairs(db.data) do
		if entry.to:lower() == lnick and entry.network == conn.network then
			count = count + 1
		end
	end
	return count
end

m.commands.tell = {
	args = {{"nick", "Nick", "nick"},
		{"text", "Text", "text"}},
	description = "Gives a message to a nick when they are next seen.",
	IRCOnly = true,
	action = function(conn, msg, args)
		local lnick = args.nick:lower()
		if lnick == conn.nick:lower() then
			return false, "I can't tell myself something!"
		end
		if lnick == msg.user.nick:lower() then
			return false, "You can tell that to yourself!"
		end
		if #args.text > 400 then
			return false, "Messages longer than 400 characters are not allowed."
		end
		if countMessages(conn, lnick) >= 8 then
			return false, "I'm already holding too many messages for that user."
		end
		if #db.data > 32 then
			return false, "I'm already holding too many messages."
		end
		table.insert(db.data, {
			time = os.time(),
			network = conn.network,
			from = msg.user.nick,
			to = args.nick,
			text = args.text,
		})
		db:save()
		return true, ("I'll tell that to %q next time I see them around."):format(args.nick)
	end,
}

local function checkMessage(conn, user)
	if not user.nick then return end
	local lnick = user.nick:lower()
	local changed = false
	local data = db.data
	local i = 1
	while data[i] do
		local entry = data[i]
		if entry.to:lower() == lnick and entry.network == conn.network then
			bot:say(conn, user.nick, ("[%s] <%s> %s: %s"):format(
					os.date("%Y-%m-%dT%H:%M:%S", entry.time),
					entry.from, entry.to, entry.text),
				user.nick
			)
			table.remove(data, i)
			changed = true
		else
			i = i + 1
		end
	end
	if changed then
		db:save()
	end
end

m.hooks.OnJoin = checkMessage
m.hooks.OnChat = checkMessage
m.hooks.OnNotice = checkMessage

return m

