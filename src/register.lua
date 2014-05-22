
local registeredFuncs = {}


-- For internal use only
function bot:register(class, func)
	registeredFuncs[class] = registeredFuncs[class] or {}
	table.insert(registeredFuncs[class], func)
end


function bot:call(class, ...)
	if not registeredFuncs[class] then
		return
	end
	-- Call internal functions first
	if registeredFuncs[class] then
		for _, func in ipairs(registeredFuncs[class]) do
			func(...)
		end
	end
	-- Then call registered functions in plugins
	for pluginName, plugin in pairs(self.plugins) do
		local registered = plugin.on
		if registered and registered[class] then
			registered[class](...)
		end
	end
end

