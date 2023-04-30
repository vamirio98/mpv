-- Operate directory in Vim way.

local options = {
	-- Keys.
	keyParentDir = "-",
	keyEnter = "ENTER i", -- Enter directory or open file.
	keyUp = "UP k",
	keyDown = "DOWN j",
	keyPgUp = "PGUP Ctrl+b",
	keyPgDn = "PGDWN Ctrl+f",
	keyBegin = "HOME Ctrl+a",
	keyEnd = "END Ctrl+e",
	keyQuit = "ESC",

	-- Entry templates.
	dircetory = "{\\b0\\fs12\\c&HFFFF00&}[d] %entry",
	file = "{\\b0\\fs12\\c&HFFFFFF&}[f] %entry",
	unknown = "{\\b0\\fs12\\c&H808080&}[u] %entry",
	hoveringDir = "{\\b0\\fs12\\c&H33FFFF&}[d] %entry",
	hoveringFile = "{\\b0\\fs12\\c&H33FFFF&}[f] %entry",
	hoveringUnknown = "{\\b0\\fs12\\c&H33FFFF&}[u] %entry",
}

local mp = require("mp")
local msg = require("mp.msg")
local utils = require("mp.utils")

package.path = package.path
	.. ";"
	.. mp.command_native({ "expand-path", "~~/scripts" })
	.. "/?.lua"

local OsdList = require("osd_list")
local kb = require("kb")

local path = nil -- Current directory path.
local osd = OsdList:new()

local function sort(a, b)
	local x = utils.file_info(utils.join_path(path, a))
	local y = utils.file_info(utils.join_path(path, b))

	-- Put unknown items last.
	if not x then
		return false
	end
	if not y then
		return true
	end

	local res = true
	if (x.is_dir and y.is_dir) or (x.is_file and y.is_file) then
		res = a < b
	else
		res = x.is_dir
	end
	return res
end

local function onParentDir()
	VdirOpen(utils.split_path(path))
end

local function onEnter()
	local fullPath = utils.join_path(path, osd.content[osd.cursor])
	local info = utils.file_info(fullPath)
	if not info then
		msg.error("Can not read file " .. fullPath)
		return
	end

	if info.is_dir then
		VdirOpen(fullPath)
	else
		mp.commandv("loadfile", fullPath, "replace")
	end
end

local function addKeyBinds()
	kb.bindKeysForced(options.keyParentDir, "parent-dir", onParentDir)
	kb.bindKeysForced(options.keyEnter, "enter", onEnter)
end

local function removeKeyBinds()
	kb.unbindKeys(options.keyParentDir, "parent-dir")
	kb.unbindKeys(options.keyEnter, "enter")
end

function VdirOpen(absPath)
	-- Force OsdList to re-calculate the show range and reset cursor.
	osd:hide()

	local tmp = absPath:gsub("\\", "/") -- Use "/" as the path separator uniformly.

	-- utils.readdir() will read the part after the last separator.
	-- e.g. a/b/c -> read c; a/b/c/ -> read nothing.
	-- Remove the last path separator.
	if
		(
			(#tmp > 3 and string.sub(tmp, 2, 2) == ":") -- For Windows.
			or #tmp > 1 -- For Linux.
		) and string.sub(tmp, #tmp, #tmp) == "/"
	then
		tmp = string.sub(tmp, 1, #tmp - 1)
	end

	-- utils.readdir() can't read C: but can C:/ , really strange.
	if #tmp == 2 and string.sub(tmp, 2, 2) == ":" then
		tmp = tmp .. "/"
	end

	path = tmp
	osd.content = utils.readdir(path)

	if not osd.content then
		msg.error("Can not read file " .. path)
		return
	end

	table.sort(osd.content, sort)

	osd.title = path

	osd:show()
end

local function onVdirOpenDir()
	local dir = nil
	if mp.get_property_native("idle-active") then
		dir = utils.getcwd()
	else
		dir = utils.split_path(mp.get_property("path"))
	end
	VdirOpen(dir)
end

local function selectTemplate(o, pos)
	local fullPath = utils.join_path(path, o.content[pos])
	local template = nil
	local info = utils.file_info(fullPath)

	if not info then
		template = pos == o.cursor and options.hoveringUnknown
			or options.unknown
	elseif info.is_dir then
		template = pos == o.cursor and options.hoveringDir or options.dircetory
	else
		template = pos == o.cursor and options.hoveringFile or options.file
	end

	return template
end

local function beforeShow()
	if not osd.visible then
		-- This key will be used to move to parent directory.
		kb.unbindKeys("-", "vidr-open-dir")
		addKeyBinds()
	end
end

local function afterHide()
	removeKeyBinds()

	-- Rebind key to open directory list.
	kb.bindKeysForced("-", "vdir-open-dir", onVdirOpenDir)
end

local function main()
	osd.beforeShow = beforeShow
	osd.afterHide = afterHide

	osd.name = "vdir"
	osd.title = path
	osd.wrap = selectTemplate

	osd.options.assTag = osd.options.assTag:gsub("}", "\\fnIosevka}")

	osd.options.resetCursorOnOpen = true

	kb.bindKeysForced("-", "vdir-open-dir", onVdirOpenDir)
end

main()
