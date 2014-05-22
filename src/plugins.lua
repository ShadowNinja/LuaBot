
local path = require("pl.path")

bot.plugins = {}

function bot:loadConfiguredPlugins()
	for name, conf in pairs(self.config.plugins) do
		if conf and not (type(conf) == "table" and conf.unloaded) then
			self:loadPlugin(name, false, conf)
		end
	end
end


local function setup(plugin)
	if plugin.hooks then
		for name, func in pairs(plugin.hooks) do
			bot:hook(name, func)
		end
	end
	if plugin.commands then
		for name, def in pairs(plugin.commands) do
			bot:checkCommandRegistration(name, def)
		end
	end
end


function bot:loadPlugin(name, persist, conf)
	if self.plugins[name] then
		return nil, "Plugin already loaded"
	end
	conf = conf or self.config.plugins[name]
	local pluginPath
	for _, searchPath in ipairs(self.config.pluginPaths) do
		local checkPath = searchPath .. path.sep .. name
		if path.isdir(checkPath) then
			pluginPath = checkPath
		end
	end
	if not pluginPath then
		return nil, ("Plugin %s not found."):format(name)
	end
	local func, err = loadfile(pluginPath .. path.sep .. "init.lua")
	if err then
		return nil, ("Error loading plugin %s: %s"):format(name, err)
	end
	local good, plugin = xpcall(func, debug.traceback, pluginPath, conf)
	if not good then
		bot:log("error", plugin)
		return nil, plugin
	end
	plugin = plugin or {}
	self.plugins[name] = plugin
	setup(plugin)
	if persist then
		local plugins = self.config.plugins
		if type(plugins[name]) == "table" then
			plugins[name].unloaded = nil
		elseif not plugins[name] then
			plugins[name] = conf or true
		end
		self:saveConfig()
	end
	return plugin
end


local function cleanup(plugin)
	if plugin.hooks then
		for name, func in pairs(plugin.hooks) do
			bot:unhook(name, func)
		end
	end
end


function bot:unloadPlugin(name, persist)
	if not self.plugins[name] then
		return false, "Plugin not loaded"
	end
	self:call("pluginUnload", name)
	local plugin = self.plugins[name]
	if type(plugin.unload) == "function" then
		plugin:unload()
	end
	cleanup(plugin)
	self.plugins[name] = nil
	if persist then
		local plugins = self.config.plugins
		if type(plugins[name]) == "table" then
			plugins[name].unloaded = true
		else
			plugins[name] = false
		end
		self:saveConfig()
	end
	return true
end


function bot:reloadPlugin(name, persist)
	local good, msg = self:unloadPlugin(name, persist)
	if not good then
		return good, msg
	end
	local good, msg = self:loadPlugin(name, persist)
	if not good then
		return good, msg
	end
	return true
end

