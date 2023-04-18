-- OSD playlist module.

local assdraw = require("mp.assdraw")
local mp = require("mp")
local msg = require("mp.msg")

local osd_playlist = {}

-- Default settings.
local SETTINGS = {
	-- To bind multiple keys separate them by a space.
	key = {
		moveUp = "UP k",
		moveDown = "DOWN j",
		movePageUp = "PGUP Ctrl+b",
		movePageDown = "PGDWN Ctrl+f",
		moveBegin = "HOME Ctrl+a",
		moveEnd = "END Ctrl+e",
		removeItem = "BS Ctrl+d",
		closePlaylist = "ESC",
	},

	-- The maximun amount of lines list will render.
	showAmount = 10,

	-- Font size scales by window, if false requires larger font and padding
	-- sizes.
	scaleByWindow = true,

	-- What to show when list is truncated.
	listSlicedPrefix = "▲",
	listSlicedSuffix = "▼",

	styleAssTag = "{\\rDefault\\an7\\fs12\\b0\\blur0\\bord1\\1c&H996F9A\\3c\\H000000\\q2}",

	-- List entry wrapper templates, used by mp.assdraw
	-- %item = list item
	wrapper = {
		normal = "{\\c&FFFFFF&}⚪  %item",
		hovering = "{\\c&33FFFF&}➔  %item",
		selected = "{\\c&FFFFFF&}⚫  %item",
		playing = "{\\c&FFFFFF&}▷ %item",
		hoveringSelected = "{\\c&FFFFFF&}➔  %item",
		playingHovering = "{\\c&33FFFF&}▷  %item",
		playingSelected = "{\\c&FFFFFF&}▶  %item",
		hoveringPlayingSelceted = "{\\c&C1C1FF}➔  %item",
	},

	-- When it is TRUE, all bindings will restore after closing the playlist.
	dynamicBinding = true,

	keybindsTimer = nil,
}

-- A playlist object.
local OBJ = {
	settings = SETTINGS,
	selection = {}, -- Selected items, a list of the index. This is a SET.
	cursor = 0, -- Cursor's position, 1-based.
	playing = 0, -- Index of the item being play, 1-based
}

-- Set operations.
function osd_playlist.addToSet(set, key)
	set[key] = true
end

function osd_playlist.removeFromSet(set, key)
	set[key] = nil
end

function osd_playlist.setContains(set, key)
	return set[key] ~= nil
end

-- Get new OSD playlist object.
function osd_playlist.new()
	local obj = OBJ
	obj.keyBindsTimer = mp.add_periodic_timer(1, msg.info(""))
	obj.keyBindsTimer:kill()
	return obj
end

-- Select a template according to the list index.
-- @obj: OSD playlist object
-- @index: list index of the current item
local function selectTemplate(obj, index)
	local template = obj.settings.wrapper.normal

	if osd_playlist.setContains(obj.selection, index) then
		if index == obj.playing then
			template = index == obj.cursor
					and obj.settings.wrapper.hoveringPlayingSelceted
				or obj.settings.wrapper.playingSelected
		else
			template = index == obj.cursor
					and obj.settings.wrapper.hoveringSelected
				or obj.settings.wrapper.selected
		end
	else
		if index == obj.playing then
			template = index == obj.cursor
					and obj.settings.wrapper.playingHovering
				or obj.settings.wrapper.playing
		elseif index == obj.cursor then
			template = obj.settings.wrapper.hovering
		end
	end

	return template
end

local function warpItem(template, item)
	return template:gsub("%%item", item)
end

-- Show the list.
-- @obj: OSD playlist object
-- @list: list [array]
function osd_playlist.show(obj, list)
	local ass = assdraw.ass_new()

	local listLen = #list
	local _, _, aspectRatio = mp.get_osd_size()
	local h = 360
	local w = aspectRatio * h

	ass:append(obj.settings.styleAssTag)

	-- (visible index, list index) pairs of list entries that should be rendered.
	local visibleIndices = {}

	table.insert(visibleIndices, obj.cursor)

	local offset = 1
	local visibleIndicesLen = 1
	while
		visibleIndicesLen < obj.settings.showAmount
		and visibleIndicesLen < listLen
	do
		-- Add entry for offset steps below the cursor.
		local below = obj.cursor + offset
		if below <= listLen then
			table.insert(visibleIndices, below)
			visibleIndicesLen = visibleIndicesLen + 1
		end

		-- Add entry for offset steps above the cursor.
		local above = obj.cursor - offset
		if
			above >= 1
			and visibleIndicesLen < obj.settings.showAmount
			and visibleIndicesLen < listLen
		then
			table.insert(visibleIndices, 1, above)
			visibleIndicesLen = visibleIndicesLen + 1
		end

		offset = offset + 1
	end

	for displayIndex, listIndex in ipairs(visibleIndices) do
		if displayIndex == 1 and listIndex ~= 1 then
			ass:append(obj.settings.listSlicedPrefix .. "\\N")
		elseif
			displayIndex == obj.settings.showAmount and listIndex ~= listLen
		then
			ass:append(obj.settings.listSlicedSuffix)
		else
			ass:append(
				warpItem(
					selectTemplate(obj, listIndex),
					listIndex .. "   " .. list[listIndex] .. "\\N"
				)
			)
		end
	end

	if obj.settings.scaleByWindow then
		w, h = 0, 0
	end
	mp.set_osd_ass(w, h, ass.text)
end

-- Hide the playlist.
function osd_playlist.hide()
	mp.set_osd_ass(0, 0, "")
end

return osd_playlist
