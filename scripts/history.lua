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
		-- Ensure the entries no more than the capacity.
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
local osdList = require("osd_list")

local historyList = {} -- Used to show OSD list.
-- OSD history timeout on inactivity in seconds, use 0 for no timeout.
local displayTimeout = 5
local visible = false -- The history is visible or not.
local osdObj = osdList.new()
local keyBindsTimer = nil
-- History list header template.
-- %pos: cursor's position
-- %listLen: length of the history list
local listHeader = "History [%pos/%listLen] (press ? for help)"
-- To bind multiple key separate them by a space.
local keys = {
	moveUp = "UP k",
	moveDown = "DOWN j",
	movePageUp = "PGUP Ctrl+b",
	movePageDown = "PGDWN Ctrl+f",
	moveBegin = "HOME Ctrl+a",
	moveEnd = "END Ctrl+e",
	playEntry = "ENTER",
	selectEntry = "RIGHT l",
	unselectEntry = "LEFT h",
	removeEntry = "BS Ctrl+d",
	closeList = "ESC",
	showHelp = "?",
}

local helpMsg = {
	"Up, k: move to previous entry",
	"Down, j: move to next entry",
	"PgUp, Ctrl+b: move to previous page",
	"PgDn, Ctrl+f: move to next page",
	"Home, Ctrl+a: move to beginning",
	"End, Ctrl+e: move to end",
	"Enter: play entry",
	"Right, l: select entry",
	"Left, h: unselect entry",
	"Backspace, Ctrl+d: remove entry",
	"Esc: close the list",
	"?: show help",
}

-- When it is TRUE, all bindings will restore after closing the list.
local dynamicBinding = true
local playing = 0 -- Current playing entry position, 1-based.
local showFunc = nil -- The forward define for function show().
local hideFunc = nil -- The forward define for function hide().

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

local function onPlayEntry()
	mp.commandv("loadfile", history[osdObj.cursor].path, "replace")

	showFunc()
end

local function onSelectEntry()
	osdList.addToSet(osdObj.selection, osdObj.cursor)

	showFunc()
end

local function onUnselectEntry()
	osdList.removeFromSet(osdObj.selection, osdObj.cursor)

	showFunc()
end

local function onRemoveEntry()
	table.remove(history, osdObj.cursor)

	-- Update selection.
	if osdList.setContains(osdObj.selection, osdObj.cursor) then
		osdList.removeFromSet(osdObj.selection, osdObj.cursor)
	end
	local tmp = {}
	for k, _ in pairs(osdObj.selection) do
		if k > osdObj.cursor then
			osdList.addToSet(tmp, k - 1)
		else
			osdList.addToSet(tmp, k)
		end
	end
	osdObj.selection = tmp

	showFunc()
end

local function onShowHelp()
	hideFunc()

	-- Record cursor position in history list and set it to 1 before show the
	-- help.
	local cursorPos = osdObj.cursor
	osdObj.cursor = 1

	local showHelp = function()
		osdList.show(
			osdObj,
			helpMsg,
			"Help (press j, k to navigate and <ESC> to quit)",
			function(_, index)
				return "{\\c&808080&}"
					.. helpMsg[index]:gsub(":", "{\\c&FFFFFF&}")
			end
		)
	end

	showHelp()

	-- Set key binds.
	kb.bindKeysForced("k", "move-page-up", function()
		osdObj.cursor = osdObj.cursor - osdObj.settings.showAmount
		if osdObj.cursor < 1 then
			osdObj.cursor = 1
		end
		showHelp()
	end, "repeatable")

	kb.bindKeysForced("j", "move-page-down", function()
		osdObj.cursor = osdObj.cursor + osdObj.settings.showAmount
		if osdObj.cursor > #historyList then
			osdObj.cursor = #historyList
		end
		showHelp()
	end, "repeatable")

	kb.bindKeysForced("ESC", "close-help", function()
		kb.unbindKeys("k", "move-page-up")
		kb.unbindKeys("j", "move-page-down")
		kb.unbindKeys("ESC", "close-help")

		osdList.hide()

		-- Restore cursor position in history list.
		osdObj.cursor = cursorPos
		showFunc()
	end)
end

