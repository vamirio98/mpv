-- Record play history.

-- How to use.
-- Save this file in your mpv scripts dir. Log will be saved as
-- $HOME/.cache/mpv/history.txt

local historyFilePath = (os.getenv("userprofile") or os.getenv("HOME"))
	.. "/.cache/mpv/history.txt"

local historyStr -- The history string.

local function openHistory(filePath)
	-- Read the existed record.
	local file = io.open(filePath, "a+") --[[ Create the file if not existed,
	                                          note that the parent folder has to
											  exist. ]]

	historyStr = file:read("a")
	file:close()

	-- Open file to write.
	file = io.open(filePath, "w")
	return file
end

local historyFile = openHistory(historyFilePath)

mp.register_event("file-loaded", function()
	historyStr = historyStr .. string.format("<%s> ", os.date("%Y/%m/%d %X"))
	historyStr = historyStr .. string.format("%s\n", mp.get_property("path"))
end)

mp.register_event("end-file", function()
end)

mp.register_event("shutdown", function()
	historyFile:write(historyStr)
	historyFile:close()
end)
