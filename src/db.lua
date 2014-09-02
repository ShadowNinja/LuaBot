local pretty = require("pl.pretty")
local serialization = require("src.serialize")

--- Loads a Lua value from a file created with saveLuaData().
-- The lua file may contain a nil.  If that is valid you will have
-- to check for the error message to determine if the load was successfull.
-- @param filename The file to load from.
-- @return The loaded data, or nil on error.
-- @return Error message, or nil on success.
-- @see saveLuaData
local function loadLuaData(filename, advanced)
	local file, err = io.open(filename, "r")
	if not file then
		return nil, err
	end
	local str = file:read("*all")
	local data, err
	if advanced then
		data, err = serialization.deserialize(str)
	else
		data, err = pretty.read(str)
	end
	file:close()
	return data, err
end

--- Saves a Lua value to a file in Lua-like format.
-- @param filename The name of the file to save to
-- @param data The Lua value to save.
-- @param indent Indentation to use, if any.
-- @return Error message, or nil on success.
-- @see loadLuaData
local function saveLuaData(filename, data, advanced, indent)
	local dataStr, err
	if advanced then
		dataStr, err = serialization.serialize(data)
	else
		dataStr, err = pretty.write(data, indent or "")
	end
	if err then return err end
	local file, err = io.open(filename, "w")
	if not file then return err end
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
-- @param advanced Whether the file is saved in a advanced format with support
--		for things like multiple references, recursion, and functions.
-- @param data Initial data for the database.
-- @return A database instance.
-- @field filename Database filename.
-- @field data Database data.
function LuaDatabase(filename, advanced, data)
	local o = {
		filename = filename,
		advanced = advanced,
		data = data or {},
	}
	return setmetatable(o, meta)
end

--- Load data from the database file.
-- @name LuaDatabase:load
function meta:load()
	local data, err = loadLuaData(self.filename, self.advanced)
	if not err then
		self.data = data
	end
	return err
end

--- Save data to the database file.
-- @name LuaDatabase:save
-- @param indent Indentation to use, if any.
function meta:save(indent)
	return saveLuaData(self.filename, self.data, self.advanced, indent)
end

