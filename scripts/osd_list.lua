-- OSD list module.

-- Default options.
local _options = {
	-- The maximum amount of lines list will render.
	showAmount = 15,

	-- Truncate a long line or not.
	truncateLongLine = true,

	-- The maximum length of a line.
	maxLineLen = 80,

	-- What to show when a line is truncated.
	truncatedSuffix = "@@@",

	-- Ass tags, see https://aegisub.org for more help.
	assTag = "{\\rDefault\\an7\\b0\\bord0\\blur0\\fs12\\1c&HFFFFFF&\\q2}",
	titleAssTag = "{\\b1\\fs16\\1c&HB414B8&}",
	entryAssTag = "{\\b0\\fs12\\1c&HFFFFFF&}",

	-- Font size scales by window, if false requires larger font and padding
	-- sizes.
	-- NOTE: this option is now unusable, list always scale by window.
	scaleByWindow = true,

	-- Keys, separate multiple keys by a space.
	keyUp = "UP k",
	keyDown = "DOWN j",
	keyPgUp = "PGUP Ctrl+b",
	keyPgDn = "PGDWN Ctrl+f",
	keyBegin = "HOME Ctrl+a",
	keyEnd = "END Ctrl+e",
	keySelect = "RIGHT l",
	keyUnselect = "LEFT h",
	keyQuit = "ESC",
	keyHelp = "?",

	helpMsg = {
		"{\\c&H808080&}Up, k:        {\\c&HFFFFFF&}move to previous entry",
		"{\\c&H808080&}Down, j:      {\\c&HFFFFFF&}move to next entry",
		"{\\c&H808080&}PgUp, Ctrl+b: {\\c&HFFFFFF&}move to previous page",
		"{\\c&H808080&}PgDn, Ctrl+f: {\\c&HFFFFFF&}move to next page",
		"{\\c&H808080&}Home, Ctrl+a: {\\c&HFFFFFF&}move to beginning",
		"{\\c&H808080&}End, Ctrl+e:  {\\c&HFFFFFF&}move to end",
		"{\\c&H808080&}Right, l:     {\\c&HFFFFFF&}select entry",
		"{\\c&H808080&}Left, h:      {\\c&HFFFFFF&}unselect entry",
		"{\\c&H808080&}Esc:          {\\c&HFFFFFF&}close the list",
		"{\\c&H808080&}?:            {\\c&HFFFFFF&}show help",
	},
}

local OsdList = {
	-- Functions called before/after show()/hide().
	beforeShow = nil,
	afterShow = nil,
	beforeHide = nil,
	afterHide = nil,

	cursor = 0,

	-- Index of the first and last entry will be rendered.
	first = 0,
	last = 0,

	selected = {}, -- Selected entries, a SET of the index.

	name = "",
	title = "",
	content = nil,
	-- Function used to wrap the entry, it accepts TWO arguments:
	-- o: the OsdList object
	-- pos: the position of current entry, 1-based
	wrap = nil,

	firstShow = true, -- Whether to show for the first time.

	visible = false, -- Whether the list is visible.

	-- Whether to reset cursor to the first entry when opening the list.
	resetCursorOnOpen = false,

	-- Whether to reset selected to empty when opening the list.
	resetSelectedOnOpen = false,

	options = _options,
}

function OsdList:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function OsdList:addToSelected(key)
	self.selected[key] = true
end

function OsdList:removeFromSelected(key)
	self.selected[key] = nil
end

function OsdList:selectedContains(key)
	return self.selected[key] ~= nil
end

local math = require("math")

local assdraw = require("mp.assdraw")
local mp = require("mp")
local msg = require("mp.msg")

package.path = package.path
	.. ";"
	.. mp.command_native({ "expand-path", "~~/scripts" })
	.. "/?.lua"

local kb = require("kb")

