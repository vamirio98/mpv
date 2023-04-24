-- Record play history.

-- NOTE:
-- 1. Log will be saved as $HOME/.cache/mpv/history.txt.
-- 2. If the two mpv instance are open at once, only the history from the later
--    closed one will be saved.

local options = {
	cap = 30, -- The capacity of the history.

	-- To bind multiple key separate them by a space.
	keyUp = "UP k",
	keyDown = "DOWN j",
	keyPgUp = "PGUP Ctrl+b",
	keyPgDn = "PGDWN Ctrl+f",
	keybegin = "HOME Ctrl+a",
	keyEnd = "END Ctrl+e",
	keyEnter = "ENTER",
	keySelect = "RIGHT l",
	keyUnselect = "LEFT h",
	keyRemove = "BS Ctrl+d",
	keyQuit = "ESC",
	keyHelp = "?",

	helpMsg = {
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
	},

	-- When it is TRUE, all bindings will restore after closing the list.
	dynamicBinding = true,

	-- OSD history timeout on inactivity in seconds, use 0 for no timeout.
	displayTimeout = 5,

	-- History list header template.
	-- %pos: cursor's position
	-- %listLen: length of the history list
	listHeader = "History [%pos/%listLen] (press ? for help)",

	-- List entry wrapper templates, used by mp.assdraw
	-- \\c&...& = color, BGR format
	-- %entry = list entry
	normal = "{\\c&FFFFFF&}○  %entry",
	hovering = "{\\c&33FFFF&}➔  %entry",
	selected = "{\\c&FFFFFF&}➤  %entry",
	playing = "{\\c&FFFFFF&}▷  %entry",
	hoveringSelected = "{\\c&33FFFF&}➤  %entry",
	playingHovering = "{\\c&33FFFF&}▷  %entry",
	playingSelected = "{\\c&FFFFFF&}▶  %entry",
	hoveringPlayingSelceted = "{\\c&33FFFF}▶  %entry",
}

local mp = require("mp")
local msg = require("mp.msg") -- Show information and debug.

--
-- To write history to log.
--
local history = {} -- Use to record history, 1 -> end <=> newest -> oldest.
local historyFilePath = mp.command_native({ "expand-path", "~/" })
	.. "/.cache/mpv/history.txt"

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
	-- Use "/" as the path separator uniformly.
	local videoPath = mp.get_property("path"):gsub("\\", "/")

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
		if #history < options.cap then
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
local visible = false -- The history is visible or not.
local osdObj = osdList.new()
local keyBindsTimer = nil
local playing = 0 -- Current playing entry position, 1-based.
local show = nil -- The forward define for function show().
local hide = nil -- The forward define for function hide().

local function onUp()
	if #historyList == 0 then
		return
	end

	if osdObj.cursor > 1 then
		osdObj.cursor = osdObj.cursor - 1
	end

	show()
end

local function onDown()
	if #historyList == 0 then
		return
	end

	if osdObj.cursor < #historyList then
		osdObj.cursor = osdObj.cursor + 1
	end

	show()
end

local function onPgUp()
	if #historyList == 0 or osdObj.cursor == 1 then
		return
	end

	osdObj.cursor = osdObj.cursor - osdObj.options.showAmount
	if osdObj.cursor < 1 then
		osdObj.cursor = 1
	end

	show()
end

local function onPgDn()
	if #historyList == 0 or osdObj.cursor == #historyList then
		return
	end

	osdObj.cursor = osdObj.cursor + osdObj.options.showAmount
	if osdObj.cursor > #historyList then
		osdObj.cursor = #historyList
	end

	show()
end

local function onBegin()
	if #historyList == 0 or osdObj.cursor == 1 then
		return
	end

	osdObj.cursor = 1
	show()
end

local function onEnd()
	if #historyList == 0 or osdObj.cursor == #historyList then
		return
	end

	osdObj.cursor = #historyList

	show()
end

local function onEnter()
	mp.commandv("loadfile", history[osdObj.cursor].path, "replace")

	hide()
end

local function onSelect()
	osdList.addToSet(osdObj.selection, osdObj.cursor)

	show()
end

local function onUnselect()
	osdList.removeFromSet(osdObj.selection, osdObj.cursor)

	show()
end

local function onRemove()
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

	show()
end

