local data = require("libs/data")
local utils = require("libs/utility")
local _blocks = require("libs/blocks")
local _player = require("libs/player")
local options = require("libs/options")
local msgpack = require("libs/msgpack")

local bit = require("libs/sbit32")

local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local nmod = utils.nmod
local randm = utils.randm

local floor = math.floor
local randomseed = math.randomseed
local filesystem = data.filesystem

local CHUNK_SIZE = 64
local CHUNKARR_DIAM = 3
local CHUNK_DATA_SIZE = CHUNK_SIZE ^ 3
local CHUNKARR_SIZE = CHUNKARR_DIAM ^ 3
local CHUNKARR_RAD = (CHUNKARR_DIAM - 1) / 2

local terrain = {}

local Chunk = {}
Chunk.CHUNK_SIZE = 64
Chunk.CHUNKARR_DIAM = 3
Chunk.CHUNKARR_RAD = CHUNKARR_RAD
Chunk.CHUNKARR_SIZE = CHUNKARR_SIZE
Chunk.CHUNK_DATA_SIZE = CHUNK_DATA_SIZE

local World = {}

terrain.Chunk = Chunk
terrain.World = World

local count = 0

local function chunkFilePath(world, x, y, z)
	return string.format("%s/%08X%08X%08X", world.path, rshift(x, 6), rshift(y, 6), rshift(z, 6))
end

local function chunkHash(x, y, z)
	x = band(x, 0x3FF)
	y = band(y, 0x3FF)
	z = band(z, 0x3FF)
	y = lshift(y, 10)
	z = lshift(z, 20)

	return bor(x, y, z) + 1
end

local function chunkLookup(world, x, y, z)
	local chunk
	local chunks = world.chunk
	local ax, ay, az = 1e8, 1e8, 1e8

	x = rshift(x, 6)
	y = rshift(y, 6)
	z = rshift(z, 6)

	if (ax ~= x or ay ~= y or az ~= z) then
		local hash = chunkHash(x, y, z)

		local first = 0
		local last = CHUNKARR_SIZE - 1
		local middle = floor((CHUNKARR_SIZE - 1) / 2)

		if not chunks[last] then
			return
		end

		while first <= last do
			if chunks[middle].coordHash > hash then
				first = middle + 1
			elseif chunks[middle].coordHash == hash then
				chunk = chunks[middle]
				return chunk
			else
				last = middle - 1
			end

			middle = floor((first + last) / 2)
		end
	end

	return chunk
end

local function genStructure(blocks, x, y, z, type)
	if type == 0 then
		for _ = randm(2) + 4, 1, -1 do
			terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_WOOD, true)
			y = y - 1
		end

		terrain.setCube(blocks, x - 2, y + 1, z - 2, 5, 2, 5, _blocks.BLOCK_LEAVES)
		terrain.setCube(blocks, x - 1, y - 1, z - 1, 3, 2, 3, _blocks.BLOCK_LEAVES)
	elseif type == 1 then
		y = y - (5 + randm(2))

		local step = 1
		local cubePlaced = 1

		while cubePlaced > 0 and step < 64 do
			cubePlaced = band(cubePlaced,
				terrain.setCube(
					blocks,
					x - utils.int(step / 2),
					y + 1,
					z - utils.int(step / 2),
					step, 1, step,
					_blocks.BLOCK_BRICKS, true
				)
			)

			y = y + 1
			step = step + 2
		end
	end
end

