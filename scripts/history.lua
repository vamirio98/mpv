-- Record play history.

-- NOTE:
-- 1. Log will be saved as $HOME/.cache/mpv/history.txt.
-- 2. If the two mpv instance are open at once, only the history from the later
--    closed one will be saved.

local mp = require("mp")
local msg = require("mp.msg") -- Show information and debug.

--
-- To write history to log.
--
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

-- Read the history.
-- Create the file if not existed, note that the parent folder has to exist.
local function readHistory()
	local file = io.open(historyFilePath, "a+")
	if not file then
		msg.error("Can't open file " .. historyFilePath .. " to read")
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
end

-- Update the history.
local function updateHistory()
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
end

-- Write history into file.
local function recordHistory()
	local file = io.open(historyFilePath, "w")
	if not file then
		msg.error("Can't open " .. historyFilePath .. " to write.")
		return
	end

	for _, v in ipairs(history) do
		file:write(string.format("\n<%s> %s\n%s\n", v.time, v.title, v.path))
	end

	file:close()
end

--
-- To show history on screen.
--
package.path = package.path
	.. ";"
	.. mp.command_native({ "expand-path", "~~/scripts" })
	.. "/?.lua"

local kb = require("kb")
local osdPlaylist = require("osd_playlist")

local historyList = {} -- Used to show OSD list.
-- OSD history timeout on inactivity in seconds, use 0 for no timeout.
local displayTimeout = 5
local visible = false -- The history is visible or not.
local osdObj = osdPlaylist.new()
local showFunc = nil -- A forward define for function show().

local function onMoveUp()
	if #historyList == 0 then
		return
	end

	if osdObj.cursor > 1 then
		osdObj.cursor = osdObj.cursor - 1
	end

	showFunc()
end

local function onMoveDown()
	if #historyList == 0 then
		return
	end

	if osdObj.cursor < #historyList then
		osdObj.cursor = osdObj.cursor + 1
	end

	showFunc()
end

local function onMovePageUp()
	if #historyList == 0 or osdObj.cursor == 1 then
		return
	end

	osdObj.cursor = osdObj.cursor - osdObj.settings.showAmount
	if osdObj.cursor < 1 then
		osdObj.cursor = 1
	end

	showFunc()
end

local function onMovePageDown()
	if #historyList == 0 or osdObj.cursor == #historyList then
		return
	end

	osdObj.cursor = osdObj.cursor + osdObj.settings.showAmount
	if osdObj.cursor > #historyList then
		osdObj.cursor = #historyList
	end

	showFunc()
end

local function onMoveBegin()
	if #historyList == 0 or osdObj.cursor == 1 then
		return
	end

	osdObj.cursor = 1
	showFunc()
end

local function onMoveEnd()
	if #historyList == 0 or osdObj.cursor == #historyList then
		return
	end

	osdObj.cursor = #historyList

	showFunc()
end

local function addKeyBinds()
	kb.bindKeysForced(
		osdObj.settings.key.moveUp,
		"move-up",
		onMoveUp,
		"repeatable"
	)

	kb.bindKeysForced(
		osdObj.settings.key.moveDown,
		"move-down",
		onMoveDown,
		"repeatable"
	)

	kb.bindKeysForced(
		osdObj.settings.key.movePageUp,
		"move-page-up",
		onMovePageUp,
		"repeatable"
	)

	kb.bindKeysForced(
		osdObj.settings.key.movePageDown,
		"move-page-down",
		onMovePageDown,
		"repeatable"
	)

	kb.bindKeysForced(
		osdObj.settings.key.moveBegin,
		"move-begin",
		onMoveBegin,
		"repeatable"
	)

	kb.bindKeysForced(
		osdObj.settings.key.moveEnd,
		"move-end",
		onMoveEnd,
		"repeatable"
	)
end

local function removeKeyBinds()
	if osdObj.settings.dynamicBinding then
		kb.unbindKeys(osdObj.settings.key.moveUp, "move-up")
		kb.unbindKeys(osdObj.settings.key.moveDown, "move-down")
		kb.unbindKeys(osdObj.settings.key.movePageUp, "move-page-up")
		kb.unbindKeys(osdObj.settings.key.movePageDown, "move-page-down")
		kb.unbindKeys(osdObj.settings.key.moveBegin, "move-begin")
		kb.unbindKeys(osdObj.settings.key.moveEnd, "move-end")
	end
end

-- Update history list.
local function updateList()
	historyList = {} -- Clear.
	for i, file in ipairs(history) do
		historyList[i] = file.title
	end
end

local function show()
	updateList()
	if #history == 0 then
		return
	end

	osdObj.keyBindsTimer:kill()
	if not visible then
		addKeyBinds()
	end

	visible = true
	osdPlaylist.show(osdObj, historyList)

	osdObj.keyBindsTimer:resume()
end

local function hide()
	osdObj.keyBindsTimer:kill()
	osdPlaylist.hide()
	visible = false
	removeKeyBinds()
end

local function main()
	showFunc = show

	osdObj.cursor = 1
	osdObj.keyBindsTimer = mp.add_periodic_timer(displayTimeout, hide)

	readHistory()

	mp.register_event("file-loaded", updateHistory)
	--mp.register_event("end-file", function() end)
	mp.register_event("shutdown", recordHistory)

	kb.bindKeys("h", "show-history", show)
end

main()
