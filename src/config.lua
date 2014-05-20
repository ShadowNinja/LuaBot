
local pretty = require("pl.pretty")

function bot:loadConfig()
	local file = io.open("settings.lua", "r")

	if file then
		self.config = pretty.read(file:read("*all"))
		file:close()
	end

	self.config = self.config or {}

	local defaults = {
		debug = true,
		quitMessage = "Disconecting...",
		networks = {},
		pluginPaths = {"plugins"},
	}

	for k, v in pairs(defaults) do
		if self.config[k] == nil then
			self.config[k] = v
		end
	end
end


function bot:saveConfig()
	local file, err = io.open("settings.lua", "w")
	if not file then
		error("Unable to write config file: "..err)
	end
	local confStr, err = pretty.write(bot.config, "\t")
	if not confStr then
		error("Unable to serialize settings: "..err)
	end
	file:write(confStr)
	file:close()
end

bot:loadConfig()

