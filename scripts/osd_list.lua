-- OSD list module.

local assdraw = require("mp.assdraw")
local mp = require("mp")
local msg = require("mp.msg")

local osd_list = {}

-- Default settings.
local SETTINGS = {
	-- The maximun amount of lines list will render.
	showAmount = 10,

	-- Font size scales by window, if false requires larger font and padding
	-- sizes.
	scaleByWindow = true,

	-- What to show when list is truncated.
	-- \\c&...& = color, BGR format
	listSlicedPrefix = "{\\c&FACE87&}▲",
	listSlicedSuffix = "{\\c&FACE87&}▼",

	styleAssTag = "{\\rDefault\\an7\\fs12\\b0\\blur0\\bord1\\1c&H996F9A\\3c\\H000000\\q2}",
}

-- A list object.
local OBJ = {
	settings = SETTINGS,
	selection = {}, -- Selected entries, a list of the index. This is a SET.
	cursor = 0, -- Cursor's position, 1-based.
}

-- Set operations.
function osd_list.addToSet(set, key)
	set[key] = true
end

function osd_list.removeFromSet(set, key)
	set[key] = nil
end

function osd_list.setContains(set, key)
	return set[key] ~= nil
end

-- Get new OSD list object.
function osd_list.new()
	return OBJ
end

-- Show the list.
-- @obj: OSD list object
-- @list: list [array]
-- @header: list header
-- @wrap: function used to wrap entry, it accepts TWO arguments:
--        DISPLAY_INDEX: rank in display section of current entry
--        LIST_INDEX: rank in the list of current entry
function osd_list.show(obj, list, header, wrap)
	local ass = assdraw.ass_new()

	local listLen = #list
	local _, _, aspectRatio = mp.get_osd_size()
	local h = 360
	local w = aspectRatio * h

	ass:append(obj.settings.styleAssTag)

	if header then
		ass:append(header .. "\\N")
	end

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
				(wrap and wrap(displayIndex, listIndex) or list[listIndex])
					.. "\\N"
			)
		end
	end

	if obj.settings.scaleByWindow then
		w, h = 0, 0
	end
	mp.set_osd_ass(w, h, ass.text)
end

-- Hide the list.
function osd_list.hide()
	mp.set_osd_ass(0, 0, "")
end

return osd_list