local function genChunk(world, seed, xOffset, yOffset, zOffset, type, force, coords)
	randomseed(seed * (xOffset * yOffset * zOffset + 1))

	local distMax, distMaxI
	local chunk = chunkLookup(world, xOffset, yOffset, zOffset)

	if not chunk then
		local i = 0

		while i < CHUNKARR_SIZE and world.chunk[i] and world.chunk[i].loaded > 0 do
			i = i + 1
		end

		if i == CHUNKARR_SIZE then
			distMax = 0
			distMaxI = 0

			for i = 0, CHUNKARR_SIZE - 1 do
				local dist = utils.dist3d(
					coords.x - world.chunk[i].center.x,
					coords.y - world.chunk[i].center.y,
					coords.z - world.chunk[i].center.z,
					2, 2, 2
				)

				if dist > distMax then
					distMax = dist
					distMaxI = i
				end
			end

			i = distMaxI
		end

		chunk = world.chunk[i]

		if not chunk then
			chunk = {
				center = {
					x = 0,
					y = 0,
					z = 0
				},
				loaded = 0,
				coordHash = 0,
			}

			utils.zinsert(world.chunk, chunk)
		end
	elseif not force then
		return
	end

	assert(chunk, "wattesgima??")

	if chunk.loaded > 0 then
		local err = Chunk.save(world, chunk)

		if err then
			print("genChunk: chunk save fail")
			error("Could not save/unload chunk")
		end

		return
	else
		chunk.blocks = utils.create_array(CHUNK_DATA_SIZE, 0)
	end

	if not chunk.blocks then
		print("genChunk: memory allocation fail")
		return
	end

	local blocks = chunk.blocks

	-- // no need to set block values as allocation is already done

	local hashX = rshift(xOffset, 6)
	local hashY = rshift(yOffset, 6)
	local hashZ = rshift(zOffset, 6)
	hashX = band(hashX, 0x3FF)
	hashY = band(hashY, 0x3FF)
	hashZ = band(hashZ, 0x3FF)
	hashY = lshift(hashY, 10)
	hashZ = lshift(hashZ, 20)
	chunk.coordHash = bor(hashX, hashY, hashZ) + 1

	chunk.center.x = xOffset + 32
	chunk.center.y = yOffset + 32
	chunk.center.z = zOffset + 32

	local path = chunkFilePath(world, xOffset, yOffset, zOffset)

	if data.fileExists(path) then
		chunk.blocks = msgpack.unpack(filesystem:read_file(path))
		chunk.loaded = count + 1
		count = count + 1
		World.sort(world)

		return true
	end

	if type == -1 then
		terrain.genDev(blocks, xOffset, yOffset, zOffset)
	elseif type == 0 then
		terrain.genClassic(blocks, yOffset)
	elseif type == 1 then
		terrain.genNew(blocks, seed, xOffset, yOffset, zOffset)
	elseif type == 2 then
		terrain.genStone(blocks, yOffset)
	elseif type == 3 then
		terrain.genFlat(blocks, yOffset)
	elseif type == 4 then
		terrain.genWater(blocks, yOffset)
	end

	chunk.loaded = count + 1
	count = count + 1

	return true
end

function World.sort(world)
	-- // table.sort(world.chunk, function(a, b)
	-- // 	return a.coordHash < b.coordHash
	-- // end)
	for i = 0, CHUNKARR_SIZE - 1 do
		for j = 0, CHUNKARR_SIZE - 2 - i do
			if world.chunk[j].coordHash < world.chunk[j + 1].coordHash then
				local temp = world.chunk[j]
				world.chunk[j] = world.chunk[j + 1]
				world.chunk[j + 1] = temp
			end
		end
	end
end

function World.save(world)
	if data.ensureDirectoryExists(world.path) then
		return true
	end

	for index = 0, CHUNKARR_SIZE - 1 do
		local chunk = world.chunk[index]

		if chunk.loaded > 0 then
			local err = Chunk.save(world, chunk)

			if err then
				return err
			end
		end
	end

	local playerPath = data.getWorldPlayerPath(world.path, options.options.username.buffer)

	local metadataPath = data.getWorldMetaPath(world.path)
	filesystem:create_file(playerPath)
	filesystem:create_file(metadataPath)

	_player.save(world.player, playerPath)

	filesystem:write_file(
		metadataPath, string.format(
			"%d\n%d\n%d\n%d\n%d\n",
			0, world.type, world.seed,
			world.dayNightMode, world.time
		)
	)
end

function World.wipe(world)
	utils.reset(world.player, 0)

	world.path = ""
	world.player.pos.x = 0
	world.player.pos.y = 0
	world.player.pos.z = 0

	for _, chunk in pairs(world.chunk) do
		if chunk.loaded and chunk.loaded > 0 then
			utils.clear(chunk.blocks)
			utils.reset(chunk, 0)
		end
	end
end

function World.load(world, name)
	World.wipe(world)
	world.path = data.getWorldPath(name)

	local metadataPath = data.getWorldMetaPath(world.path)
	local metadata = filesystem:read_file(metadataPath)

	if not metadataPath then
		return 2
	end

	local version = utils.fscanf(metadata, "%d")

	if version ~= 0 then
		return 3
	end

	local type, seed, dayNightMode, time = utils.fscanf(metadata, "%d\n%d\n%d\n%d")
	world.type = type
	world.seed = seed
	world.dayNightMode = dayNightMode
	world.time = time

	local playerPath = data.getWorldPlayerPath(world.path, options.options.username.buffer)

	if data.fileExists(playerPath) then
		_player.load(world.player, playerPath)
	end
end