-- Format string.
-- @o: the OsdList object
-- @s: the format string
-- @pos: the position of current entry
-- Escape placeholder:
--     %pos: position of current entry, in other word, the @pos
--     %len: length of the list
--     %entry: the current entry
local function format(s, o, pos)
	local len = tostring(#o.content):len()
	return s:gsub("%%pos", string.format("%0" .. len .. "d", pos))
		:gsub("%%len", #o.content)
		:gsub("%%entry", o.content[pos])
end

-- Check if the OsdList object's first and last menber is out of border
local function checkBorder(o)
	if o.first < 1 then
		o.first = 1
	end
	if o.last > #o.content then
		o.last = #o.content
	end
end

function OsdList:onUp()
	if #self.content == 0 or self.cursor == 1 then
		return
	end

	if self.cursor == self.first then
		self.first = self.first - 1
		self.last = self.first + self.options.showAmount - 1
		checkBorder(self)
	end

	self.cursor = self.cursor - 1
end

function OsdList:onDown()
	if #self.content == 0 or self.cursor == #self.content then
		return
	end

	if self.cursor == self.last then
		self.last = self.last + 1
		self.first = self.last - self.options.showAmount + 1
		checkBorder(self)
	end

	self.cursor = self.cursor + 1
end

function OsdList:onPgUp()
	if #self.content == 0 or self.cursor == 1 then
		return
	end

	if self.first == 1 then
		self.cursor = 1
	else
		self.cursor = self.first + 1
		self.last = self.cursor
		self.first = self.last - self.options.showAmount + 1
		checkBorder(self)
	end
end

function OsdList:onPgDn()
	if #self.content == 0 or self.cursor == #self.content then
		return
	end

	if self.last == #self.content then
		self.cursor = self.last
	else
		self.cursor = self.last - 1
		self.first = self.cursor
		self.last = self.first + self.options.showAmount - 1
		checkBorder(self)
	end
end

function OsdList:onBegin()
	if #self.content == 0 or self.cursor == 1 then
		return
	end

	self.cursor = 1
	if self.first ~= 1 then
		self.first = 1
		self.last = self.options.showAmount
		checkBorder(self)
	end
end

function OsdList:onEnd()
	if #self.content == 0 or self.cursor == #self.content then
		return
	end

	self.cursor = #self.content
	if self.last ~= #self.content then
		self.last = #self.content
		self.first = self.last - self.options.showAmount + 1
		checkBorder(self)
	end
end

function OsdList:onSelect()
	self:addToSelected(self.cursor)
end

function OsdList:onUnselect()
	self:removeFromSelected(self.cursor)
end

-- Remove all key binds.
local function removeKeyBinds(o)
	kb.unbindKeys(o.options.keyUp, o.name .. "-up")
	kb.unbindKeys(o.options.keyDown, o.name .. "-down")
	kb.unbindKeys(o.options.keyPgUp, o.name .. "-pgup")
	kb.unbindKeys(o.options.keyPgDn, o.name .. "-pgdn")
	kb.unbindKeys(o.options.keyBegin, o.name .. "-begin")
	kb.unbindKeys(o.options.keyEnd, o.name .. "-end")
	kb.unbindKeys(o.options.keySelect, o.name .. "-select")
	kb.unbindKeys(o.options.keyUnselect, o.name .. "-unselect")
	kb.unbindKeys(o.options.keyQuit, o.name .. "-quit")
	kb.unbindKeys(o.options.keyHelp, o.name .. "-help")
end

-- Add all key binds.
local function addKeyBinds(o)
	kb.bindKeysForced(o.options.keyUp, o.name .. "-up", function()
		o:onUp()
		o:show()
	end, "repeatable")

	kb.bindKeysForced(o.options.keyDown, o.name .. "-down", function()
		o:onDown()
		o:show()
	end, "repeatable")

	kb.bindKeysForced(o.options.keyPgUp, o.name .. "-pgup", function()
		o:onPgUp()
		o:show()
	end, "repeatable")

	kb.bindKeysForced(o.options.keyPgDn, o.name .. "-pgdn", function()
		o:onPgDn()
		o:show()
	end, "repeatable")

	kb.bindKeysForced(o.options.keyBegin, o.name .. "-begin", function()
		o:onBegin()
		o:show()
	end)

	kb.bindKeysForced(o.options.keyEnd, o.name .. "-end", function()
		o:onEnd()
		o:show()
	end)

	kb.bindKeysForced(o.options.keySelect, o.name .. "-select", function()
		o:onSelect()
		o:show()
	end)

	kb.bindKeysForced(o.options.keyUnselect, o.name .. "-unselect", function()
		o:onUnselect()
		o:show()
	end)

	kb.bindKeysForced(o.options.keyQuit, o.name .. "-quit", function()
		o:hide()
		removeKeyBinds(o)
	end)

	kb.bindKeysForced(o.options.keyHelp, o.name .. "-help", function()
		o:hide()
		removeKeyBinds(o)

		local help = OsdList:new()
		help.name = o.name .. "-help"
		help.title = "Help (press j, k to navigate and <ESC> to quit)"
		help.content = o.options.helpMsg
		help.options.helpMsg = nil

		help:show()

		kb.bindKeysForced(help.options.keyUp, help.name .. "-up", function()
			help:onPgUp()
			help:show()
		end)

		kb.bindKeysForced(help.options.keyDown, help.name .. "-down", function()
			help:onPgDn()
			help:show()
		end)

		kb.bindKeysForced(help.options.keyQuit, help.name .. "-quit", function()
			help:hide()

			kb.unbindKeys(help.options.keyUp, help.name .. "-up")
			kb.unbindKeys(help.options.keyDown, help.name .. "-down")
			kb.unbindKeys(help.options.keyQuit, help.name .. "-quit")

			o:show()
		end)
	end)
end

-- Show the list.
function OsdList:show()
	if self.beforeShow then
		self.beforeShow()
	end

	if not self.content or #self.content == 0 then
		self.content[1] = "(Empty)"
	end

	local ass = assdraw.ass_new()

	local _, _, aspectRatio = mp.get_osd_size()
	local h = 360
	local w = aspectRatio * h

	ass:append(self.options.assTag)

	if self.firstShow then
		-- If the cursor position is assign by caller, do NOT change it.
		if self.cursor == 0 then
			self.cursor = 1
		end
	else
		if not self.visible then
			if self.resetCursorOnOpen then
				self.cursor = 1
			end
			if self.resetSelectedOnOpen then
				self.selected = {}
			end
		end
	end

	ass:append(
		self.options.titleAssTag
			.. format(self.title, self, self.cursor)
			.. (self.options.helpMsg and " (press ? for help)" or "")
			.. "\\N"
	)

	if self.firstShow or self.options.resetCursorOnOpen then
		self.first = self.cursor - math.floor(self.options.showAmount / 2)
		if self.first < 1 then
			self.first = 1
		end
		self.last = self.first + self.options.showAmount - 1
		checkBorder(self)
	end

	if self.content[1] == "(Empty)" then
		ass:append(self.options.entryAssTag .. self.content[1])
	else
		for pos = self.first, self.last do
			ass:append(
				format(
					(
						self.wrap and self.wrap(self, pos)
						or (self.options.entryAssTag .. "%entry")
					),
					self,
					pos
				) .. "\\N"
			)
		end
	end

	if self.options.scaleByWindow then
		w, h = 0, 0
	end
	mp.set_osd_ass(w, h, ass.text)

	if self.firstShow then
		self.firstShow = false
	end

	if not self.visible then
		addKeyBinds(self)
		self.visible = true
	end

	if self.afterShow then
		self.afterShow()
	end
end

-- Hide the list.
function OsdList:hide()
	if self.beforeHide then
		self.beforeHide()
	end

	mp.set_osd_ass(0, 0, "")

	self.visible = false

	if self.afterHide then
		self.afterHide()
	end
end

-- Add help message.
-- Note: @message must be an ARRAY
function OsdList:addHelpMsg(message)
	for _, v in ipairs(message) do
		table.insert(self.options.helpMsg, v)
	end
end

return OsdList
