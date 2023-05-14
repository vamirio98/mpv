-- Some basic tools.

local tools = {}

-- Deep copy.
function tools.clone(object)
	local lookupTable = {}
	local function _copy(obj)
		-- For simple type, it is already deep copy.
		if type(obj) ~= "table" then
			return obj
		-- For multiple value refer to a common object, return its reference.
		elseif lookupTable[obj] then
			return lookupTable[obj]
		end

		local newTable = {}
		for key, value in pairs(obj) do
			newTable[_copy(key)] = _copy(value)
		end

		return setmetatable(newTable, getmetatable(obj))
	end

	return _copy(object)
end

local mp = require("mp")

function tools.bindKeys(keys, name, func, opts)
	if keys == nil or keys == "" then
		mp.add_key_binding(keys, name, func, opts)
		return
	end

	local i = 1
	for key in keys:gmatch("[^%s]+") do
		local prefix = (i == 1 and "" or i)
		mp.add_key_binding(key, name .. prefix, func, opts)
		i = i + 1
	end
end

function tools.bindKeysForced(keys, name, func, opts)
	if keys == nil or keys == "" then
		mp.add_forced_key_binding(keys, name, func, opts)
		return
	end

	local i = 1
	for key in keys:gmatch("[^%s]+") do
		local prefix = (i == 1 and "" or i)
		mp.add_forced_key_binding(key, name .. prefix, func, opts)
		i = i + 1
	end
end

function tools.unbindKeys(keys, name)
	if keys == nil or keys == "" then
		mp.remove_key_binding(name)
		return
	end

	local i = 1
	for _ in keys:gmatch("[^%s]+") do
		local prefix = (i == 1 and "" or i)
		mp.remove_key_binding(name .. prefix)
		i = i + 1
	end
end

return tools
