-- Operate directory in Vim way.

local options = {
	keyUp = "UP k",
	keyDown = "DOWN j",
	keyPgUp = "PGUP Ctrl+b",
	keyPgDn = "PGDWN Ctrl+f",
	keyBegin = "HOME Ctrl+a",
	keyEnd = "END Ctrl+e",
	keyQuit = "ESC",
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
	local x = utils.file_info(path .. "/" .. a)
	local y = utils.file_info(path .. "/" .. b)

	local res = true
	if (x.is_dir and y.is_dir) or (x.is_file and y.is_file) then
		res = a < b
	else
		res = x.is_file
	end
	return res
end

local function onUp()
	if #files ~= 0 and osdObj.cursor > 1 then
		osdObj.cursor = osdObj.cursor - 1
	end
	msg.info("hello")

	show()
end

local function onDown()
	if #files ~= 0 and osdObj.cursor < #files then
		osdObj.cursor = osdObj.cursor + 1
	end

	msg.info("world")

	show()
end

local function onPgUp()
	if #files ~= 0 then
		osdObj.cursor = osdObj.cursor - osdObj.settings.showAmount
		if osdObj.cursor < 1 then
			osdObj.cursor = 1
		end
	end

	show()
end

local function onPgDn()
	if #files ~= 0 then
		osdObj.cursor = osdObj.cursor + osdObj.settings.showAmount
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
	kb.bindKeysForced(options.keyUp, "up", onUp, "repeatable")
	kb.bindKeysForced(options.keyDown, "down", onDown, "repeatable")
	kb.bindKeysForced(options.keyPgUp, "page-up", onPgUp, "repeatable")
	kb.bindKeysForced(options.keyPgDn, "page-down", onPgDn, "repeatable")
	kb.bindKeysForced(options.keyBegin, "begin", onBegin, "repeatable")
	kb.bindKeysForced(options.keyEnd, "end", onEnd, "repeatable")
	kb.bindKeysForced(options.keyQuit, "quit", onQuit)
end

local function removeKeyBinds()
	kb.unbindKeys(options.keyUp, "up")
	kb.unbindKeys(options.keyDown, "down")
	kb.unbindKeys(options.keyPgUp, "page-up")
	kb.unbindKeys(options.keyPgDn, "page-down")
	kb.unbindKeys(options.keyBegin, "begin")
	kb.unbindKeys(options.keyEnd, "end")
	kb.unbindKeys(options.keyQuit, "quit")
end

local function doShow()
	local list = { "Empty" }
	if #files ~= 0 then
		list = files
	end
	osdList.show(osdObj, list, path)
	if not visible then
		addKeyBinds()
		visible = true
	end
end

local function doHide()
	removeKeyBinds()
	osdList.hide()
	visible = false
end

function VdirOpen(absPath)
	path = absPath
	files = utils.readdir(path)
	table.sort(files, sort)

	if visible then -- Hide previous list but do NOT remove key binds.
		osdObj.cursor = 0 -- Reset.
		osdList.hide()
	end
	show()
end

local function onVdirOpenDir()
	VdirOpen(utils.getcwd())
end

local function main()
	show = doShow
	hide = doHide

	kb.bindKeysForced("-", "vdir-open-dir", onVdirOpenDir)
end

main()
