
bot.registeredFuncs = {}


function bot:register(class, func)
	self.registeredFuncs[class] = self.registeredFuncs[class] or {}
	table.insert(self.registeredFuncs[class], func)
end


function bot:call(class, ...)
	if not self.registeredFuncs[class] then
		return
	end
	for _, func in ipairs(self.registeredFuncs[class]) do
		func(...)
	end
end

