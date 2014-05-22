
local socket = require("socket")
local mime = require("mime")  -- Part of luasocket
local pretty = require("pl.pretty")

base64e = mime.b64
base64d = mime.unb64


function toboolean(x)
	local t = type(x)
	if t == "string" then
		x = x:lower()
		if x == "true" or x == "yes" or x == "on" or
				x == "enable" or x == "enabled" then
			return true
		elseif x == "false" or x == "no" or x == "off" or
				x == "disable" or x == "disabled" then
			return false
		else
			return nil
		end
	else
		return x and true or false
	end
end


function sleep(seconds)
	if seconds <= 0 then return end
	socket.sleep(seconds)
end


function dump(data, indent)
	return pretty.write(data, indent or "\t")
end


function splitRe(str, re)
	local t = {}
	for s in str:gmatch(re) do
		table.insert(t, s)
	end
	return t
end


function string:findAll(match, start, raw)
	local positions = {}
	local nextPos = start
	local pos = nil
	repeat
		pos = self:find(match, nextPos, raw)
		if pos then
			table.insert(positions, pos)
			nextPos = pos + 1
		end
	until not pos
	return positions
end


function string:isNickChar()
	return self:find("^[a-zA-Z0-9_%-%[|%]%^{|}`]$") ~= nil
end


function string:max(maxLen)
	assert(maxLen >= 3, "Argument to string.max must be at least 3")
	if #self > maxLen then
		return self:sub(1, maxLen - 3).."..."
	end
	return self
end


function table.maxn(t)
	local max = 0
	for k, v in pairs(t) do
		if type(k) == "number" and k > max then
			max = k
		end
	end
	return max
end


local unescapeEnv = {}
function unescape(s)
	-- Check for a string closer (eg, [[test", print("foo")]])
	for slashes in s:gmatch("(\\*)\"") do
		if #slashes % 2 == 0 then
			return nil
		end
	end
	local f = load('return "'..s..'"', "UnescapeSandbox", "t", unescapeEnv)
	local good, str = pcall(f)
	if good then
		return str
	end
	return nil
end

