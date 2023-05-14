-- OSD list module.

-- Default options.
local _options = {
	-- The maximum amount of lines list will render.
	showAmount = 15,

	-- Ass tags, see https://aegisub.org for more help.
	assTag = "{\\rDefault\\an7\\b0\\bord0\\blur0\\fs12\\1c&HFFFFFF&\\q2}",
	titleAssTag = "{\\b1\\fs16\\1c&HB414B8&}",
	entryAssTag = "{\\b0\\fs12\\1c&HFFFFFF&}",

	-- Font size scales by window, if false requires larger font and padding
	-- sizes.
	-- NOTE: this option is now unusable, list always scale by window.
	scaleByWindow = true,

	-- Whether to reset cursor to the first entry when opening the list.
	resetCursorOnOpen = false,

	-- Whether to reset selected to empty when opening the list.
	resetSelectedOnOpen = false,

	-- Keys, separate multiple keys by a space.
	keyUp = "UP k",
	keyDown = "DOWN j",
	keyPgUp = "PGUP Ctrl+b",
	keyPgDn = "PGDWN Ctrl+f",
	keyBegin = "HOME Ctrl+a",
	keyEnd = "END Ctrl+e",
	keySelect = "RIGHT l",
	keyQuit = "ESC",
	keyHelp = "?",

	helpMsg = {
		"{\\c&H808080&}Up, k:        {\\c&HFFFFFF&}move to previous entry",
		"{\\c&H808080&}Down, j:      {\\c&HFFFFFF&}move to next entry",
		"{\\c&H808080&}PgUp, Ctrl+b: {\\c&HFFFFFF&}move to previous page",
		"{\\c&H808080&}PgDn, Ctrl+f: {\\c&HFFFFFF&}move to next page",
		"{\\c&H808080&}Home, Ctrl+a: {\\c&HFFFFFF&}move to beginning",
		"{\\c&H808080&}End, Ctrl+e:  {\\c&HFFFFFF&}move to end",
		"{\\c&H808080&}Right, l:     {\\c&HFFFFFF&}select/unselect entry",
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
	content = {},
	-- Function used to wrap the entry, it accepts TWO arguments:
	-- o: the OsdList object
	-- pos: the position of current entry, 1-based
	wrap = nil,

	visible = false, -- Whether the list is visible.

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

-- Get selected entrys' 1-based position, the result is a ordered array.
function OsdList:getSelected()
	local res = {}

	for k, _ in pairs(self.selected) do
		table.insert(res, k)
	end
	table.sort(res)

	return res
end

local math = require("math")

local assdraw = require("mp.assdraw")
local mp = require("mp")
local msg = require("mp.msg")

package.path = package.path
	.. ";"
	.. mp.command_native({ "expand-path", "~~/scripts" })
	.. "/?.lua"

local tools = require("tools")

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
	local res = s
	if s:find("%%pos") ~= nil then
		res = res:gsub("%%pos", string.format("%0" .. len .. "d", pos))
	end
	if s:find("%len") ~= nil then
		res = res:gsub("%%len", #o.content)
	end
	if s:find("%entry") ~= nil then
		res = res:gsub("%%entry", o.content[pos])
	end
	return res
end

-- Check if the OsdList object's first and last menber is out of border.
local function checkUpperBound(o)
	if o.first < 1 then
		o.first = 1
	end
end

local function checkLowerBound(o)
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
		checkUpperBound(self)
		self.last = self.first + self.options.showAmount - 1
		checkLowerBound(self)
	end

	self.cursor = self.cursor - 1
end

function OsdList:onDown()
	if #self.content == 0 or self.cursor == #self.content then
		return
	end

	if self.cursor == self.last then
		self.last = self.last + 1
		checkLowerBound(self)
		self.first = self.last - self.options.showAmount + 1
		checkUpperBound(self)
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
		checkUpperBound(self)
		-- Try to show as many entries as posible.
		self.last = self.first + self.options.showAmount - 1
		checkLowerBound(self)
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
		checkLowerBound(self)
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
		checkLowerBound(self)
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
		checkUpperBound(self)
	end
end

-- Toggle select.
function OsdList:onSelect()
	if not self:selectedContains(self.cursor) then
		self:addToSelected(self.cursor)
	else
		self:removeFromSelected(self.cursor)
	end
end

-- Remove all key binds.
local function removeKeyBinds(o)
	tools.unbindKeys(o.options.keyUp, o.name .. "-up")
	tools.unbindKeys(o.options.keyDown, o.name .. "-down")
	tools.unbindKeys(o.options.keyPgUp, o.name .. "-pgup")
	tools.unbindKeys(o.options.keyPgDn, o.name .. "-pgdn")
	tools.unbindKeys(o.options.keyBegin, o.name .. "-begin")
	tools.unbindKeys(o.options.keyEnd, o.name .. "-end")
	tools.unbindKeys(o.options.keySelect, o.name .. "-select")
	tools.unbindKeys(o.options.keyQuit, o.name .. "-quit")
	tools.unbindKeys(o.options.keyHelp, o.name .. "-help")
end

-- Add all key binds.
local function addKeyBinds(o)
	tools.bindKeysForced(o.options.keyUp, o.name .. "-up", function()
		o:onUp()
		o:show()
	end, "repeatable")

	tools.bindKeysForced(o.options.keyDown, o.name .. "-down", function()
		o:onDown()
		o:show()
	end, "repeatable")

	tools.bindKeysForced(o.options.keyPgUp, o.name .. "-pgup", function()
		o:onPgUp()
		o:show()
	end, "repeatable")

	tools.bindKeysForced(o.options.keyPgDn, o.name .. "-pgdn", function()
		o:onPgDn()
		o:show()
	end, "repeatable")

	tools.bindKeysForced(o.options.keyBegin, o.name .. "-begin", function()
		o:onBegin()
		o:show()
	end)

	tools.bindKeysForced(o.options.keyEnd, o.name .. "-end", function()
		o:onEnd()
		o:show()
	end)

	tools.bindKeysForced(o.options.keySelect, o.name .. "-select", function()
		o:onSelect()
		o:show()
	end)

	tools.bindKeysForced(o.options.keyQuit, o.name .. "-quit", function()
		o:hide()
		removeKeyBinds(o)
	end)

	tools.bindKeysForced(o.options.keyHelp, o.name .. "-help", function()
		o:hide()
		removeKeyBinds(o)

		local help = OsdList:new()
		help.name = o.name .. "-help"
		help.title = "Help (press j, k to navigate and <ESC> to quit)"
		help.content = tools.clone(o.options.helpMsg)
		help.options.helpMsg = nil

		help:show()

		tools.bindKeysForced(help.options.keyUp, help.name .. "-up", function()
			help:onPgUp()
			help:show()
		end)

		tools.bindKeysForced(
			help.options.keyDown,
			help.name .. "-down",
			function()
				help:onPgDn()
				help:show()
			end
		)

		tools.bindKeysForced(
			help.options.keyQuit,
			help.name .. "-quit",
			function()
				help:hide()

				tools.unbindKeys(help.options.keyUp, help.name .. "-up")
				tools.unbindKeys(help.options.keyDown, help.name .. "-down")
				tools.unbindKeys(help.options.keyQuit, help.name .. "-quit")

				addKeyBinds(o)

				-- Record the reset options, then set them to false to avoid to
				-- reset the object.
				local resetCursorOnOpen = o.options.resetCursorOnOpen
				local resetSelectedOnOpen = o.options.resetSelectedOnOpen
				o.options.resetCursorOnOpen = false
				o.options.resetSelectedOnOpen = false

				o:show()

				-- Restore the object's reset options.
				o.options.resetCursorOnOpen = resetCursorOnOpen
				o.options.resetSelectedOnOpen = resetSelectedOnOpen
			end
		)
	end)
end

-- Show the list.
function OsdList:show()
	if self.beforeShow then
		self.beforeShow()
	end

	if #self.content == 0 then
		self.content[1] = "(Empty)"
	end

	local ass = assdraw.ass_new()

	local _, _, aspectRatio = mp.get_osd_size()
	local h = 360
	local w = aspectRatio * h

	ass:append(self.options.assTag)

	if not self.visible then
		-- If the cursor position is assign by caller, do NOT change it.
		if self.cursor == 0 or self.options.resetCursorOnOpen then
			self.cursor = 1
		end
		if self.options.resetSelectedOnOpen then
			self.selected = {}
		end
		self.first = self.cursor - math.floor(self.options.showAmount / 2)
		checkUpperBound(self)
		self.last = self.first + self.options.showAmount - 1
		checkLowerBound(self)
	end

	ass:append(
		self.options.titleAssTag
			.. format(self.title, self, self.cursor)
			.. (self.options.helpMsg and " (press ? for help)" or "")
			.. "\\N"
	)

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

-- Recalculate the show range.
-- NOTE: this function will try to keep the cursor on the original line.
function OsdList:recalculateShowRange()
	checkLowerBound(self)
	if self.cursor > self.last then
		self.cursor = self.last
	end
	if self.first > self.last then
		self.first = self.last - self.options.showAmount
		checkUpperBound(self)
	end
end

-- Locate the cursor to the specified entry, return the result if found, and 0
-- if not.
function OsdList:locate(entry)
	local pos = 0
	for i, v in ipairs(self.content) do
		if entry == v then
			pos = i
		end
	end

	return pos
end

return OsdList
