--[[
-- Plugin to oper-up on connect
--
-- Usage:
--  Set plugins.Oper.<network>.username and plugins.Oper.<network>.password in
--  the network block to the oper username and oper password for the bot.
--]]

local path, conf = ...

bot:hook("OnConnect", function(conn)
	local netConf = conf[conn.network]
	if not netConf or not netConf.username or not netConf.password then
		return
	end
	conn:queue(irc.Message("OPER", {netConf.username, netConf.password}))
end)


