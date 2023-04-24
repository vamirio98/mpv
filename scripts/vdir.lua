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
	dircetory = "{\\c&HFFFF00&}[d] ",
	file = "{\\c&HFFFFFF&}[f] ",
	hoveringDir = "{\\c&H33FFFF&}[d] ",
	hoveringFile = "{\\c&H33FFFF&}[f] ",
}

local mp = require("mp")
local msg = require("mp.msg")
local utils = require("mp.utils")

package.path = package.path
	.. ";"
	.. mp.command_native({ "expand-path", "~~/scripts" })
	.. "/?.lua"

local kb = require("kb")
local osdList = require("osd_list")

local path = nil -- Current directory path.
local files = {} -- All files and subdirectories in current directory.
local osdObj = osdList.new()
local visible = false -- If the directory list visible or not.
local show = nil
local hide = nil

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
	local fullPath = utils.join_path(path, files[osdObj.cursor])
	if utils.file_info(fullPath).is_dir then
		VdirOpen(fullPath)
	else
		mp.commandv("loadfile", fullPath, "replace")
	end
end

local function onUp()
	if #files ~= 0 and osdObj.cursor > 1 then
		osdObj.cursor = osdObj.cursor - 1
	end

	show()
end

local function onDown()
	if #files ~= 0 and osdObj.cursor < #files then
		osdObj.cursor = osdObj.cursor + 1
	end

	show()
end

local function onPgUp()
	if #files ~= 0 then
		osdObj.cursor = osdObj.cursor - osdObj.options.showAmount
		if osdObj.cursor < 1 then
			osdObj.cursor = 1
		end
	end

	show()
end

local function onPgDn()
	if #files ~= 0 then
		osdObj.cursor = osdObj.cursor + osdObj.options.showAmount
		if osdObj.cursor > #files then
			osdObj.cursor = #files
		end
	end

	show()
end

local function onBegin()
	if #files ~= 0 then
		osdObj.cursor = 1
	end

	show()
end

local function onEnd()
	if #files ~= 0 then
		osdObj.cursor = #files
	end

	show()
end

local function onQuit()
	hide()
end

local function addKeyBinds()
	kb.bindKeysForced(
		options.keyParentDir,
		"parent-dir",
		onParentDir,
		"repeatable"
	)
	kb.bindKeysForced(options.keyEnter, "enter", onEnter, "repeatable")
	kb.bindKeysForced(options.keyUp, "up", onUp, "repeatable")
	kb.bindKeysForced(options.keyDown, "down", onDown, "repeatable")
	kb.bindKeysForced(options.keyPgUp, "page-up", onPgUp, "repeatable")
	kb.bindKeysForced(options.keyPgDn, "page-down", onPgDn, "repeatable")
	kb.bindKeysForced(options.keyBegin, "begin", onBegin, "repeatable")
	kb.bindKeysForced(options.keyEnd, "end", onEnd, "repeatable")
	kb.bindKeysForced(options.keyQuit, "quit", onQuit)
end

local function removeKeyBinds()
	kb.unbindKeys(options.keyParentDir, "parent-dir")
	kb.unbindKeys(options.keyEnter, "enter")
	kb.unbindKeys(options.keyUp, "up")
	kb.unbindKeys(options.keyDown, "down")
	kb.unbindKeys(options.keyPgUp, "page-up")
	kb.unbindKeys(options.keyPgDn, "page-down")
	kb.unbindKeys(options.keyBegin, "begin")
	kb.unbindKeys(options.keyEnd, "end")
	kb.unbindKeys(options.keyQuit, "quit")
end

function VdirOpen(absPath)
	path = absPath:gsub("\\", "/") -- Use "/" as the path separator uniformly.
	files = utils.readdir(path)
	table.sort(files, sort)

	osdObj.cursor = #files == 0 and 0 or 1 -- Reset.

	if visible then -- Hide previous list but do NOT remove key binds.
		osdList.hide()
	else
		-- This key will be used to move to parent directory.
		kb.unbindKeys("-", "vidr-open-dir")
	end
	show()
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

local function wrapEntry(_, index)
	local fullPath = utils.join_path(path, files[index])
	local template = nil
	if utils.file_info(fullPath).is_dir then
		template = index == osdObj.cursor and options.hoveringDir
			or options.dircetory
	else
		template = index == osdObj.cursor and options.hoveringFile
			or options.file
	end
	return template .. files[index]
end

local function doShow()
	local list = { "Empty" }
	if #files ~= 0 then
		list = files
	end
	osdList.show(osdObj, list, path, wrapEntry)
	if not visible then
		addKeyBinds()
		visible = true
	end
end

local function doHide()
	removeKeyBinds()
	osdList.hide()
	visible = false

	-- Rebind key to open directory list.
	kb.bindKeysForced("-", "vdir-open-dir", onVdirOpenDir)
end

local function main()
	show = doShow
	hide = doHide

	osdObj.options.styleAssTag =
		"{\\rDefault\\an7\\fnIosevka\\fs12\\b0\\blur0\\bord1\\1c&H996F9A\\3c\\H000000\\q2}"

	kb.bindKeysForced("-", "vdir-open-dir", onVdirOpenDir)
end

main()
