
local socket = require("socket")  -- For gettime


bot.scheduledEvents = {}


function bot:schedule(after, repeats, func, ...)
	assert(type(after) == "number" and after >= 0,
			"Argument #1 to schedule must be a positive number")
	assert(type(func) == "function",
			"Argument #3 to schedule must be a function")
	local time = socket.gettime()
	table.insert(self.scheduledEvents, {
		time = time,
		after = after,
		func = func,
		repeats = repeats,
		args = {...},
	})
end


bot:register("step", function(dtime)
	local time = socket.gettime()
	local events = bot.scheduledEvents
	local i = 1
	while events[i] ~= nil do
		local event = events[i]
		if (event.time + event.after) <= time then
			event.func(table.unpack(event.args))
			if event.repeats then
				event.time = event.time + event.after
				i = i + 1
			else
				table.remove(events, i)
			end
		else
			i = i + 1
		end
	end
end)

