local gui = require("libs/gui")
local menus = require("libs/menus")
local compat = require("libs/compat")
local utils = require("libs/utility")
local blocks = require("libs/blocks")
local Player = require("libs/player")
local texts = require("libs/textures")
local terrain = require("libs/terrain")
local options = require("libs/options")
local bit = require("libs/sbit32")

local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local int = utils.int
local nmod = utils.nmod

local max = math.max
local min = math.min
local sin = math.sin
local cos = math.cos

local abs = math.abs
local sqrt = math.sqrt
local floor = math.floor

local state = menus.state
local popup = menus.popup

local Chunk = terrain.Chunk
local World = terrain.World

local InvSlot = Player.InvSlot
local Inventory = Player.Inventory

local round = math.round or function(x)
	return floor(x + .25)
end

local f21, f22, f23, f24, f25, f26, f27, f28
local f29, f30, f31, f32, f33, f34, f35, f36

local chunk
local selectedPass = false
local blockSelected = false
local coordPass = {x = 0, y = 0, z = 0}
local blockSelect = {x = 0, y = 0, z = 0}
local blockSelectOffset = {x = 0, y = 0, z = 0}

local hmm
local world = {
	player = {
		xp = 0,
		hRot = 0,
		vRot = 0,
		health = 0,
		hunger = 0,
		breath = 0,

		FBVelocity = 0,
		LRVelocity = 0,
		vectorH = {x = 0, y = 0},
		vectorV = {x = 0, y = 0},
		pos = {x = 0, y = 0, z = 0},

		inventory = {
			slots = {},
			armor = {},
			hotbar = {},
			hotbarSelect = 0,
			offhand = {blockid = 0, amount = 0, durability = 0},
		}
	},

	type = 0,
	seed = 0,
	time = 0,
	path = nil,
	chunk = {},
	dayNightMode = 0
}

--[[
for i = 0, Chunk.CHUNKARR_SIZE - 1 do
	chunks[i] = {center = {x = 0, y = 0, z = 0}, coordHash = 0, loaded = 0}
end
]]

for i = 0, Player.HOTBAR_SIZE - 1 do
	world.player.inventory.hotbar[i] = {blockid = 0, amount = 0, durability = 0}
end

for i = 0, Player.INVENTORY_SIZE - 1 do
	world.player.inventory.slots[i] = {blockid = 0, amount = 0, durability = 0}
end

for i = 0, Player.ARMOR_SIZE - 1 do
	world.player.inventory.armor[i] = {blockid = 0, amount = 0, durability = 0}
end

local gamePopup
local activeSlot
local player = world.player
local setColor = compat.setColor
local gameState = state.STATE_TITLE
local playerMovement = {x = 0, y = 0, z = 0}

local guiOn
local debugOn

local l
local flipFlop = false
local gameStart = os.clock()
local backgroundRect = {x = 0, y = 0, w = gui.BUFFER_W, h = gui.BUFFER_H}

local fps_now = 0
local fps_count = 0
local fps_lastmil = 0

local gameLoop = {}
gameLoop.errorMessage = nil

local function getTicks()
	return (os.clock() - gameStart) * 1000
end

function gameLoop.resetGame()
	l = getTicks()

	guiOn = true
	gamePopup = 0
	debugOn = false
	utils.clear(gui.chatHistory)
	gui.chatAdd("Game started")
	gui.chatAdd("Chat /help for help")
end

function gameLoop.gameLoop(canvas, inputs)
	if gameLoop.errorMessage then
		if state.err(canvas, inputs, gameLoop.errorMessage) then
			gameLoop.errorMessage = nil
			compat.quit()
		end

		return
	end

	if gameState == state.STATE_TITLE then
		gameState = state.title(canvas, inputs, gameState)

		if gameState == true then
			compat.quit()
		end
	elseif gameState == state.STATE_SELECT_WORLD then
		gameState, hmm = state.selectWorld(canvas, inputs, gameState, world)

		if hmm then
			world = hmm
		end
	elseif gameState == state.STATE_NEW_WORLD then
		gameState = state.newWorld(canvas, inputs, gameState, world)
	elseif gameState == state.STATE_LOADING then
		if state.loading(canvas, world, world.seed, player.pos) then
			gameLoop.resetGame()
			gameState = 5
		end
	elseif gameState == state.STATE_GAMEPLAY then
		gameLoop.gameplay(canvas, inputs)
	elseif gameState == state.STATE_OPTIONS then
		gameState = state.options(canvas, inputs, gameState)
	else
		gameState = state.egg(canvas, inputs, gameState)
	end

	if gameState ~= state.STATE_GAMEPLAY or gamePopup ~= popup.POPUP_HUD then
		inputs.mouse.left = nil
		inputs.mouse.right = nil
	end
