local bit = require("libs/sbit32")

local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local utils = require("libs/utility")
local blocks = require("libs/blocks")
local int = utils.int

local texts = {}
texts.BLOCK_TEXTURE_W = 16
texts.BLOCK_TEXTURE_H = 16
texts.TEXTURES_SIZE = blocks.NUMBER_OF_BLOCKS * texts.BLOCK_TEXTURE_W * texts.BLOCK_TEXTURE_H * 3
texts.textures = utils.create_array(texts.TEXTURES_SIZE, 0)

local cobbleCracks = {
	0b0000001110000100,
	0b0010110010000110,
	0b1011100011001110,
	0b1110100011110011,
	0b0011000110001001,
	0b0001000100001111,
	0b0001111110000001,
	0b0011001111100110,
	0b1110001000111100,
	0b0100010100011000,
	0b1000010000011100,
	0b0100110000110111,
	0b0011111011000010,
	0b1100001010000001,
	0b0010000111000011,
	0b0000111100111110,
}

local function determ2d(x, y)
	return math.fmod(math.abs(math.tan(9 * x + 1 + y)), 1)
end

local function genTexture(blockId)
	local brightness = 255 - utils.randm(96)

	for y = 0, texts.BLOCK_TEXTURE_H * 3 - 1 do
		for x = 0, texts.BLOCK_TEXTURE_W - 1 do
			local baseColor = 0x966C4A
			local noiseFloor = 255
			local noiseScale = 96

			if blockId == blocks.BLOCK_SAND then
				noiseScale = 48
			elseif blockId == blocks.BLOCK_GRAVEL then
				noiseScale = 140
			end

			local bullshit = (band(rshift(x * x * (3 + x) * 81, 2), 0x3))

			if blockId == blocks.BLOCK_GRASS and y < bullshit + 18 then
				baseColor = 0x6AAA40
			elseif blockId == blocks.BLOCK_GRASS and y < bullshit + 19 then
				brightness = int(brightness * 2 / 3)
			end

			local needAltNoise = (blockId == blocks.BLOCK_STONE or blockId == blocks.BLOCK_WATER)

			if not needAltNoise or utils.randm(3) == 0 then
				brightness = noiseFloor - utils.randm(noiseScale)
			end

			if blockId == blocks.BLOCK_WOOD then
				baseColor = 0x675231

				if x > 0 and x < 15 and ((y > 0 and y < 15) or (y > 32 and y < 47)) then
					baseColor = 0xBC9862

					local i6 = x - 7
					local i7 = band(y, 0xF) - 7

					i6 = (i6 < 0 and 1 - i6 or i6)
					i7 = (i7 < 0 and 1 - i7 or i7)
					i6 = (i7 > i6 and i7 or i6)

					brightness = 196 - utils.randm(32) + i6 % 3 * 32
				elseif utils.randm(2) == 0 then
					brightness = brightness * (150 - band(x, 0x1) * 100) / 100
				end
			end

			if blockId == blocks.BLOCK_STONE then
				baseColor = 0x7F7F7F
			elseif blockId == blocks.BLOCK_SAND then
				baseColor = 0xD8CE9B
			elseif blockId == blocks.BLOCK_GRAVEL then
				baseColor = 0xAAAAAA
			elseif blockId == blocks.BLOCK_BRICKS then
				baseColor = 0xB53A15

				if int(x + int(y / 4) * 4) % 8 == 0 or y % 4 == 0 then
					baseColor = 12365733
				end
			elseif blockId == blocks.BLOCK_COBBLESTONE then
				baseColor = 0x999999
				brightness = brightness - (
					band(rshift(
						cobbleCracks[band(y, 0xF) + 1],
					x), 1)
				) * 128
			elseif blockId == blocks.BLOCK_WATER then
				baseColor = 0x3355EE
			elseif blockId == blocks.BLOCK_PLAYER_HEAD then
				brightness = 255

				if utils.dist2d(x, y % texts.BLOCK_TEXTURE_H, 8, 8) > 6.2 or (y / 16) % 3 == 2 then
					baseColor = 0
				else
					baseColor = 0xFFFFFF
					brightness = brightness - utils.dist2d(x, y % texts.BLOCK_TEXTURE_H, 8, 2) * 8
					brightness = int(brightness)
				end
			elseif blockId == blocks.BLOCK_PLAYER_BODY then
				brightness = 255

				if utils.dist2d(x, y % texts.BLOCK_TEXTURE_H, 8, 8) > 12.2 or int(y / 16) % 3 ~= 1 and int(y / 16) % 3 ~= 2 then
					baseColor = 0
				else
					baseColor = 0xFFFFFF
					brightness = brightness - utils.dist2d(x, y % texts.BLOCK_TEXTURE_H, 8, 2) * 8
				end
			elseif blockId == blocks.BLOCK_LEAVES then
				baseColor = 0x50D937

				if utils.randm(2) == 0 then
					baseColor = 0
					brightness = 255
				end
			elseif blockId == blocks.BLOCK_TALL_GRASS then
				baseColor = 0x50D937

				if determ2d(x, int(y / 3)) < .2 or y < texts.BLOCK_TEXTURE_H or utils.randm(y - texts.BLOCK_TEXTURE_H + 1) < 2 then
					baseColor = 0
					brightness = 255
				end
			end

			local finalBrightness = brightness

			if y >= texts.BLOCK_TEXTURE_H * 2 then
				finalBrightness = int(finalBrightness / 2)
			end

			local finalColor = bor(
				lshift(band(rshift(baseColor, 16), 0xFF) * (finalBrightness / 255), 16),
				lshift(band(rshift(baseColor, 8), 0xFF) * (finalBrightness / 255), 8),
				band(baseColor, 0xFF) * (finalBrightness / 255)
			)

			texts.textures[
				x +
				y * texts.BLOCK_TEXTURE_H +
				blockId * texts.BLOCK_TEXTURE_W * texts.BLOCK_TEXTURE_H * 3
			] = finalColor
		end
	end
end

function texts.genTextures(seed)
	math.randomseed(seed)

	for blockId = 1, blocks.NUMBER_OF_BLOCKS - 1 do
		genTexture(blockId)
	end
end

return texts