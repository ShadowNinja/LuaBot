--[[
-- Plugin to oper-up on connect
--
-- Usage:
--  Set oper.username and oper.password in the network block to
--  the oper username and oper password for the bot.
--]]

local m = {hooks = {}}

function m.hooks:OnConnect()
	local netConf = bot.config.networks[self.network].oper
	if not netConf or not netConf.username or not netConf.password then
		return
	end
	self:queue(irc.Message("OPER", {netConf.username, netConf.password}))
end

return m