end

function gameLoop.gameplay(canvas, inputs)
	local canvas = canvas
	local chunks = world.chunk
	local options = options.options

	if options.trapMouse > 0 then
		compat.setMouse(true)
	end

	local fpx, fpy, fpz = round(player.pos.x), round(player.pos.y), round(player.pos.z)
	local headInWater = World.getBlock(world, fpx, fpy, fpz) == blocks.BLOCK_WATER
	local feetInWater = World.getBlock(world, fpx, fpy + 1, fpz) == blocks.BLOCK_WATER

	local effectDrawDistance = (headInWater and 10 or options.drawDistance)

	player.vectorH.x = sin(player.hRot)
	player.vectorH.y = cos(player.hRot)
	player.vectorV.x = sin(player.vRot)
	player.vectorV.y = cos(player.vRot)

	local timeCoef = 0

	if world.dayNightMode == 0 then
		timeCoef = (world.time % 102944) / 16384
		timeCoef = sin(timeCoef)
		timeCoef = timeCoef / sqrt(timeCoef * timeCoef + (1 / 128))
		timeCoef = (timeCoef + 1) / 2
	else
		timeCoef = (2 - world.dayNightMode)
	end

	local color

	if headInWater then
		color = {
			48  * timeCoef,
			96  * timeCoef,
			200 * timeCoef
		}
	else
		color = {
			153 * timeCoef,
			204 * timeCoef,
			255 * timeCoef
		}
	end

	compat.clear(canvas, unpack(color))

	if inputs.keyboard.esc then
		gamePopup = (gamePopup == 1 and 0 or 1)
	end

	fps_count = fps_count + 1

	if fps_lastmil < getTicks() - 1000 then
		fps_lastmil = getTicks()
		fps_now = fps_count
		fps_count = 0
	end

	while getTicks() - l > 10 do
		world.time = world.time + 1
		l = l + 10
		gameLoop.processMovement(inputs, feetInWater)
	end

	if gamePopup == popup.POPUP_HUD then
		activeSlot = player.inventory.hotbar[player.inventory.hotbarSelect]

		if (inputs.mouse.left or inputs.keyboard.n) and blockSelected then
			local blockid = World.getBlock(
				world,
				blockSelect.x,
				blockSelect.y,
				blockSelect.z
			)

			if blockid ~= blocks.BLOCK_PLAYER_BODY and blockid ~= blocks.BLOCK_PLAYER_HEAD and blockid ~= blocks.BLOCK_AIR and blockid ~= blocks.BLOCK_WATER then
				local pickedUp = {
					amount = 1,
					durability = 1,
					blockid = blockid,
				}

				Inventory.transferIn(player.inventory, pickedUp)

				World.setBlock(
					world,
					blockSelect.x,
					blockSelect.y,
					blockSelect.z,
					0, 1
				)
			end
		end

		blockSelectOffset.x = blockSelectOffset.x + blockSelect.x
		blockSelectOffset.y = blockSelectOffset.y + blockSelect.y
		blockSelectOffset.z = blockSelectOffset.z + blockSelect.z

		if (inputs.mouse.right or inputs.keyboard.m) and blockSelected then
			if (
				abs(player.pos.x - .5 - blockSelectOffset.x) >= .8 or
				abs(player.pos.y - blockSelectOffset.y) >= 1.45 or
				abs(player.pos.z - .5 - blockSelectOffset.z) >= .8
			) and activeSlot.amount > 0 then
				local blockSet = World.setBlock(
					world,
					blockSelectOffset.x,
					blockSelectOffset.y,
					blockSelectOffset.z,
					activeSlot.blockid, 1
				)

				if blockSet then
					activeSlot.amount = activeSlot.amount - 1

					if activeSlot.amount <= 0 then
						activeSlot.blockid = 0
					end
				end
			end
		end

		if inputs.keyboard.f then
			local left, right = InvSlot.swap(player.inventory.hotbar[player.inventory.hotbarSelect], player.inventory.offhand)

			player.inventory.hotbar[player.inventory.hotbarSelect] = left
			player.inventory.offhand = right
		end

		if inputs.mouse.wheel ~= 0 then
			player.inventory.hotbarSelect = nmod(player.inventory.hotbarSelect - inputs.mouse.wheel, 9)
			inputs.mouse.wheel = 0
		end

		for i = 0, 9 do
			if inputs.keyboard["num" .. tostring(i)] then
				player.inventory.hotbarSelect = (i == 0 and 8 or i - 1)
			end
		end

		if inputs.keyboard.f1 then
			guiOn = not guiOn
		end

		if inputs.keyboard.f3 then
			debugOn = not debugOn
		end

		if inputs.keyboard.f4 then
			gamePopup = (gamePopup == popup.POPUP_ADVANCED_DEBUG and 0 or 4)
		end

		if inputs.keyboard.t then
			inputs.keyTyped = nil
			gamePopup = popup.POPUP_CHAT
		end

		if inputs.keyboard.e_fix then
			inputs.keyboard.e_fix = nil
			gamePopup = popup.POPUP_INVENTORY
		end
	end

	local effectFov = options.fov

	if headInWater then
		effectFov = effectFov + 20
	end

	selectedPass = false

	-- // the worst part (raycasting)

	for pixelX = 0, gui.BUFFER_W - 1 do
		local rayOffsetX = (pixelX - gui.BUFFER_HALF_W) / effectFov

		for pixelY = 0, gui.BUFFER_H - 1 do
			local pixelShade = 0
			local pixelMist = 255
			local finalPixelColor = 0
			local rayOffsetY = (pixelY - gui.BUFFER_HALF_H) / effectFov

			f21 = 1
			f26 = 5
			f22 = f21 * player.vectorV.y + rayOffsetY * player.vectorV.x
			f23 = rayOffsetY * player.vectorV.y - f21 * player.vectorV.x
			f24 = rayOffsetX * player.vectorH.y + f22 * player.vectorH.x
			f25 = f22 * player.vectorH.y - rayOffsetX * player.vectorH.x

			local rayDistanceLimit = effectDrawDistance

			for blockFace = 0, 2 do
				f27 = f24

				if blockFace == 1 then
					f27 = f23
				elseif blockFace == 2 then
					f27 = f25
				end

				f28 = 1 / ((f27 < 0) and (-1 * f27) or f27)
				f29 = f24 * f28
				f30 = f23 * f28
				f31 = f25 * f28
				f32 = player.pos.x - floor(player.pos.x)

				if blockFace == 1 then
					f32 = player.pos.y - floor(player.pos.y)
				elseif blockFace == 2 then
					f32 = player.pos.z - floor(player.pos.z)
				end

				if f27 > 0 then
					f32 = (1 - f32)
				end

				f33 = f28 * f32
				f34 = player.pos.x + f29 * f32
				f35 = player.pos.y + f30 * f32
				f36 = player.pos.z + f31 * f32

				if f27 < 0 then
					if blockFace == 0 then
						f34 = f34 - 1
					elseif blockFace == 1 then
						f35 = f35 - 1
					elseif blockFace == 2 then
						f36 = f36 - 1
					end
				end


				-- // god i hate this part

				local intersectedBlock = 0
				local blockRayPosition = {x = 0, y = 0, z = 0}

				while f33 < rayDistanceLimit do
					blockRayPosition.x = floor(f34)
					blockRayPosition.y = floor(f35)
					blockRayPosition.z = floor(f36)

					local lookup_now = {
						rshift(blockRayPosition.x, 6),
						rshift(blockRayPosition.y, 6),
						rshift(blockRayPosition.z, 6)
					}

					if lookup_now[1] ~= 1e8 or lookup_now[2] ~= 1e8 or lookup_now[3] ~= 1e8 then
						lookup_now[1] = band(lookup_now[1], 0x3FF)
						lookup_now[2] = band(lookup_now[2], 0x3FF)
						lookup_now[3] = band(lookup_now[3], 0x3FF)

						lookup_now[2] = lshift(lookup_now[2], 10)
						lookup_now[3] = lshift(lookup_now[3], 20)

						local lookup_hash = bor(lookup_now[1], lookup_now[2], lookup_now[3]) + 1

						local lookup_first = 0
						local lookup_last = Chunk.CHUNKARR_SIZE - 1
						local lookup_middle = floor((Chunk.CHUNKARR_SIZE - 1) / 2)

						while lookup_first <= lookup_last do
							if chunks[lookup_middle].coordHash > lookup_hash then
								lookup_first = lookup_middle + 1
							elseif chunks[lookup_middle].coordHash == lookup_hash then
								chunk = chunks[lookup_middle]

								if chunk and chunk.loaded > 0 then
									intersectedBlock = chunk.blocks[
										nmod(blockRayPosition.x, 64) +
										lshift(nmod(blockRayPosition.y, 64), 6) +
										lshift(nmod(blockRayPosition.z, 64), 12)
									] or 0
								end

								break
							else
								lookup_last = lookup_middle - 1
							end

							lookup_middle = int((lookup_first + lookup_last) / 2)
						end

						chunk = nil
					end

					if intersectedBlock ~= blocks.BLOCK_AIR and not (headInWater and intersectedBlock == blocks.BLOCK_WATER) then
						local textureX = band(floor((f34 + f36) * 16), 0xF)
						local textureY = band(floor(f35 * 16), 0xF) + 16

						if blockFace == 1 then
							textureX = band(floor(f34 * 16), 0xF)
							textureY = band(floor(f36 * 16), 0xF)

							if f30 < 0 then
								textureY = textureY + 32
							end
						end

						local pixelColor = 0xFFFFFF

						if (
							not blockSelected or
							blockRayPosition.x ~= blockSelect.x or blockRayPosition.y ~= blockSelect.y or blockRayPosition.z ~= blockSelect.z
						) or (
							textureX > 0
							and textureY % 16 > 0
							and textureX < 15
							and textureY % 16 < 15
						) or not guiOn or gamePopup > 0 then
							if intersectedBlock >= blocks.NUMBER_OF_BLOCKS then
								pixelColor = 0xFF0000
							else
								pixelColor = texts.textures[
									textureX + (textureY * 16) + intersectedBlock * 256 * 3
								]
							end
						end

						if f33 < f26 and (
							(
								false -- // options.trapMouse == 0
								and pixelX == int(inputs.mouse.x / gui.BUFFER_SCALE)
								and pixelY == int(inputs.mouse.y / gui.BUFFER_SCALE)
							) or (
								true -- // options.trapMouse > 1
								and pixelX == gui.BUFFER_HALF_W
								and pixelY == gui.BUFFER_HALF_H
							)
						) and intersectedBlock ~= blocks.BLOCK_WATER then
							selectedPass = true
							coordPass = blockRayPosition
							blockSelectOffset = {x = 0, y = 0, z = 0}

							local bullshit = 1 - 2 * (f27 > 0 and 1 or 0)

							if blockFace == 0 then
								blockSelectOffset.x = bullshit
							elseif blockFace == 1 then
								blockSelectOffset.y = bullshit
							elseif blockFace == 2 then
								blockSelectOffset.z = bullshit
							end

							f26 = f33
						end

						if pixelColor > 0 then
							finalPixelColor = pixelColor
							pixelMist = 255 - int(f33 / effectDrawDistance * 255)
							pixelShade = 255 - (blockFace + 2) % 3 * 50
							rayDistanceLimit = f33
						end
					end

					f34 = f34 + f29
					f35 = f35 + f30
					f36 = f36 + f31
					f33 = f33 + f28
				end
			end

			if true --[[options.trapMouse > 1]] and ((pixelX == gui.BUFFER_HALF_W and abs(gui.BUFFER_HALF_H - pixelY) < 4) or (pixelY == gui.BUFFER_HALF_H and abs(gui.BUFFER_HALF_W - pixelX) < 4)) then
				finalPixelColor = 0x1000000 - finalPixelColor
			end

			if finalPixelColor > 0 then
				setColor(
					canvas,
					rshift(band(rshift(finalPixelColor, 16), 0xFF) * pixelShade, 8),
					rshift(band(rshift(finalPixelColor, 8), 0xFF) * pixelShade, 8),
					rshift(band(finalPixelColor, 0xFF) * pixelShade, 8),
					(options.fogType == 1 and sqrt(pixelMist) * 16 or pixelMist)
				)
			else
				setColor(canvas, unpack(color))
			end

			gui.points(canvas, pixelX, pixelY)
		end
	end

	if headInWater then
		setColor(canvas, 16, 32, 255, 128)
		gui.fill_rect(canvas, backgroundRect)
	end

	blockSelected = selectedPass
	blockSelect = coordPass

	inputs.mouse.x = inputs.mouse.x / gui.BUFFER_SCALE
	inputs.mouse.y = inputs.mouse.y / gui.BUFFER_SCALE

	gameLoop.drawPopup(canvas, inputs)
	-- // and there we have it folks, the end of this nonsense
