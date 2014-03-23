
bot.schedule = {
	events = {},
}


function bot.schedule:add(after, func, ...)
	local time = os.time()
	table.insert(self.events, {
		time = time + after,
		func = func,
		args = {...}
	})
end


bot:register("step", function(dtime)
	local time = os.time()
	local events = bot.schedule.events
	local i = 1
	while events[i] ~= nil do
		local event = events[i]
		if event.time <= time then
			event.func(unpack(event.args))
			table.remove(events, i)
		else
			i = i + 1
		end
	end
end)

