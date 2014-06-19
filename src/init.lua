
package.path = package.path .. ";./?/init.lua"

local socket = require("socket")
irc = require("irc")
require("pl.stringx").import()
require("pl.strict")

bot = {}
bot.versionString = "LuaBot 0.1"
bot.conns = {}

-- LuaJIT compatability
table.unpack = table.unpack or unpack

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
loadFile("log")
loadFile("misc")


local function safeThink(conn)
	-- We need the wrapper function to pass the implict self parameter
	local good, errMsg = xpcall(function()
			conn:think()
		end, debug.traceback)
	if not good then
		bot:log("error", errMsg)
	end
	return good
end

function bot:main()
	bot:log("info", "Initializing...")
	self:registerHooks()
	self:loadConfiguredPlugins()

	for name, data in pairs(self.config.networks) do
		if data.autoConnect ~= false then
			bot:log("info", ("Connecting to %s..."):format(name))
			self.conns[name] = self:connect(name, data)
		end
	end

	bot:log("info", "Entering main loop.")
	local stepTime, stepTimeNoSleep = 0, 0
	while not self.kill do  -- Main loop
		local stepStart = socket.gettime()

		self:call("step", stepTime, stepTimeNoSleep)

		local numConns = 0
		for _, conn in pairs(self.conns) do
			safeThink(conn)
			numConns = numConns + 1
		end

		if numConns < 1 then
			bot:log("important", "All connections closed.  Shutting down.")
			break
		end

		stepTimeNoSleep = socket.gettime() - stepStart
		sleep(math.max(0.2 - stepTimeNoSleep, 0.1))
		stepTime = socket.gettime() - stepStart
	end
end


function bot:shutdown()
	bot:log("info", "Shutting down...")
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
		password = data.password,
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


local flushInterval = bot.config.flushInterval or 300

function bot:flush(final)
	bot:log("debug", "Flushing...")
	bot:call("flush", final)
end

bot:schedule(flushInterval, true, bot.flush, bot, false)

bot:register("shutdown", function()
	bot:flush(true)
end)


-- Try to register a signal handler for SIGINT
local gotPosix, posix = pcall(require, "posix")
if gotPosix then
	posix.signal(posix.SIGINT, function() bot:shutdown() end)
end

bot:main()
bot:shutdown()