end

function gameLoop.drawPopup(canvas, inputs)
	if gamePopup ~= 0 then
		-- // SDL_SetRelativeMouseMode(0)
	end

	if gamePopup == popup.POPUP_HUD then
		if guiOn then
			popup.hud(
				canvas, inputs, world, debugOn, fps_now, player
			)
		end
	elseif gamePopup == popup.POPUP_PAUSE then
		setColor(canvas, 0, 0, 0, 128)
		gui.fill_rect(canvas, backgroundRect)
		gamePopup, gameState = popup.pause(canvas, inputs, gamePopup, gameState, world)
	elseif gamePopup == popup.POPUP_OPTIONS then
		setColor(canvas, 0, 0, 0, 128)
		gui.fill_rect(canvas, backgroundRect)
		gamePopup = popup.options(canvas, inputs, gamePopup)
	elseif gamePopup == popup.POPUP_INVENTORY then
		gamePopup = popup.inventory(canvas, inputs, player, gamePopup)
	elseif gamePopup == popup.POPUP_ADVANCED_DEBUG then
		setColor(canvas, 0, 0, 0, 128)
		gui.fill_rect(canvas, backgroundRect)
		gamePopup = popup.debugTools(canvas, inputs, gamePopup)
	elseif gamePopup == popup.POPUP_CHUNK_PEEK then
		setColor(canvas, 0, 0, 0, 128)
		gui.fill_rect(canvas, backgroundRect)
		gamePopup = popup.chunkPeek(canvas, inputs, world, gamePopup, player)
	elseif gamePopup == popup.POPUP_ROLL_CALL then
		setColor(canvas, 0, 0, 0, 128)
		gui.fill_rect(canvas, backgroundRect)
		gamePopup = popup.rollCall(canvas, inputs, world, gamePopup)
	elseif gamePopup == popup.POPUP_OVERVIEW then
		setColor(canvas, 0, 0, 0, 128)
		gui.fill_rect(canvas, backgroundRect)
		gamePopup = popup.overview(canvas, inputs, world, gamePopup)
	elseif gamePopup == popup.POPUP_CHAT then
		popup.chat(canvas, inputs, world.time)
	end
