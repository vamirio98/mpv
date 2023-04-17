-- OSD List module.

local osd_list = {}

-- Default settings.
osd_list.DEFAULT_SETTIINGS = {
	-- To bind multiple keys separate them by a space.
	key = {
		moveUp = "UP k",
		moveDown = "DOWN j",
		movePageUp = "PGUP Ctrl+b",
		movePageDown = "PGDWN Ctrl+f",
		moveBegin = "HOME gg",
		moveEnd = "END G",
	},

	-- OSD timeout on inactivity in seconds, use 0 for no timeout.
	displayTimeout = 3,

	-- The maximun amount of lines list will render.
	showAmount = 10,

	-- What to show when list is truncated.
	listSlicedPrefix = "▲",
	listSlicedSuffix = "▼",

	styleAssTag = "{\\rDefault\\an7\\fs12\\b0\\blur0\\bord1\\1c&H996F9A\\3c\\H000000\\q2}",
}

local assdraw = require("mp.assdraw")
local mp = require("mp")
local msg = require("mp.msg")
local utils = require("mp.utils")

-- Draw the list.
-- @list: list [array]
-- @cursor: 1-based cursor index of the list
-- @settings: list settings
function osd_list.draw(list, cursor, settings)
	if not settings then
		settings = osd_list.DEFAULT_SETTIINGS
	end

	local ass = assdraw.ass_new()

	local listLen = #list
	local _, _, aspectRatio = mp.get_osd_size()
	local h = 360
	local w = aspectRatio * h

	ass:append(settings.styleAssTag)

	-- (visible index, list index) pairs of list entries that should be rendered.
	local visibleIndices = {}

	table.insert(visibleIndices, cursor)

	local offset = 1
	local visibleIndicesLen = 1
	while
		visibleIndicesLen < settings.showAmount
		and visibleIndicesLen < listLen
	do
		-- Add entry for offset steps below the cursor.
		local below = cursor + offset
		if below <= listLen then
			table.insert(visibleIndices, below)
			visibleIndicesLen = visibleIndicesLen + 1
		end

		-- Add entry for offset steps above the cursor.
		local above = cursor - offset
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

	for displayIndex, listIndex in pairs(visibleIndices) do
		if displayIndex == 1 and listIndex ~= 1 then
			ass:append(settings.listSlicedPrefix .. "\\N")
		elseif displayIndex == settings.showAmount and listIndex ~= listLen then
			ass:append(settings.listSlicedSuffix)
		else
			ass:append(displayIndex .. " " .. list[listIndex] .. "\\N")
		end
	end

	mp.set_osd_ass(w, h, ass.text)
end

return osd_list
