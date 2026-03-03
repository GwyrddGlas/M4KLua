local line_cache = {}

local function zero_index(tbl)
	local ntbl = {}

	for i = 0, #(tbl) - 1 do
		ntbl[i] = tbl[i + 1]
	end

	return ntbl
end

-- // perlin 2d hash

local hash = {
208, 34, 231, 213, 32, 248, 233, 56, 161, 78, 24, 140,
71, 48, 140, 254, 245, 255, 247, 247, 40, 185, 248, 251,
245, 28, 124, 204, 204, 76, 36, 1, 107, 28, 234, 163, 202,
224, 245, 128, 167, 204, 9, 92, 217, 54, 239, 174, 173, 102,
193, 189, 190, 121, 100, 108, 167, 44, 43, 77, 180, 204, 8,
81, 70, 223, 11, 38, 24, 254, 210, 210, 177, 32, 81, 195, 243, 125, 8,
169, 112, 32, 97, 53, 195, 13, 203, 9, 47, 104, 125, 117, 114, 124, 165, 203,
181, 235, 193, 206, 70, 180, 174, 0, 167, 181, 41, 164, 30, 116, 127, 198, 245,
146, 87, 224, 149, 206, 57, 4, 192, 210, 65, 210, 129, 240, 178, 105, 228, 108,
245, 148, 140, 40, 35, 195, 38, 58, 65, 207, 215, 253, 65, 85, 208, 76, 62, 3,
237, 55, 89, 232, 50, 217, 64, 244, 157, 199, 121, 252, 90, 17, 212, 203, 149,
152, 140, 187, 234, 177, 73, 174, 193, 100, 192, 143, 97, 53, 145, 135, 19,
103, 13, 90, 135, 151, 199, 91, 239, 247, 33, 39, 145, 101, 120, 99, 3, 186, 86,
99, 41, 237, 203, 111, 79, 220, 135, 158, 42, 30, 154, 120, 67, 87, 167, 135,
176, 183, 191, 253, 115, 184, 21, 233, 58, 129, 233, 142, 39, 128, 211, 118,
137, 139, 255, 114, 20, 218, 113, 154, 27, 127, 246, 250, 1, 8, 198, 250, 209,
92, 222, 173, 21, 88, 102, 219}

hash = zero_index(hash)

local utils = {}
utils.zero_index = zero_index

function utils.randm(max)
	return math.random(0, max - 1) -- // math.random(0, 2147483647) % max
end

function utils.nmod(left, right)
	left = left % right

	if left < 0 then
		left = left + right
	end

	return left
end

function utils.p2d_noise(x, y, hash, seed)
	local tmp = hash[(y + seed) % 256]
	return hash[(tmp + x) % 256]
end

function utils.p2d_lerp(x, y, s)
	return x + s * s * (3 - 2 * s) * (y - x)
end

function utils.perlin2d(seed, x, y, freq)
	local amp, fin, div = 1.0, 0, 0.0

	local xa = x * freq
	local ya = y * freq

	for _ = 0, 3 do
		div = div + (256 * amp)

		local x_int = utils.int(xa)
		local y_int = utils.int(ya)
		local x_frac = xa - x_int
		local y_frac = ya - y_int

		local s = utils.p2d_noise(x_int, y_int, hash, seed)
		local t = utils.p2d_noise(x_int + 1, y_int, hash, seed)
		local u = utils.p2d_noise(x_int, y_int + 1, hash, seed)
		local v = utils.p2d_noise(x_int + 1, y_int + 1, hash, seed)

		local low = utils.p2d_lerp(s, t, x_frac)
		local high = utils.p2d_lerp(u, v, x_frac)

		fin = fin + (utils.p2d_lerp(low, high, y_frac) * amp)
		amp = amp / 2
		xa = xa * 2
		ya = ya * 2
	end

	return (fin / div)
end

function utils.dist2d(x, y, p, q)
	return math.sqrt((p - x) ^ 2 + (q - y) ^ 2)
end

function utils.dist3d(x, y, z, p, q, r)
	return math.sqrt((p - x) ^ 2 + (q - y) ^ 2 + (r - z) ^ 2)
end

function utils.create_array(length, value)
	local tbl = {}

	for i = 0, length - 1 do
		tbl[i] = value
	end

	return tbl
end

function utils.create_2d_array(h, w, value)
	local tbl = {}

	for y = 0, h - 1 do
		tbl[y] = {}

		for x = 0, w - 1 do
			tbl[y][x] = value
		end
	end

	return tbl
end

function utils.zinsert(tbl, value)
	if not tbl[0] then
		tbl[0] = value
	else
		tbl[#(tbl) + 1] = value
	end
end

function utils.split(inp, sep)
	sep = sep or "%s"

	local t = {}

	for str in string.gmatch(inp, "([^"..sep.."]+)") do
		table.insert(t, str)
	end

	return t
end

function utils.strnum(ptr, offset, num)
	return ptr:sub(1, offset) .. tostring(num) .. ptr:sub(offset + #tostring(num) + 1)
end

function utils.int(x)
	if x >= 0 then
		return math.floor(x)
	else
		return -math.floor(math.abs(x))
	end
end

local function read_line(file)
	local line = line_cache[file]

	if not line then
		line = {utils.split(file, "\n"), 1}
		line_cache[file] = line
	end

	local thing = line[1][line[2]]
	line[2] = line[2] + 1

	if line[2] > #(line[1]) then
		line[2] = 1
	end

	return thing
end

function utils.fscanf(file, format)
	local results = {}
	local flines = utils.split(format, "\n")

	for i = 1, #(flines) do
		local format = flines[i]
		local line = read_line(file)
		assert(line, "line not found")

		local pattern = format:gsub("(%S+)", function(char)
			if char == "%d" then
				return "([-+]?%d+)"
			elseif char == "%f" then
				return "([-+]?%d*%.?%d+)"
			elseif char == "%s" then
				return "[%s]+"
			elseif char == "%c" then
				return "(.?)"
			elseif char == "%u" then
				return "(%u+)"
			else
				return char
			end
		end)

		local _, count = line:gsub(pattern, "foobar123")
		local iterator = line:gmatch(pattern)

		for _ = 1, count do
			for _, v in ipairs({iterator()}) do
				table.insert(results, v)
			end
		end
	end

	for i, v in ipairs(results) do
		if tonumber(v) then
			results[i] = tonumber(v)
		end
	end

	return unpack(results)
end

function utils.reset(tbl, value)
	for i, v in pairs(tbl) do
		if type(v) == "table" then
			utils.reset(v, value)
		else
			tbl[i] = value
		end
	end
end

function utils.clear(tbl)
	for i in pairs(tbl) do
		tbl[i] = nil
	end
end

return utils