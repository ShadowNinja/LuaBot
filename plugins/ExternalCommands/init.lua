--[[
External commands

This creates a unix domain socket and listens on it for connections from
external command senders.  Messages have the form:
	<ID> ' ' <Command> ' ' [Arguments] '\n'
Where <ID> is a string used to identify the command.

The response is of the form:
	<ID> ' ' <Status> ' ' <Text> '\n'
Where:
  * <ID> is the ID of the command that triggered this response,
  * <Status> is a boolean indicating success or failure,
  * <Text> is the response text that the command returned.


Configuration:
  * socket - The name of the unix socket file (default "control.sock")
--]]

local pluginPath, conf = ...

local socket = require("socket")
socket.unix = require("socket.unix")

local m = {on = {}}

-- Create server
local filename = type(conf) == "table" and conf.socket or "control.sock"
local server = assert(socket.unix())
assert(server:bind(filename))
assert(server:listen(3))
server:settimeout(0)
local clients = {}


local cmdOpts = {privs = {"owner"}}

function m.on.step()
	local client, errMsg = server:accept()
	if client then
		client:settimeout(0)
		table.insert(clients, client)
	elseif errMsg ~= "timeout" then
		bot:log("error", "While accepting remote command clients: "..errMsg)
	end
	local i = 1
	while clients[i] do
		local client = clients[i]
		local line, errMsg = client:receive("*l")
		if line then
			local id, cmd = line:match("(%S+) (.+)")
			assert(id, ("Invalid command message %q received."):format(line))
			bot:log("action", ("External command (id: %s): %s"):format(id, cmd))
			local text, status = bot:handleCommand(cmd, cmdOpts)
			local good, errMsg = client:send(("%s %s %s\n"):format(id, status, text))
			if not good then
				bot:log("error", "While sending command response: "..errMsg)
			end
		elseif errMsg == "closed" then
			table.remove(clients, i)
			-- Skip incrementing of i
			goto continue
		elseif errMsg ~= "timeout" then
			bot:log("error", "While reading command: "..errMsg)
		end
		i = i + 1
		::continue::
	end
end


local function cleanup()
	for _, client in pairs(clients) do
		client:close()
	end
	clients = {}
	server:close()
	os.remove(filename)
end


m.unload = cleanup
m.on.shutdown = cleanup

return m

