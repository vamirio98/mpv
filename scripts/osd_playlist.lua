-- OSD playlist module.

local osd_playlist = {}

-- Default settings.
local DEFAULT_SETTIINGS = {
	-- To bind multiple keys separate them by a space.
	key = {
		actionUp = "UP k",
		actionDown = "DOWN j",
		actionPageUp = "PGUP Ctrl+b",
		actionPageDown = "PGDWN Ctrl+f",
		actionBegin = "HOME gg",
		actionEnd = "END G",
		actionRemove = "BS dd",
		actionClose = "ESC",
	},

	-- OSD timeout on inactivity in seconds, use 0 for no timeout.
	displayTimeout = 3,

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
		normal = "{\\c&FFFFFF&}□ %item",
		hovering = "{\\c&33FFFF&}➔ %item",
		selected = "{\\c&FFFFFF&}■ %item",
		playing = "{\\c&FFFFFF&}▷ %item",
		hoveringSelected = "{\\c&FFFFFF&}➔ %item",
		playingHovering = "{\\c&33FFFF&}▷ %item",
		playingSelected = "{\\c&FFFFFF&}▶ %item",
		hoveringPlayingSelceted = "{\\c&C1C1FF}➔ %item",
	},
}

local DEFAULT_CURSOR_STATUS = {
	selection = {}, -- Selected items, a list of the index. This is a SET.
	pos = 0, -- Cursor's position, 1-based.
	playing = 0, -- Index of the item being play, 1-based
}

function osd_playlist.addToSet(set, key)
	set[key] = true
end

function osd_playlist.removeFromSet(set, key)
	set[key] = nil
end

function osd_playlist.setContains(set, key)
	return set[key] ~= nil
end

local assdraw = require("mp.assdraw")
local mp = require("mp")
local msg = require("mp.msg")
local utils = require("mp.utils")

-- Get new settings.
function osd_playlist.newSettings()
	return DEFAULT_SETTIINGS
end

-- Get new cursor status object.
function osd_playlist.newCursorStatus()
	return DEFAULT_CURSOR_STATUS
end

-- Select a template according to the list index.
-- @cursor: CursorStatus object
-- @index: list index of the current item
-- @settings: provide the templates
local function selectTemplate(cursor, index, settings)
	if not settings then
		settings = DEFAULT_SETTIINGS
	end

	local template = settings.wrapper.normal

	if osd_playlist.setContains(cursor.selection, index) then
		if index == cursor.playing then
			template = index == cursor.pos
					and settings.wrapper.hoveringPlayingSelceted
				or settings.wrapper.playingSelected
		else
			template = index == cursor.pos and settings.wrapper.hoveringSelected
				or settings.wrapper.selected
		end
	else
		if index == cursor.playing then
			template = index == cursor.pos and settings.wrapper.playingHovering
				or settings.wrapper.playing
		elseif index == cursor.pos then
			template = settings.wrapper.hovering
		end
	end

	return template
end

local function warpItem(template, item)
	return template:gsub("%%item", item)
end

-- Draw the list.
-- @list: list [array]
-- @cursor: CursorStatus object
-- @settings: list settings
function osd_playlist.draw(list, cursor, settings)
	if not settings then
		settings = DEFAULT_SETTIINGS
	end

	local ass = assdraw.ass_new()

	local listLen = #list
	local _, _, aspectRatio = mp.get_osd_size()
	local h = 360
	local w = aspectRatio * h

	ass:append(settings.styleAssTag)

	-- (visible index, list index) pairs of list entries that should be rendered.
	local visibleIndices = {}

	table.insert(visibleIndices, cursor.pos)

	local offset = 1
	local visibleIndicesLen = 1
	while
		visibleIndicesLen < settings.showAmount
		and visibleIndicesLen < listLen
	do
		-- Add entry for offset steps below the cursor.
		local below = cursor.pos + offset
		if below <= listLen then
			table.insert(visibleIndices, below)
			visibleIndicesLen = visibleIndicesLen + 1
		end

		-- Add entry for offset steps above the cursor.
		local above = cursor.pos - offset
		if
			above >= 1
			and visibleIndicesLen < settings.showAmount
			and visibleIndicesLen < listLen
		then
			table.insert(visibleIndices, 1, above)
			visibleIndicesLen = visibleIndicesLen + 1
		end

		offset = offset + 1
	end

	for displayIndex, listIndex in ipairs(visibleIndices) do
		if displayIndex == 1 and listIndex ~= 1 then
			ass:append(settings.listSlicedPrefix .. "\\N")
		elseif displayIndex == settings.showAmount and listIndex ~= listLen then
			ass:append(settings.listSlicedSuffix)
		else
			ass:append(
				warpItem(
					selectTemplate(cursor, listIndex, settings),
					listIndex .. " " .. list[listIndex] .. "\\N"
				)
			)
		end
	end

	if settings.scaleByWindow then
		w, h = 0, 0
	end
	mp.set_osd_ass(w, h, ass.text)
end

return osd_playlist
