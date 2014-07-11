local pretty = require("pl.pretty")

--- Loads a Lua value from a file created with saveLuaData().
-- The lua file may contain a nil.  If that is valid you will have
-- to check for the error message to determine if the load was successfull.
-- @param filename The file to load from.
-- @return The loaded data, or nil on error.
-- @return Error message, or nil on success.
-- @see saveLuaData
local function loadLuaData(filename)
	local file, err = io.open(filename, "r")
	if not file then
		return nil, err
	end
	local data, err = pretty.read(file:read("*all"))
	file:close()
	return data, err
end

--- Saves a Lua value to a file in Lua-like format.
-- @param filename The name of the file to save to
-- @param data The Lua value to save.
-- @param indent Indentation to use, if any.
-- @return Error message, or nil on success.
-- @see loadLuaData
local function saveLuaData(filename, data, indent)
	local dataStr, err = pretty.write(data, indent or "")
	if not dataStr then
		return err
	end
	local file, err = io.open(filename, "w")
	if not file then
		return err
	end
	file:write(dataStr)
	file:close()
end


-----------------------
-- LuaDatabase class --
-----------------------

local meta = {}
meta.__index = meta

--- Database class that stores data in a file in Lua-like format.
-- @param filename The file for the database to operate on.
-- @param data Initial data for the database.
-- @return A database instance.
-- @field data Database data.
-- @field filename Database filename.
function LuaDatabase(filename, data)
	local o = {
		filename = filename,
		data = data or {},
	}
	return setmetatable(o, meta)
end

--- Save data to the database file.
-- @name LuaDatabase:save
function meta:load()
	local data, err = loadLuaData(self.filename)
	if not err then
		self.data = data
	end
	return err
end

--- Load data from the database file.
-- @name LuaDatabase:load
-- @param indent Indentation to use, if any.
function meta:save(indent)
	return saveLuaData(self.filename, self.data, indent)
end

