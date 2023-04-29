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
	hoveringDir = "{\\b0\\fs12\\c&H33FFFF&}[d] %entry",
	hoveringFile = "{\\b0\\fs12\\c&H33FFFF&}[f] %entry",
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
local files = {} -- All files and subdirectories in current directory.
local osd = OsdList:new()

local function sort(a, b)
	local x = utils.file_info(utils.join_path(path, a))
	local y = utils.file_info(utils.join_path(path, b))

	local res = true
	if (x.is_dir and y.is_dir) or (x.is_file and y.is_file) then
		res = a < b
	else
		res = x.is_dir
	end
	return res
end

local function onParentDir()
	if #files == 0 then
		return
	end

	local tmp = utils.split_path(path)
	-- Remove the last path separator.
	if
		#tmp > 1
		and (
			string.sub(tmp, #tmp, #tmp) == "\\"
			or string.sub(tmp, #tmp, #tmp) == "/"
		)
	then
		tmp = string.sub(tmp, 1, #tmp - 1)
	end
	VdirOpen(tmp)
end

local function onEnter()
	if #files == 0 then
		return
	end
	local fullPath = utils.join_path(path, files[osd.cursor])
	if utils.file_info(fullPath).is_dir then
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
	path = absPath:gsub("\\", "/") -- Use "/" as the path separator uniformly.
	files = utils.readdir(path)
	table.sort(files, sort)

	--osd.cursor = #files == 0 and 0 or 1 -- Reset.
	osd.title = path
	osd.content = files

	if not osd.visible then
		-- This key will be used to move to parent directory.
		kb.unbindKeys("-", "vidr-open-dir")
	end
	osd:show()
end

local function onVdirOpenDir()
	local dir = nil
	if mp.get_property_native("idle-active") then
		dir = utils.getcwd()
	else
		dir = utils.split_path(mp.get_property("path"))
		dir = dir:sub(1, #dir - 1)
	end
	VdirOpen(dir)
end

local function selectTemplate(o, pos)
	local fullPath = utils.join_path(path, o.content[pos])
	local template = nil
	if utils.file_info(fullPath).is_dir then
		msg.info(pos)
		template = pos == o.cursor and options.hoveringDir or options.dircetory
	else
		template = pos == o.cursor and options.hoveringFile or options.file
	end
	return template
end

local function beforeShow()
	if not osd.visible then
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