local function addKeyBinds()
	kb.bindKeysForced(keys.moveUp, "move-up", onMoveUp, "repeatable")
	kb.bindKeysForced(keys.moveDown, "move-down", onMoveDown, "repeatable")
	kb.bindKeysForced(
		keys.movePageUp,
		"move-page-up",
		onMovePageUp,
		"repeatable"
	)
	kb.bindKeysForced(
		keys.movePageDown,
		"move-page-down",
		onMovePageDown,
		"repeatable"
	)
	kb.bindKeysForced(keys.moveBegin, "move-begin", onMoveBegin, "repeatable")
	kb.bindKeysForced(keys.moveEnd, "move-end", onMoveEnd, "repeatable")
	kb.bindKeysForced(keys.playEntry, "play-entry", onPlayEntry, "repeatable")
	kb.bindKeysForced(
		keys.selectEntry,
		"select-entry",
		onSelectEntry,
		"repeatable"
	)
	kb.bindKeysForced(
		keys.unselectEntry,
		"unselect-entry",
		onUnselectEntry,
		"repeatable"
	)
	kb.bindKeysForced(
		keys.removeEntry,
		"remove-entry",
		onRemoveEntry,
		"repeatable"
	)
	kb.bindKeysForced(keys.closeList, "close-list", hideFunc)
	kb.bindKeysForced(keys.showHelp, "show-help", onShowHelp)
end

local function removeKeyBinds()
	if dynamicBinding then
		kb.unbindKeys(keys.moveUp, "move-up")
		kb.unbindKeys(keys.moveDown, "move-down")
		kb.unbindKeys(keys.movePageUp, "move-page-up")
		kb.unbindKeys(keys.movePageDown, "move-page-down")
		kb.unbindKeys(keys.moveBegin, "move-begin")
		kb.unbindKeys(keys.moveEnd, "move-end")
		kb.unbindKeys(keys.playEntry, "play-entry")
		kb.unbindKeys(keys.selectEntry, "select-entry")
		kb.unbindKeys(keys.unselectEntry, "unselect-entry")
		kb.unbindKeys(keys.removeEntry, "remove-entry")
		kb.unbindKeys(keys.closeList, "close-list")
		kb.unbindKeys(keys.showHelp, "show-help")
	end
end

local function wrapHeader(header)
	local len = tostring(#historyList):len()
	return header
		:gsub("%%pos", string.format("%0" .. len .. "d", osdObj.cursor))
		:gsub("%%listLen", #historyList)
end

-- List entry wrapper templates, used by mp.assdraw
-- \\c&...& = color, BGR format
-- %entry = list entry
local entryTemplates = {
	normal = "{\\c&FFFFFF&}○  %entry",
	hovering = "{\\c&33FFFF&}➔  %entry",
	selected = "{\\c&FFFFFF&}➤  %entry",
	playing = "{\\c&FFFFFF&}▷  %entry",
	hoveringSelected = "{\\c&33FFFF&}➤  %entry",
	playingHovering = "{\\c&33FFFF&}▷  %entry",
	playingSelected = "{\\c&FFFFFF&}▶  %entry",
	hoveringPlayingSelceted = "{\\c&33FFFF}▶  %entry",
}

-- Select a template according to the list index.
-- @obj: OSD list object
-- @index: list index of the current entry
local function selectTemplate(index)
	local template = entryTemplates.normal

	if osdList.setContains(osdObj.selection, index) then
		if index == playing then
			template = index == osdObj.cursor
					and entryTemplates.hoveringPlayingSelceted
				or entryTemplates.playingSelected
		else
			template = index == osdObj.cursor
					and entryTemplates.hoveringSelected
				or entryTemplates.selected
		end
	else
		if index == playing then
			template = index == osdObj.cursor and entryTemplates.playingHovering
				or entryTemplates.playing
		elseif index == osdObj.cursor then
			template = entryTemplates.hovering
		end
	end

	return template
end

local function wrapEntry(_, index)
	return selectTemplate(index):gsub("%%entry", historyList[index])
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

	keyBindsTimer:kill()
	if not visible then
		addKeyBinds()
	end

	visible = true
	osdList.show(osdObj, historyList, wrapHeader(listHeader), wrapEntry)

	keyBindsTimer:resume()
end

local function hide()
	keyBindsTimer:kill()
	osdList.hide()
	visible = false
	removeKeyBinds()
end

local function onFileLoaded()
	updateHistory()

	if visible then -- Update the OSD list.
		show()
	end
end

local function main()
	showFunc = show
	hideFunc = hide

	osdObj.cursor = 1
	osdObj.settings.styleAssTag =
		"{\\rDefault\\an7\\fnIosevka\\fs12\\b0\\blur0\\bord1\\1c&H996F9A\\3c\\H000000\\q2}"
	keyBindsTimer = mp.add_periodic_timer(displayTimeout, hide)
	keyBindsTimer:kill()

	readHistory()

	mp.register_event("file-loaded", onFileLoaded)
	mp.register_event("shutdown", recordHistory)

	kb.bindKeys("h", "show-history", show)
end

main()