function World.getBlock(world, x, y, z)
	local chunk = chunkLookup(world, x, y, z)

	if not chunk or (chunk.loaded and chunk.loaded == 0 or not chunk.loaded) then
		return _blocks.BLOCK_NIL
	end

	return chunk.blocks[
		nmod(x, CHUNK_SIZE) +
		(nmod(y, CHUNK_SIZE) *
		CHUNK_SIZE) +
		(nmod(z, CHUNK_SIZE) *
		CHUNK_SIZE * CHUNK_SIZE)
	]
end

function World.setBlock(world, x, y, z, block, force)
	local b = World.getBlock(world, x, y, z) == _blocks.BLOCK_AIR

	if force or b then
		local chunk = chunkLookup(world, x, y, z)

		if not chunk or not chunk.loaded then
			return -1
		end

		chunk.blocks[
			nmod(x, CHUNK_SIZE) +
			(nmod(y, CHUNK_SIZE) *
			CHUNK_SIZE) +
			(nmod(z, CHUNK_SIZE) *
			CHUNK_SIZE * CHUNK_SIZE)
		] = block

		return b
	end
end

function Chunk.save(world, chunk)
	local path = chunkFilePath(world, chunk.center.x - 32, chunk.center.y - 32, chunk.center.z - 32)

	if not filesystem:read_file(path) then
		filesystem:create_file(path)
	end

	filesystem:write_file(
		path, msgpack.pack(chunk.blocks)
	)
end

function terrain.getBlock(blocks, x, y, z)
	if x < 0 or y < 0 or z < 0 or x >= CHUNK_SIZE or y >= CHUNK_SIZE or z >= CHUNK_SIZE then
		return _blocks.BLOCK_AIR
	end

	return blocks[
		x + (y * CHUNK_SIZE) +
		(z * CHUNK_SIZE * CHUNK_SIZE)
	]
end

function terrain.setBlock(blocks, x, y, z, block, force)
	if x < 0 or y < 0 or z < 0 then
		return 0
	end

	if x >= CHUNK_SIZE or y >= CHUNK_SIZE or z >= CHUNK_SIZE then
		return 0
	end

	x = floor(x)
	y = floor(y)
	z = floor(z)

	local notAir = blocks[
		x + (y * CHUNK_SIZE) +
		(z * CHUNK_SIZE * CHUNK_SIZE)
	] ~= _blocks.BLOCK_AIR

	if not force and notAir then
		return notAir
	end

	blocks[
		x + (y * CHUNK_SIZE) +
		(z * CHUNK_SIZE * CHUNK_SIZE)
	] = block

	return notAir
end

function terrain.setCube(blocks, x, y, z, w, h, l, block, force)
	x = x - 1
	y = y - 1
	z = z - 1

	local blockPlaced = 0

	for xx = w + x, x + 1, -1 do
		for yy = h + y, y + 1, -1 do
			for zz = l + z, z + 1, -1 do
				blockPlaced = bor(blockPlaced, terrain.setBlock(blocks, xx, yy, zz, block, force) and 1 or 0)
			end
		end
	end

	return blockPlaced
end

function terrain.genClassic(blocks, yOffset)
	for x = 0, CHUNK_SIZE - 1 do
		for y = 0, CHUNK_SIZE - 1 do
			for z = 0,  CHUNK_SIZE - 1 do
				if (y + yOffset > 32) then
					local block = (randm(2) == 0 and randm(9) or 0)

					if block == _blocks.BLOCK_SAND or block == _blocks.BLOCK_GRAVEL then
						block = _blocks.BLOCK_DIRT
					end

					terrain.setBlock(blocks, x, y, z, block, true)
				end
			end
		end
	end
end

