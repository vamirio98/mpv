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
		"{\\c&H808080&}Enter:             {\\c&HFFFFFF&}play entry",
		"{\\c&H808080&}Backspace, Ctrl+d: {\\c&HFFFFFF&}remove entry",
	},

	-- OSD history timeout on inactivity in seconds, use 0 for no timeout.
	displayTimeout = 5,

	-- History list header template.
	-- %pos: cursor's position
	-- %listLen: length of the history list
	listHeader = "History [%pos/%listLen] (press ? for help)",

	-- List entry wrapper templates, used by mp.assdraw
	-- \\c&...& = color, BGR format
	-- %entry = list entry
	normal = "{\\b0\\fs12\\c&FFFFFF&}○  %entry",
	hovering = "{\\b0\\fs12\\c&33FFFF&}➔  %entry",
	selected = "{\\b0\\fs12\\c&FFFFFF&}➤  %entry",
	hoveringSelected = "{\\b0\\fs12\\c&33FFFF&}➤  %entry",
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

local OsdList = require("osd_list")
local kb = require("kb")

local osd = OsdList:new()

local function onEnter()
	mp.commandv("loadfile", history[osd.cursor].path, "replace")

	osd:hide()
end

local function onRemove()
	table.remove(history, osd.cursor)

	-- Update selection.
	if osd:selectedContains(osd.cursor) then
		osd:removeFromSelected(osd.cursor)
	end
	-- TODO: there is a strange bug that tmp.selected will contains elements
	-- in osd.selected since the second time this function is called, even I
	-- always create it through OsdList:new().
	local tmp = OsdList:new()
	for _, v in ipairs(osd:getSelected()) do
		tmp:addToSelected(v > osd.cursor and (v - 1) or v)
	end
	osd.selected = tmp.selected

	osd:show()
end

local function addKeyBinds()
	kb.bindKeysForced(options.keyEnter, "play-entry", onEnter)
	kb.bindKeysForced(options.keyRemove, "remove-entry", onRemove)
end

local function removeKeyBinds()
	kb.unbindKeys(options.keyEnter, "play-entry")
	kb.unbindKeys(options.keyRemove, "remove-entry")
end

-- Select a template according to the list index.
-- @obj: OSD list object
-- @index: list index of the current entry
local function selectTemplate(o, pos)
	local template = options.normal

	if o:selectedContains(pos) then
		template = pos == o.cursor and options.hoveringSelected
			or options.selected
	elseif pos == o.cursor then
		template = options.hovering
	end

	return template
end

-- Update OSD list.
local function updateList()
	osd.content = {} -- Clear.
	for i, file in ipairs(history) do
		osd.content[i] = file.title
	end
end

local function setShortcutKey()
	kb.bindKeysForced("h", "show-history", function()
		kb.unbindKeys("h", "show-history")
		osd:show()
	end)
end

local function beforeShow()
	local prevLen = #osd.content
	updateList()
	if #osd.content ~= prevLen then
		osd:recalculateShowRange()
	end

	if not osd.visible then
		addKeyBinds()
	end
end

local function afterHide()
	removeKeyBinds()

	setShortcutKey()
end

local function onFileLoaded()
	updateHistory()
end

local function main()
	osd.beforeShow = beforeShow
	osd.afterHide = afterHide

	osd.name = "history"
	osd.title = "History [%pos/%len]"
	osd.wrap = selectTemplate
	osd:addHelpMsg(options.helpMsg)
	osd.options.resetCursorOnOpen = true
	osd.options.resetSelectedOnOpen = true

	osd.options.showAmount = 10
	osd.options.assTag = osd.options.assTag:gsub("}", "\\fnIosevka}")

	readHistory()

	mp.register_event("file-loaded", onFileLoaded)
	mp.register_event("shutdown", recordHistory)

	setShortcutKey()
end

main()
