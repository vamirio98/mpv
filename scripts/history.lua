-- Record play history.

-- NOTE:
-- 1. Log will be saved as $HOME/.cache/mpv/history.txt.
-- 2. If the two mpv instance are open at once, only the history from the later
--    closed one will be saved.

local mp = require("mp")
local msg = require("mp.msg") -- Show information and debug.

package.path = package.path
	.. ";"
	.. mp.command_native({ "expand-path", "~~/scripts" })
	.. "/?.lua"

local kb = require("kb")
local osdPlaylist = require("osd_playlist")

local history = {} -- Use to record history, 1 -> end <=> newest -> oldest.
local historyFilePath = mp.command_native({ "expand-path", "~/" })
	.. "/.cache/mpv/history.txt"
local cap = 30 -- The capacity of the history.

-- Wrap the last N elements in the table T with length L(only the array part).
local function wrap(t, n, l)
	if not l then
		l = #t
	end

	for _ = 1, n do
		table.insert(t, 1, table.remove(t, l))
	end
end

-- Create the file if not existed, note that the parent folder has to exist.
local file = io.open(historyFilePath, "a+")
if not file then
	msg.error("Can't open file " .. historyFilePath .. " to read", 3)
	return
end
-- Read all history.
local getLine = file:lines("l")
while getLine() do
	local line = getLine()
	history[#history + 1] =
		{ time = string.sub(line, 2, 20), title = string.sub(line, 23) }
	line = getLine()
	history[#history].path = line
end
file:close()

mp.register_event("file-loaded", function()
	local inHistory = false
	local playTime = os.date("%Y/%m/%d %X")
	local videoTitle = mp.get_property("filename")
	local videoPath = mp.get_property("path")

	for i, v in ipairs(history) do
		-- This video has been play before, update the play time.
		if v.path == videoPath then
			inHistory = true
			v.time = playTime
			wrap(history, 1, i) -- Update order.
			break
		end
	end

	-- Add a new record.
	if not inHistory then
		-- Ensure the items no more than the capacity.
		local offset = 0
		if #history < cap then
			offset = 1
		end

		history[#history + offset] = {
			time = playTime,
			title = videoTitle,
			path = videoPath,
		}
		wrap(history, 1)
	end
end)

--mp.register_event("end-file", function() end)

mp.register_event("shutdown", function()
	file = io.open(historyFilePath, "w")
	if not file then
		msg.error("Can't open " .. historyFilePath .. " to write.", 3)
		return
	end

	for _, v in ipairs(history) do
		file:write(string.format("\n<%s> %s\n%s\n", v.time, v.title, v.path))
	end

	file:close()
end)

function ShowHistory(duration)
	if not duration then
		duration = 3
	end

	local list = {}
	for _, f in ipairs(history) do
		table.insert(list, f.title)
	end
	local osdList = osdPlaylist.new()
	osdList.cursor = 1
	osdPlaylist.draw(osdList, list)
end

kb.bindKeys("h", "show_history", ShowHistory)
