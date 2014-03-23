
local path = require("pl.path")

bot.plugins = {}


function bot:loadPlugins()
	for name, conf in pairs(self.config.plugins) do
		local pluginPath
		for _, searchPath in ipairs(self.config.pluginPaths) do
			local checkPath = searchPath .. path.sep .. name
			if path.isdir(checkPath) then
				pluginPath = checkPath
			end
		end
		if not pluginPath then
			error(("Plugin %s not found."):format(name))
		end
		local func, err = loadfile(pluginPath .. path.sep .. "init.lua")
		if err then
			error(("Error loading plugin %s: %s")
					:format(name, err))
		end
		self.plugins[name] = func(conf, pluginPath)
	end
end