function terrain.genNew(blocks, seed, xOffset, yOffset, zOffset)
	local heightmap = {}

	for x = 0, CHUNK_SIZE - 1 do
		heightmap[x] = {}

		for z = 0, CHUNK_SIZE - 1 do
			heightmap[x][z] = utils.int(utils.perlin2d(
				seed,
				x + xOffset + 0xFFFFFF,
				z + zOffset + 0xFFFFFF,
				0.0625
			) * 16 +
			utils.perlin2d(
				seed,
				x + xOffset + 0xFFFFFF,
				z + zOffset + 0xFFFFFF,
				0.0078125
			) * 64)
		end
	end

	for x = 0, CHUNK_SIZE - 1 do
		for y = 0, CHUNK_SIZE - 1 do
			for z = 0, CHUNK_SIZE - 1 do
				if y + yOffset > heightmap[x][z] + 4 then
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_STONE, true)
				elseif y + yOffset > heightmap[x][z] then
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_DIRT, true)
				elseif y + yOffset == heightmap[x][z] then
					if y + yOffset < 44 then
						terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_GRASS, true)
					else
						terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_SAND, true)
					end
				elseif y + yOffset < 45 then
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_AIR, true)
				else
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_WATER, true)
				end
			end
		end
	end

	for x = 0, CHUNK_SIZE - 1 do
		for z = 0, CHUNK_SIZE - 1 do
			repeat
				local noisePoint = utils.perlin2d(
					seed + yOffset,
					x + xOffset + 0xFFFFFF,
					z + zOffset + 0xFFFFFF,
					.0625
				)

				if noisePoint < .47 or noisePoint > .53 then
					break
				end

				local elevation = floor(utils.perlin2d(
					seed + 2 + yOffset,
					x + xOffset + 0xFFFFFF,
					z + zOffset + 0xFFFFFF,
					.0625
				) * 8)

				local height = floor(utils.perlin2d(
					seed + 3 + yOffset,
					x + xOffset + 0xFFFFFF,
					z + zOffset + 0xFFFFFF,
					.0625
				) * 4 + 2 - randm(1)) -- // (randm(1) > 0) [this part in the C port makes no fucking sense]

				local lowPoint = 64 - elevation
				local highPoint = 64 - elevation - height

				for y = highPoint, lowPoint - 1 do
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_AIR, true)
				end

				if terrain.getBlock(blocks, x, lowPoint, z) == 2 then
					if terrain.getBlock(blocks, x, highPoint - 1, z) == _blocks.BLOCK_AIR then
						terrain.setBlock(blocks, x, lowPoint, z, _blocks.BLOCK_GRASS, true)
					else
						terrain.setBlock(blocks, x, lowPoint, z, _blocks.BLOCK_GRAVEL, true)
					end
				end
			until true
		end
	end

	randomseed(seed * (xOffset * yOffset * zOffset + 2))

	for _ = randm(2), 1, -1 do
		local x = randm(64)
		local z = randm(64)
		genStructure(blocks, x, heightmap[x][z] + 1, z, 1)
	end

	randomseed(seed * (xOffset * yOffset * zOffset + 3))

	for _ = randm(16) + 64, 1, -1 do
		repeat
			local x = randm(64)
			local z = randm(64)

			if terrain.getBlock(blocks, x, heightmap[x][z], z) ~= _blocks.BLOCK_GRASS then
				break
			end

			genStructure(blocks, x, heightmap[x][z] - 1, z, 0)
		until true
	end

	randomseed(seed * (xOffset * yOffset * zOffset + 4))

	for x = 0, CHUNK_SIZE - 1 do
		for z = 0, CHUNK_SIZE - 1 do
			if terrain.getBlock(blocks, x, heightmap[x][z], z) == _blocks.BLOCK_GRASS and randm(2) == 0 then
				terrain.setBlock(blocks, x, heightmap[x][z] - 1, z, _blocks.BLOCK_TALL_GRASS)
			end
		end
	end
end

function terrain.genStone(blocks, yOffset)
	for x = 0, CHUNK_SIZE - 1 do
		for y = 0, CHUNK_SIZE - 1 do
			for z = 0, CHUNK_SIZE - 1 do
				if y + yOffset > 32 then
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_STONE, true)
				else
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_AIR, true)
				end
			end
		end
	end
end

function terrain.genFlat(blocks, yOffset)
	for x = 0, CHUNK_SIZE - 1 do
		for y = 0, CHUNK_SIZE - 1 do
			for z = 0, CHUNK_SIZE - 1 do
				if y + yOffset < 32 then
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_AIR, true)
				elseif y + yOffset == 32 then
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_GRASS, true)
				elseif y + yOffset > 32 then
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_DIRT, true)
				end
			end
		end
	end
end

function terrain.genWater(blocks, yOffset)
	for x = 0, CHUNK_SIZE - 1 do
		for y = 0, CHUNK_SIZE - 1 do
			for z = 0, CHUNK_SIZE - 1 do
				if y + yOffset > 64 then
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_SAND, true)
				elseif y + yOffset > 32 then
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_WATER, true)
				else
					terrain.setBlock(blocks, x, y, z, _blocks.BLOCK_AIR, true)
				end
			end
		end
	end
end

function terrain.genDev(block, xOffset, yOffset, zOffset)
	if yOffset ~= 0 then
		return
	end

	for x = 0, CHUNK_SIZE - 1 do
		for z = 0, CHUNK_SIZE - 1 do
			terrain.setBlock(
				block, x, 4, z,
				(x + 1) % (_blocks.NUMBER_OF_BLOCKS - 1), true
			)

			terrain.setBlock(block, x, 5, z, _blocks.BLOCK_STONE, true)
		end
	end
end

terrain.genChunk = genChunk
terrain.chunkLookup = chunkLookup

return terrain