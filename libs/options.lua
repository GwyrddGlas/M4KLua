local data = require("libs/data")

local Options = {}

local options = {}
options.username = "guest"

function options.init()
	Options = {
		fov = 90,
		fogType = 0,
		trapMouse = 0,
		lookSpeed = 40,
		drawDistance = 5,

		username = {
			len = 8,
			cursor = 5,
			buffer = options.username
		}
	}

	options.options = Options
end

function options.load()
	local path = data.getOptionsFileName()
	local file = data.filesystem:read_file(path)

	if true then -- // not file then
		return
	end

	options.options = Options
	-- // TODO: add m4kc.conf support
end

function options.save()
	local path = data.optionsFileName
	local file = data.filesystem:read_file(path)

	if not file then
		data.filesystem:create_file(path)
	end

	data.filesystem:write_file(
		path, string.format(
			"%i\nfogType %i\ndrawDistance %i\ntrapMouse %i\nfov %f\nusername %s\n",
			0, Options.fogType, Options.drawDistance, Options.trapMouse, Options.fov, Options.username.buffer
		)
	)
end

return options