local function onHelp()
	hide()

	-- Record cursor position in history list and set it to 1 before show the
	-- help.
	local cursorPos = osdObj.cursor
	osdObj.cursor = 1

	local showHelp = function()
		osdList.show(
			osdObj,
			options.helpMsg,
			"Help (press j, k to navigate and <ESC> to quit)",
			function(_, index)
				return "{\\c&808080&}"
					.. options.helpMsg[index]:gsub(":", "{\\c&FFFFFF&}")
			end
		)
	end

	showHelp()

	-- Set key binds.
	kb.bindKeysForced("k", "move-page-up", function()
		osdObj.cursor = osdObj.cursor - osdObj.options.showAmount
		if osdObj.cursor < 1 then
			osdObj.cursor = 1
		end
		showHelp()
	end, "repeatable")

	kb.bindKeysForced("j", "move-page-down", function()
		osdObj.cursor = osdObj.cursor + osdObj.options.showAmount
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
		show()
	end)
end

local function addKeyBinds()
	kb.bindKeysForced(options.keyUp, "move-up", onUp, "repeatable")
	kb.bindKeysForced(options.keyDown, "move-down", onDown, "repeatable")
	kb.bindKeysForced(options.keyPgUp, "move-page-up", onPgUp, "repeatable")
	kb.bindKeysForced(options.keyPgDn, "move-page-down", onPgDn, "repeatable")
	kb.bindKeysForced(options.keybegin, "move-begin", onBegin, "repeatable")
	kb.bindKeysForced(options.keyEnd, "move-end", onEnd, "repeatable")
	kb.bindKeysForced(options.keyEnter, "play-entry", onEnter, "repeatable")
	kb.bindKeysForced(options.keySelect, "select-entry", onSelect, "repeatable")
	kb.bindKeysForced(
		options.keyUnselect,
		"unselect-entry",
		onUnselect,
		"repeatable"
	)
	kb.bindKeysForced(options.keyRemove, "remove-entry", onRemove, "repeatable")
	kb.bindKeysForced(options.keyQuit, "close-list", hide)
	kb.bindKeysForced(options.keyHelp, "show-help", onHelp)
end

local function removeKeyBinds()
	if options.dynamicBinding then
		kb.unbindKeys(options.keyUp, "move-up")
		kb.unbindKeys(options.keyDown, "move-down")
		kb.unbindKeys(options.keyPgUp, "move-page-up")
		kb.unbindKeys(options.keyPgDn, "move-page-down")
		kb.unbindKeys(options.keybegin, "move-begin")
		kb.unbindKeys(options.keyEnd, "move-end")
		kb.unbindKeys(options.keyEnter, "play-entry")
		kb.unbindKeys(options.keySelect, "select-entry")
		kb.unbindKeys(options.keyUnselect, "unselect-entry")
		kb.unbindKeys(options.keyRemove, "remove-entry")
		kb.unbindKeys(options.keyQuit, "close-list")
		kb.unbindKeys(options.keyHelp, "show-help")
	end
end

local function wrapHeader(header)
	local len = tostring(#historyList):len()
	return header
		:gsub("%%pos", string.format("%0" .. len .. "d", osdObj.cursor))
		:gsub("%%listLen", #historyList)
end

-- Select a template according to the list index.
-- @obj: OSD list object
-- @index: list index of the current entry
local function selectTemplate(index)
	local template = options.normal

	if osdList.setContains(osdObj.selection, index) then
		if index == playing then
			template = index == osdObj.cursor
					and options.hoveringPlayingSelceted
				or options.playingSelected
		else
			template = index == osdObj.cursor and options.hoveringSelected
				or options.selected
		end
	else
		if index == playing then
			template = index == osdObj.cursor and options.playingHovering
				or options.playing
		elseif index == osdObj.cursor then
			template = options.hovering
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

local function doShow()
	updateList()
	if #history == 0 then
		return
	end

	keyBindsTimer:kill()
	if not visible then
		addKeyBinds()
	end

	visible = true
	osdList.show(osdObj, historyList, wrapHeader(options.listHeader), wrapEntry)

	keyBindsTimer:resume()
end

local function doHide()
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
	show = doShow
	hide = doHide

	osdObj.cursor = 1
	osdObj.options.styleAssTag =
		"{\\rDefault\\an7\\fnIosevka\\fs12\\b0\\blur0\\bord1\\1c&H996F9A\\3c\\H000000\\q2}"
	keyBindsTimer = mp.add_periodic_timer(options.displayTimeout, hide)
	keyBindsTimer:kill()

	readHistory()

	mp.register_event("file-loaded", onFileLoaded)
	mp.register_event("shutdown", recordHistory)

	kb.bindKeys("h", "show-history", show)
end

main()
