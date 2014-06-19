
--- Checks if a string is a valid IRC channel.
-- @param str The string to check.
-- @param conn An active Connection, optional
function bot:isChannel(str, conn)
	if str == "" then return false end
	local prefix = str:sub(1, 1)
	local chanTypes = conn and conn.supports.CHANTYPES or "#&!+"
	for chanType in chanTypes:gmatch(".") do
		if prefix == chanType then
			return true
		end
	end
	return false
end

--- Checks if a string is a valid IRC nickname.
-- Distinct from irc.checkNick in that it accepts normally invalid nicks
-- (nicks starting with a decimal digit) that are sometimes set by the server.
-- @param str The string to check.
function bot:isNick(str)
	return str:find("^[a-zA-Z0-9_%-%[|%]%^{|}`]+$") ~= nil
end

