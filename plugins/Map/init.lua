--[[
-- Plugin to generate a network channel user map
--
-- This requires the Oper plugin, a valid operator block on the server, and
--  the oper:spy privilege.
--]]

local json = require("json")
local m = {commands = {}, hooks = {}}
local pluginPath, conf = ...

local waitingListEnd = false
local chanUsers = {}
local chansWaiting = {}


m.commands.genmap = {
	description = "Generate network channel user map",
	privs = {"map"},
	IRCOnly = true,
	action = function(conn, msg, args)
		waitingListEnd = true
		conn:queue(irc.Message("LIST"))
		return true, "Generating map..."
	end,
}


local function generateMap(conn)
	local nodes = {}
	local edges = {}
	local nickIDs = {}

	local id = 1
	for channel, nicks in pairs(chanUsers) do
		local cid = id
		table.insert(nodes, {
			id = id,
			label = channel,
			fontSize = 24,
			color = "green",
		})
		id = id + 1
		for i, nick in pairs(nicks) do
			if nickIDs[nick] then
				table.insert(edges, {
					from = cid,
					to = nickIDs[nick],
				})
			else
				nickIDs[nick] = id
				table.insert(nodes, {
					id = id,
					label = nick,
					shape = "box",
				})
				table.insert(edges, {
					from = cid,
					to = id,
				})
				id = id + 1
			end
		end
	end

	-- Reset tables
	chanUsers = {}
	chansWaiting = {}

	-- Write data
	local f, err = io.open(conf.filename or "map.js", "w")
	if not f then return end
	f:write("window.nodes = ")
	f:write(json.encode(nodes))
	f:write("\n")
	f:write("window.edges = ")
	f:write(json.encode(edges))
	f:write("\n")
	f:close()
end

-- LIST
function m.hooks:Do322(msg)
	if not waitingListEnd then
		return
	end
	local channel = msg.args[2]
	chanUsers[channel] = chanUsers[channel] or {}
	chansWaiting[channel] = true
	self:queue(irc.Message("WHO", {"!"..channel}))
end

-- End of /LIST
function m.hooks:Do323(msg)
	if waitingListEnd then
		waitingListEnd = false
	end
end


-- WHO list
function m.hooks:Do352(msg)
	local channel = msg.args[2]
	local nick = msg.args[6]
	if not chansWaiting[channel] then
		return
	end
	if not nick:find("Serv$") then
		table.insert(chanUsers[channel], nick)
	end
end


-- End of /WHO list
function m.hooks:Do315(msg)
	local channel = msg.args[2]
	if not chansWaiting[channel] then
		return
	end
	chansWaiting[channel] = nil

	-- Return if we are still waiting for more channels
	for _, _ in pairs(chansWaiting) do
		return
	end
	generateMap(self)
end

return m

