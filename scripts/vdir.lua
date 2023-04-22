-- Operate directory in Vim way.

local mp = require("mp")
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

function VdirOpen(absPath)
	path = absPath
	files = utils.readdir(path)
	table.sort(files, sort)

	osdList.show(osdObj, files)
end

local function onVdirOpenDir()
	VdirOpen(utils.getcwd())
end

local function main()
	kb.bindKeysForced("-", "vdir-open-dir", onVdirOpenDir)
end

main()
