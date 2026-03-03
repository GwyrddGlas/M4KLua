local memfs = require("libs/memfs")
local utils = require("libs/utility")
local blocks = require("libs/blocks")
local texts = require("libs/textures")

local filesystem = memfs.new()

local directoryName = "m4kc"
local optionsFileName = "m4kc/m4kc.conf"
local worldsDirectoryName = "m4kc/worlds"
local screenshotsDirectoryName = "m4kc/screenshots"

local data = {}
data.worldList = {}
data.worldListLength = 0
data.filesystem = filesystem
data.directoryName = directoryName
data.optionsFileName = optionsFileName
data.worldsDirectoryName = worldsDirectoryName
data.screenshotsDirectoryName = screenshotsDirectoryName

function data.pathExists(path)
	return filesystem:get_inode(filesystem:resolve_path(path))
end

function data.fileExists(path)
	local file = data.pathExists(path)
	return file and not file.is_dir
end

function data.directoryExists(path)
	local dir = data.pathExists(path)
	return dir and dir.is_dir
end

function data.ensureDirectoryExists(path)
	local current = ""
	local dirs = utils.split(path, "/")

	for _, v in ipairs(dirs) do
		current = current .. v .. "/"

		if not data.directoryExists(current) then
			local success = filesystem:create_file(current, true)

			if not success then
				return true
			end
		end
	end

	return
end

function data.removeDirectory(path)
	filesystem:remove(path)
end

function data.init()
	local to_check = {directoryName, optionsFileName, worldsDirectoryName, screenshotsDirectoryName}

	for _, v in pairs(to_check) do
		assert(not data.ensureDirectoryExists(v), v .. ": No such file or directory")
	end
end

function data.getWorldPath(worldName)
	data.ensureDirectoryExists(worldsDirectoryName)
	return string.format("%s/%s", worldsDirectoryName, worldName)
end

function data.getWorldMetaPath(worldPath)
	return string.format("%s/metadata", worldPath)
end

function data.getWorldPlayerPath(worldPath, name)
	return string.format("%s/%s.player", worldPath, name)
end

function data.getScreenshotPath()
	return string.format("%s/snip_%s.bmp", screenshotsDirectoryName, os.date("%Y-%m-%d_%H-%M-%S"))
end

function data.refreshWorldList()
	for i in pairs(data.worldList) do
		data.worldList[i] = nil
	end

	data.worldListLength = 0

	if data.ensureDirectoryExists(worldsDirectoryName) then
		return true
	end

	for _, world in ipairs(filesystem:list_dir(worldsDirectoryName)) do
		local thumbnail = filesystem:read_file(string.format("%s/%s/thumbnail.bmp", worldsDirectoryName, world))

		if not thumbnail then
			thumbnail = {}

			for y = 0, 15 do
				for x = 0, 15 do
					utils.zinsert(thumbnail, texts.textures[
						x +
						y *
						texts.BLOCK_TEXTURE_W + (blocks.BLOCK_GRASS * 3 + 1) *
						texts.BLOCK_TEXTURE_W *
						texts.BLOCK_TEXTURE_H
					])
				end
			end
		end

		utils.zinsert(data.worldList, {
			name = world,
			thumbnail = thumbnail
		})
	end
end

-- // getSurfacePixel

return data