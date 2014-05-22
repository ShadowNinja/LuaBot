
local tablex = require("pl.tablex")

local colors = {
	black = 30,
	red = 31,
	green = 32,
	yellow = 33,
	blue = 34,
	magenta = 35,
	cyan = 36,
	white = 37,
}

local function ANSIColor(color, text)
	assert(colors[color], ("ANSI Color %q does not exist"):format(color))
	return string.format("\x1B[%um%s\x1B[0m", colors[color], text)
end

local levels = {
	error = {color = "red"},
	warning = {color = "yellow"},
	important = {color = "yellow"},
	action = {color = "green"},
	info = {color = nil},
	debug = {color = "cyan"},
}

local useColor = bot.config.log.color
if useColor == nil then useColor = true end
local enabledLevels = bot.config.log.levels
local logFilename = bot.config.log.filename
local toWriteBuffer = {}


local function logToFile(str)
	if not logFilename then return end
	table.insert(toWriteBuffer, str)
end


bot:register("flush", function(final)
	if not logFilename then return end
	if not (#toWriteBuffer > 0) then
		return
	end

	local file = io.open(logFilename, "a")
	if not file then return end

	for _, str in ipairs(toWriteBuffer) do
		file:write(str.."\n")
	end

	if final then
		file:write(string.rep("*", 80).."\n")
	end

	file:close()
	toWriteBuffer = {}
end)


function bot:log(level, text)
	if not levels[level] or (level ~= "important" and
			not tablex.find(enabledLevels, level)) then
		return
	end
	local str = ("[%s] %s: %s"):format(
		os.date("%Y-%m-%dT%H:%M:%S"),
		level,
		text
	)
	logToFile(str)
	if useColor and levels[level].color then
		str = ANSIColor(levels[level].color, str)
	end
	print(str)
end

