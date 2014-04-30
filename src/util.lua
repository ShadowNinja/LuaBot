
local socket = require("socket")
local mime = require("mime")  -- Part of luasocket
local pretty = require("pl.pretty")

base64e = mime.b64
base64d = mime.unb64


function sleep(s)
	if s <= 0 then return end
	socket.select(nil, nil, s)
end


function dump(data, indent)
	return pretty.write(data, indent)
end


function bot:getPrivs(user)
	local privs = {}
	for mask, privSet in pairs(self.config.privs) do
		if user.host:find(mask) then
			for _, priv in pairs(privSet) do
				privs[priv] = true
			end
		end
	end
	return privs
end


function bot:checkPrivs(needs, has, ignoreOwner)
	if not ignoreOwner and has.owner then
		return true
	end
	for priv, _ in pairs(needs) do
		if not has[priv] then
			return false
		end
	end
	return true
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