end

function gameLoop.processMovement(inputs, inWater)
	player.vectorH.x = sin(player.hRot)
	player.vectorH.y = cos(player.hRot)
	player.vectorV.x = sin(player.vRot)
	player.vectorV.y = cos(player.vRot)

	local options = options.options
	flipFlop = not flipFlop

	local doPhysics = not inWater or flipFlop

	if gamePopup == 0 then
		if options.trapMouse > 0 then
			player.hRot = player.hRot + (inputs.mouse.x / 64)
			player.vRot = player.vRot + (inputs.mouse.y / 64)
		else
			-- // uncomment this if you want to look with keys rather than your mouse
			player.vRot = player.vRot + ((inputs.keyboard.i and 1 or 0) / (100 - options.lookSpeed))
			player.vRot = player.vRot + ((inputs.keyboard.k and -1 or 0) / (100 - options.lookSpeed))

			player.hRot = player.hRot + ((inputs.keyboard.j and -1 or 0) / (100 - options.lookSpeed))
			player.hRot = player.hRot + ((inputs.keyboard.l and 1 or 0) / (100 - options.lookSpeed))

			--[[
			local cameraMoveX = (inputs.mouse.x - gui.BUFFER_W * 2) / gui.BUFFER_W * 2
			local cameraMoveY = (inputs.mouse.y - gui.BUFFER_H * 2) / gui.BUFFER_H * 2
			local cameraMoveDistance = max(sqrt(cameraMoveX * cameraMoveX + cameraMoveY * cameraMoveY) - 1.2, 0)

			if cameraMoveDistance > 0 then
				player.hRot = player.hRot + (cameraMoveX * cameraMoveDistance / 400)
				player.vRot = player.vRot - (cameraMoveY * cameraMoveDistance / 400)
			end
			]]
		end

		player.vRot = min(max(player.vRot, -1.57), 1.57)

		local speed = .02

		if doPhysics then
			player.FBVelocity = ((inputs.keyboard.w and 1 or 0) - (inputs.keyboard.s and 1 or 0)) * speed
			player.LRVelocity = ((inputs.keyboard.d and 1 or 0) - (inputs.keyboard.a and 1 or 0)) * speed
		end
	end

	if doPhysics then
		playerMovement.x = playerMovement.x / 2
		playerMovement.y = playerMovement.y * .99
		playerMovement.z = playerMovement.z / 2

		playerMovement.y = playerMovement.y + .003
		playerMovement.x = playerMovement.x + (player.vectorH.x * player.FBVelocity + player.vectorH.y * player.LRVelocity)
		playerMovement.z = playerMovement.z + (player.vectorH.y * player.FBVelocity - player.vectorH.x * player.LRVelocity)
	end

	for axis = 0, 2 do
		if not doPhysics then
			break
		end

		local playerPosTry = {
			x = player.pos.x + playerMovement.x * ((axis + 2) % 3 / 2),
			y = player.pos.y + playerMovement.y * ((axis + 1) % 3 / 2),
			z = player.pos.z + playerMovement.z * ((axis + 3) % 3 / 2)
		}

		local stopCheck

		for step = 0, 11 do
			local blockX = floor(playerPosTry.x + band(rshift(step, 0), 1) * .6 - .3)
			local blockY = floor(playerPosTry.y + (rshift(step, 2) - 1) * .8 + .65)
			local blockZ = floor(playerPosTry.z + band(rshift(step, 1), 1) * .6 - .3)

			local block = World.getBlock(world, blockX, blockY, blockZ)
			local shouldCollide = block ~= blocks.BLOCK_AIR and block ~= blocks.BLOCK_WATER and block ~= blocks.BLOCK_TALL_GRASS

			if shouldCollide then
				if axis ~= 1 then
					stopCheck = true
					break
				end

				if inputs.keyboard.space and (playerMovement.y > 0) and gamePopup == 0 then
					playerMovement.y = -.1
					stopCheck = true
					break
				end

				playerMovement.y = 0
				stopCheck = true
				break
			end
		end

		if not stopCheck then
			playerPosTry.y = player.pos.y + playerMovement.y * ((axis + 1) % 3 / 2)
			player.pos.x = playerPosTry.x
			player.pos.y = playerPosTry.y
			player.pos.z = playerPosTry.z
		end
	end

	if inWater and doPhysics then
		if inputs.keyboard.space and playerMovement.y > -.05 and gamePopup == 0 then
			playerMovement.y = -.1
		end
	end
end

return gameLoop