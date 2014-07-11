
local db = LuaDatabase("settings.lua")

function bot:loadConfig()
	db:load()
	self.config = db.data

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
	local err = db:save("\t")
	assert(not err, err)
end

bot:loadConfig()

