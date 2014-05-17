
package.path = package.path .. ";./?/init.lua"

irc = require("irc")
require("pl.stringx").import()
require("pl.strict")

bot = {}
bot.versionString = "LuaBot 0.1"
bot.conns = {}

local function loadFile(name)
	dofile(("src/%s.lua"):format(name))
end

loadFile("config")
loadFile("util")
loadFile("hooks")
loadFile("register")
loadFile("schedule")
loadFile("plugins")
loadFile("commands")


local function safeThink(conn)
	-- We need the wrapper function to pass the implice self parameter
	local good, errMsg = xpcall(function()
			conn:think()
		end, debug.traceback)
	if not good then
		print(errMsg)
	end
	return good
end

function bot:main()
	print("Initializing...")
	self:loadConfig()
	self:registerHooks()
	self:loadConfiguredPlugins()

	for name, data in pairs(self.config.networks) do
		print(("Connecting to %s..."):format(name))
		self.conns[name] = self:connect(name, data)
	end

	print("Entering main loop.")
	local dtime = 0
	while not self.kill do  -- Main loop
		local loopStart = os.clock()

		self:call("step", dtime)

		local numConns = 0
		for _, conn in pairs(self.conns) do
			safeThink(conn)
			numConns = numConns + 1
		end

		if numConns < 1 then
			print("All connections closed.  Shutting down.")
			break
		end

		dtime = os.clock() - loopStart
		sleep(math.max(0.2 - dtime, 0.1))
	end
end


function bot:shutdown()
	print("Shutting down...")
	self:call("shutdown")

	for _, conn in pairs(self.conns) do
		self:disconnect(conn.network)
	end
	os.exit()
end


function bot:connect(name, data)
	local conn = irc.new({
		nick = data.nick,
		username = data.username,
		realname = data.realname,
	})
	conn.network = name
	self:hookup(conn)
	conn:connect({
		host = data.host,
		port = data.port,
		secure = data.secure,
	})
	conn:invoke("OnConnect")
	for chanName, info in pairs(data.channels) do
		if info.autoJoin then
			conn:join(chanName, info.key)
		end
	end
	return conn
end


function bot:disconnect(name, message)
	local conn = self.conns[name]
	if not conn then
		error(("Tried to disconnect from non-existant"
			.." connection %s."):format(name))
	end
	-- Make sure final messages get through
	safeThink(conn)
	conn:disconnect(message or self.config.quitMessage)
	self.conns[name] = nil
end

-- Try to register a signal handler for SIGINT
local gotPosix, posix = pcall(require, "posix")
if gotPosix then
	posix.signal(posix.SIGINT, function() bot:shutdown() end)
end

bot:main()
bot:shutdown()

