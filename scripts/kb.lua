-- Key Binding module.

local kb = {}

local mp = require("mp")

function kb.bindKeys(keys, name, func, opts)
	if keys == nil or keys == "" then
		mp.add_key_binding(keys, name, func, opts)
		return
	end

	local i = 1
	for key in keys:gmatch("[^%s]+") do
		local prefix = (i == 1 and '' or i)
		mp.add_key_binding(key, name .. prefix, func, opts)
		i = i + 1
	end
end

function kb.bindKeysForced(keys, name, func, opts)
	if keys == nil or keys == "" then
		mp.add_forced_key_binding(keys, name, func, opts)
		return
	end

	local i = 1
	for key in keys:gmatch("[^%s]+") do
		local prefix = (i == 1 and '' or i)
		mp.add_forced_key_binding(key, name .. prefix, func, opts)
		i = i + 1
	end
end

function kb.unbindKeys(keys, name)
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

return kb
