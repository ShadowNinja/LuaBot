--[[
CLI controller for LuaBot

Dependencies:
  * LuaSocket
  * readline (optional)

See init.lua for protocol documentation.
--]]

local socket = require("socket")
socket.unix = require("socket.unix")
local gotReadline, readline = pcall(require, "readline")

local run = true

-- Connect to the bot
local filename = arg[1] or "control.sock"
local conn = assert(socket.unix())
assert(conn:connect(filename))
conn:settimeout(0)


local nextID = 0
function runCommand(command)
	local id = tostring(nextID)
	nextID = nextID + 1
	local good, errMsg = conn:send(("%s %s\n"):format(id, command))
	if not good then
		if errMsg == "closed" then
			run = false
			return false, "Connection closed."
		else
			return false, "Error sending command: "..errMsg
		end
	end
	local status, text
	for i = 1, 5 do
		socket.sleep(0.1)
		local line, errMsg = conn:receive("*l")
		if line then
			local recvID
			recvID, status, text = line:match("^(%S+) (%S+) (.*)$")
			assert(recvID, "Invalid protocol line: "..line)
			if recvID == id then
				status = status == "true"
				break
			end
		elseif errMsg == "closed" then
			run = false
			return false, "Connection closed."
		elseif errMsg ~= "timeout" then
			return false, "Error reading response: "..errMsg
		end
	end
	if not text then
		text = "Error: Response timed out."
		status = false
	end
	return status, text
end


print("LuaBot external command sender.")
print("Connected to unix:"..filename)
print("Type an empty line or EOF (Control-D) to quit.")

local status = true
while run do
	local prompt = (status and "✓" or "x").." > "
	local command
	if gotReadline then
		command = readline.readline(prompt)
	else
		io.write(prompt)
		io.flush()
		command = io.read()
	end
	if not command then
		io.write('\n')
		break
	elseif command == "" then
		break
	end
	local text
	status, text = runCommand(command)
	if text ~= "" then
		print(text)
	end
end

conn:close()

