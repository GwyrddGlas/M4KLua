local gui = require("libs/gui")
local data = require("libs/data")
local _input = require("libs/input")
local blocks = require("libs/blocks")
local utils = require("libs/utility")
local compat = require("libs/compat")
local _player = require("libs/player")
local texts = require("libs/textures")
local terrain = require("libs/terrain")
local options = require("libs/options")

local flash = 0
local scroll = 0
local badName = false
local chunkPeekRYMax = 0
local badUserName = false
local World = terrain.World
local Chunk = terrain.Chunk

local page = 0
local typeSelect = 1
local whichInput = -1
local chunkLoadNum = 0
local nameInput = false
local dayNightSelect = 0

local chatBox = {
	len = 64,
	cursor = 0,
	buffer = ""
}

local bit = require("libs/sbit32")
local utf8 = utf8 or require("utf8")
local codepoint = utf8.codepoint

local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local min = math.min
local max = math.max
local floor = math.floor

local int = utils.int
local nmod = utils.nmod
local strnum = utils.strnum
local zero_index = utils.zero_index

local chatHistory = gui.chatHistory
local chatHistoryFade = gui.chatHistoryFade

local input = gui.input
local button = gui.button
local drawStr = gui.drawStr
local drawChar = gui.drawChar
local drawSlot = gui.drawSlot
local scrollbar = gui.scrollbar
local shadowStr = gui.shadowStr
local centerStr = gui.centerStr
local drawBGStr = gui.drawBGStr
local loadScreen = gui.loadScreen
local drawBigShadow = gui.drawBigShadow
local shadowCenterStr = gui.shadowCenterStr
local redShadowCenterStr = gui.redShadowCenterStr

local points = gui.points
local dirtBg = gui.dirtBg
local chatAdd = gui.chatAdd
local draw_line = gui.draw_line
local draw_rect = gui.draw_rect
local fill_rect = gui.fill_rect
local drawWorldListItem = gui.drawWorldListItem

local BUFFER_W = gui.BUFFER_W
local BUFFER_H = gui.BUFFER_H
local BUFFER_SCALE = gui.BUFFER_SCALE
local BUFFER_HALF_W = gui.BUFFER_HALF_W
local BUFFER_HALF_H = gui.BUFFER_HALF_H

local fovTexts = {
	"FOV: Low",
	"FOV: Medium",
	"FOV: High",
	"FOV: ?"
}

local fogTexts = {
	"Fog: Gradual",
	"Fog: Sharp"
}

local terrainNames = {
	"Classic Terrain",
	"Natural Terrain",
	"Flat Stone",
	"Flat Grass",
	"Water World"
}

local dayNightModes = {
	"Day and Night",
	"Always Day",
	"Always Night"
}

local trapMouseTexts = {
	"Capture Mouse: OFF",
	"Capture Mouse: ON"
}

fovTexts = zero_index(fovTexts)
fogTexts = zero_index(fogTexts)
terrainNames = zero_index(terrainNames)
dayNightModes = zero_index(dayNightModes)

local menus = {}
local menu = {}

local state = {}
state.STATE_TITLE = 0
state.STATE_ABOUT = 1
state.STATE_SELECT_WORLD = 2
state.STATE_NEW_WORLD = 3
state.STATE_LOADING = 4
state.STATE_GAMEPLAY = 5
state.STATE_EDIT_WORLD = 6
state.STATE_JOIN_GAME = 7
state.STATE_OPTIONS = 8

state.nameBuffer = ""
state.seedBuffer = ""

state.seedInput = {
	len = 16,
	cursor = 0,
	buffer = state.seedBuffer,
}

state.nameInput = {
	len = 16,
	cursor = 0,
	buffer = state.nameBuffer
}

local popup = {}
popup.POPUP_HUD = 0
popup.POPUP_PAUSE = 1
popup.POPUP_OPTIONS = 2
popup.POPUP_INVENTORY = 3
popup.POPUP_ADVANCED_DEBUG = 4
popup.POPUP_CHUNK_PEEK = 5
popup.POPUP_CHAT = 6
popup.POPUP_ROLL_CALL = 7
popup.POPUP_OVERVIEW = 8

menus.menu = menu
menus.state = state
menus.popup = popup

function state.title(canvas, inputs, gameState)
	inputs.mouse.x = inputs.mouse.x / BUFFER_SCALE
	inputs.mouse.y = inputs.mouse.y / BUFFER_SCALE

	dirtBg(canvas)
	compat.setColor(canvas, 255, 255, 255)

	drawBigShadow(
		canvas,
		"M4KLua",
		BUFFER_HALF_W,
		16
	)

	shadowStr(canvas, "version 1.0", 1, BUFFER_H - 9)

	if button(canvas, "Singleplayer", BUFFER_HALF_W - 64, 42, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		if data.refreshWorldList() then
			error("Cannot refresh world list")
		else
			gameState = state.STATE_SELECT_WORLD
		end
	end

	if button(canvas, "Options", BUFFER_HALF_W - 64, 64, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gameState = state.STATE_OPTIONS
	end

	if button(canvas, "Quit Game", BUFFER_HALF_W - 64, 86, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		return true
	end

	return gameState
end

function state.selectWorld(canvas, inputs, gameState, world)
	local scroll = 0
	local needRefresh = false

	if inputs.mouse.wheel ~= 0 then
		scroll = scroll - inputs.mouse.wheel
		inputs.mouse.wheel = 0
	end

	scroll = min(max(scroll, 0), data.worldListLength - 1)

	local listBackground = {x = 0, y = 0, w = BUFFER_W, h = BUFFER_H - 28}

	inputs.mouse.x = inputs.mouse.x / BUFFER_SCALE
	inputs.mouse.y = inputs.mouse.y / BUFFER_SCALE

	dirtBg(canvas)
	compat.setColor(canvas, 0, 0, 0, 128)
	fill_rect(canvas, listBackground)
	draw_line(canvas, 0, BUFFER_H - 29, BUFFER_W, BUFFER_H - 29)

	local y = 6
	local index = 0
	local yLimit = BUFFER_H - 44

	local item = data.worldList[index]

	while item do
		local break_fr = false

		repeat
			if y > yLimit then
				break_fr = true
				break
			end

			if index < scroll then
				break
			end

			local hover = drawWorldListItem(canvas, item, BUFFER_HALF_W - 64, y, inputs.mouse.x, inputs.mouse.y)
			y = y + 21

			if not inputs.mouse.left then
				break
			end

			if hover == 1 then
				local err = World.load(world, item.name)

				if err then
					error("Could not load world: " .. tostring(err))
				else
					gameState = state.STATE_LOADING
					return gameState, world
				end
			elseif hover == 2 then
				local deletePath = data.getWorldPath(item.name)

				if not deletePath then
					error("Could not delete world")
				end

				data.removeDirectory(deletePath)
				needRefresh = true
			end
		until true

		if break_fr then
			break
		end

		index = index + 1
		item = data.worldList[index]
	end

	if 6 + index * 22 > yLimit then
		scrollbar(
			canvas,
			BUFFER_HALF_W + 70, 0, BUFFER_H - 29,
			inputs.mouse.x, inputs.mouse.y, inputs.mouse.left, scroll, data.worldListLength
		)
	end

	if index == 0 then
		shadowCenterStr(canvas, "No worlds", BUFFER_HALF_W, BUFFER_HALF_H - 15)
	end

	if button(canvas, "Cancel", BUFFER_HALF_W - 64, BUFFER_H - 22, 61, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gameState = state.STATE_TITLE
		scroll = 0
	end

	if button(canvas, "New", BUFFER_HALF_W + 3, BUFFER_H - 22, 61, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gameState = state.STATE_NEW_WORLD
		scroll = 0
	end

	if needRefresh then
		data.refreshWorldList()
	end

	return gameState
end

function state.newWorld(canvas, inputs, gameState, world)
	inputs.mouse.x = inputs.mouse.x / BUFFER_SCALE
	inputs.mouse.y = inputs.mouse.y / BUFFER_SCALE
	dirtBg(canvas)

	if whichInput == 0 then
		_input.manageInputBuffer(state.nameInput, inputs)
	end

	if input(canvas, "Name", state.nameInput.buffer, BUFFER_HALF_W - 64, 8, 128, inputs.mouse.x, inputs.mouse.y, whichInput == 0) and inputs.mouse.left then
		whichInput = 0
	end

	if badName then
		compat.setColor(canvas, 255, 128, 128)
		drawChar(canvas, "!", BUFFER_HALF_W + 70, 12)
	end

	if whichInput == 1 then
		_input.manageInputBuffer(state.seedInput, inputs)
	end

	if input(canvas, "Seed", state.seedInput.buffer, BUFFER_HALF_W - 64, 30, 128, inputs.mouse.x, inputs.mouse.y, whichInput == 1) and inputs.mouse.left then
		whichInput = 1
	end

	if button(canvas, terrainNames[typeSelect], BUFFER_HALF_W - 64, 52, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		typeSelect = (typeSelect + 1) % 5
	end

	if button(canvas, dayNightModes[dayNightSelect], BUFFER_HALF_W - 64, 74, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		dayNightSelect = (dayNightSelect + 1) % 3
	end

	if button(canvas, "Cancel", BUFFER_HALF_W - 64, 96, 61, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gameState = state.STATE_SELECT_WORLD
	end

	if button(canvas, "Generate", BUFFER_HALF_W + 3, 96, 61, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		if #(state.nameInput.buffer) <= 0 then
			badName = true
			whichInput = -1
			return gameState
		end

		if state.nameInput.buffer:match("[^%w%s]+") then
			badName = true
			whichInput = -1
			return gameState
		end

		if not data.getWorldPath(state.nameInput.buffer) then
			badName = true
			whichInput = -1
			return gameState
		end

		World.wipe(world)
		world.path = data.getWorldPath(state.nameInput.buffer)

		if world.path and data.directoryExists(world.path) then
			badName = true
			whichInput = -1
			return gameState
		end

		world.time = 2048
		world.type = typeSelect
		world.dayNightMode = dayNightSelect

		world.seed = 0

		for i = 1, #(state.seedInput.buffer) do
			world.seed = world.seed * 10
			world.seed = world.seed + codepoint(state.seedInput.buffer:sub(i, i)) - 48
		end

		if world.seed == 0 then
			world.seed = os.time() % 999999999999999
		end

		-- // secret world for testing nonsense. seed's "dev"
		if world.seed == 5800 then
			world.type = -1
		end

		badName = false
		whichInput = -1

		-- // state.nameInput.len = 0
		state.nameInput.cursor = 0
		state.nameInput.buffer = ""

		-- // state.seedInput.len = 0
		state.seedInput.cursor = 0
		state.seedInput.buffer = ""

		gameState = state.STATE_LOADING
	end

	return gameState
end

function state.loading(canvas, world, seed, center)
	local chunkLoadCoords = {}

	if chunkLoadNum < Chunk.CHUNKARR_SIZE then
		chunkLoadCoords.x = int(
			((chunkLoadNum % Chunk.CHUNKARR_DIAM) -
			Chunk.CHUNKARR_RAD) * 64
		)

		chunkLoadCoords.y = int(
			((int(chunkLoadNum / Chunk.CHUNKARR_DIAM) % Chunk.CHUNKARR_DIAM) - Chunk.CHUNKARR_RAD) * 64
		)

		chunkLoadCoords.z = int(
			(int(chunkLoadNum / (Chunk.CHUNKARR_DIAM ^ 2)) - Chunk.CHUNKARR_RAD) * 64
		)

		terrain.genChunk(
			world, seed,
			chunkLoadCoords.x,
			chunkLoadCoords.y,
			chunkLoadCoords.z, world.type, true,
			center
		)

		loadScreen(
			canvas,
			"Generating world...",
			chunkLoadNum, Chunk.CHUNKARR_SIZE
		)

		chunkLoadNum = chunkLoadNum + 1
	else
		chunkLoadNum = 0
		terrain.World.sort(world)
		return true
	end
end

function state.options(canvas, inputs, gameState)
	inputs.mouse.x = inputs.mouse.x / BUFFER_SCALE
	inputs.mouse.y = inputs.mouse.y / BUFFER_SCALE
	dirtBg(canvas)

	if menu.optionsMain(canvas, inputs) then
		gameState = 0
	end

	return gameState
end

-- // state_egg in C port
-- // i have no idea what this is but it has a funny name so i'm going to add it

function state.egg(canvas, inputs, gameState)
	inputs.mouse.x = inputs.mouse.x / BUFFER_SCALE
	inputs.mouse.y = inputs.mouse.y / BUFFER_SCALE
	dirtBg(canvas)

	compat.setColor(canvas, 255, 255, 255)
	centerStr(
		canvas,
		"Go away, this is my house.",
		BUFFER_HALF_W, BUFFER_HALF_H - 16
	)

	if button(canvas, "Ok", BUFFER_HALF_W - 64, BUFFER_HALF_H, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gameState = state.STATE_TITLE
	end

	return gameState
end

-- // state_err is just the same as state_egg but slightly different ui positioning

function state.err(canvas, inputs, message)
	inputs.mouse.x = inputs.mouse.x / BUFFER_SCALE
	inputs.mouse.y = inputs.mouse.y / BUFFER_SCALE
	dirtBg(canvas)

	compat.setColor(canvas, 255, 255, 255)

	centerStr(
		canvas,
		"Error:",
		BUFFER_HALF_W, BUFFER_HALF_H - 20
	)

	centerStr(
		canvas,
		message,
		BUFFER_HALF_W, BUFFER_HALF_H - 4
	)

	if button(canvas, "Ok", BUFFER_HALF_W - 64, BUFFER_HALF_H + 16, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		return
	end

	return true
end

-- [[ === INGAME POPUPS === ]] --

function popup.hud(canvas, inputs, world, debugOn, fps_now, player)
	local hotbarRect = {x = BUFFER_HALF_W - 77, y = BUFFER_H - 18, w = 154, h = 18}
	local hotbarSelectRect = {x = 0, y = hotbarRect.y, w = 18, h = 18}
	local offhandRect = {x = 0, y = BUFFER_H - 18, w = 18, h = 18}

	if debugOn then
		local debugText = {
			"M4KLua 1.0",
			"Seed: ",
			"X: ",
			"Y: ",
			"Z: ",
			"FPS: ",
			"chunkX: ",
			"chunkY: ",
			"chunkZ: "
		}

		debugText[2] = strnum(debugText[2], 6, world.seed)

		debugText[3] = strnum(debugText[3], 3, floor(player.pos.x))
		debugText[4] = strnum(debugText[4], 3, floor(player.pos.y))
		debugText[5] = strnum(debugText[5], 3, floor(player.pos.z))

		debugText[6] = strnum(debugText[6], 5, fps_now)

		debugText[7] = strnum(debugText[7], 8, rshift(floor(player.pos.x), 6))
		debugText[8] = strnum(debugText[8], 8, rshift(floor(player.pos.y), 6))
		debugText[9] = strnum(debugText[9], 8, rshift(floor(player.pos.z), 6))

		for i = 1, 9 do
			drawBGStr(canvas, debugText[i], 0, i * 9)
		end

		local CHUNKMONW = 10
		local CHUNKMONCOL = 9
		local chunkMonitorRect = {x = 0, y = 1 - CHUNKMONW, w = CHUNKMONW, h = CHUNKMONW}

		for i = 0, Chunk.CHUNKARR_SIZE - 1 do
			if i % CHUNKMONCOL == 0 then
				chunkMonitorRect.x = BUFFER_W - (CHUNKMONW * (CHUNKMONCOL - 1)) + 2
				chunkMonitorRect.y = chunkMonitorRect.y + CHUNKMONW - 1
			else
				chunkMonitorRect.x = chunkMonitorRect.x + CHUNKMONW - 1
			end

			local stamp = world.chunk[i].loaded

			compat.setColor(
				canvas,
				band(stamp, 0x03) * 64,
				band(stamp, 0x0C) * 16,
				band(stamp, 0x30) * 4
			)

			fill_rect(canvas, chunkMonitorRect)

			compat.setColor(canvas, 255, 255, 255)
			draw_rect(canvas, chunkMonitorRect)
		end
	end

	compat.setColor(canvas, 0, 0, 0, 128)
	fill_rect(canvas, hotbarRect)

	for i = 0, 8 do
		drawSlot(
			canvas,
			player.inventory.hotbar[i],
			BUFFER_HALF_W - 76 + i * 17,
			BUFFER_H - 17,
			inputs.mouse.x,
			inputs.mouse.y
		)
	end

	if player.inventory.offhand.blockid ~= 0 then
		compat.setColor(canvas, 0, 0, 0, 128)

		draw_rect(canvas, offhandRect)
		drawSlot(
			canvas,
			player.inventory.offhand,
			1,
			BUFFER_H - 17,
			inputs.mouse.x,
			inputs.mouse.y
		)
	end

	hotbarSelectRect.x = BUFFER_HALF_W - 77 + player.inventory.hotbarSelect * 17
	compat.setColor(canvas, 255, 255, 255)
	draw_rect(canvas, hotbarSelectRect, true)

	-- // chat
	local chatDrawIndex = gui.chatHistoryIndex

	for i = 0, 10 do
		chatDrawIndex = nmod(chatDrawIndex - 1, 11)

		if chatHistoryFade[chatDrawIndex] > 0 and chatHistory[chatDrawIndex] then
			chatHistoryFade[chatDrawIndex] = chatHistoryFade[chatDrawIndex] - 1

			drawBGStr(
				canvas,
				chatHistory[chatDrawIndex],
				0, BUFFER_H - 32 - i * 9, chatHistoryFade[chatDrawIndex]
			)
		elseif chatHistory[chatDrawIndex] then
			chatHistory[chatDrawIndex] = nil
		end
	end
end

function popup.manageInvSlot(canvas, inputs, x, y, current, selected, dragging)
	if drawSlot(canvas, current, x, y, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		inputs.mouse.left = nil

		if dragging then
			if current.blockid == 0 then
				dragging = false
				current = selected
				selected = {blockid = 0, durability = 0, amount = 0}
			elseif current.blockid == selected.blockid then
				_player.InvSlot.transfer(current, selected)
			else
				current, selected = _player.InvSlot.swap(current, selected)
			end
		elseif current.blockid ~= 0 then
			dragging = true
			selected = current
			current = {blockid = 0, durability = 0, amount = 0}
		end
	end

	return current, selected, dragging
end

local dragging = false
local selected = {blockid = 0, amount = 0, durability = 0}

function popup.inventory(canvas, inputs, player, gamePopup)
	local inventoryRect = {x = BUFFER_HALF_W - 77, y = (BUFFER_H - 18) / 2 - 26, w = 154, h = 52}
	local hotbarRect = {x = BUFFER_HALF_W - 77, y = BUFFER_H - 18, w = 154, h = 18}
	local offhandRect = {x = 0, y = BUFFER_H - 18, w = 18, h = 18}

	compat.setColor(canvas, 0, 0, 0, 128)
	fill_rect(canvas, inventoryRect)
	fill_rect(canvas, hotbarRect)
	fill_rect(canvas, offhandRect)

	for i = 0, _player.HOTBAR_SIZE - 1 do
		player.inventory.hotbar[i], selected, dragging = popup.manageInvSlot(
			canvas, inputs,
			BUFFER_HALF_W - 76 + i * 17,
			BUFFER_H - 17,
			player.inventory.hotbar[i],
			selected,
			dragging
		)
	end

	for i = 0, _player.INVENTORY_SIZE - 1 do
		player.inventory.slots[i], selected, dragging = popup.manageInvSlot(
			canvas, inputs,
			BUFFER_HALF_W - 76 + (i % _player.HOTBAR_SIZE) * 17,
			inventoryRect.y + 1 + int(i / _player.HOTBAR_SIZE) * 17,
			player.inventory.slots[i],
			selected,
			dragging
		)
	end

	player.inventory.offhand, selected, dragging = popup.manageInvSlot(
		canvas, inputs, 1,
		BUFFER_H - 17,
		player.inventory.offhand,
		selected,
		dragging
	)

	if dragging then
		drawSlot(
			canvas, selected,
			inputs.mouse.x - 8,
			inputs.mouse.y - 8,
			0, 0
		)
	end

	if inputs.keyboard.e_fix then
		inputs.keyboard.e_fix = nil
		gamePopup = popup.POPUP_HUD
	end

	return gamePopup
end

function popup.chat(canvas, inputs, gameTime)
	local chatBoxRect = {x = 0, y = BUFFER_H - 9, w = BUFFER_W, h = 9}

	local chatDrawIndex = gui.chatHistoryIndex

	for i = 0, 10 do
		chatDrawIndex = nmod(chatDrawIndex - 1, 11)

		if chatHistoryFade[chatDrawIndex] > 0 and chatHistory[chatDrawIndex] then
			chatHistoryFade[chatDrawIndex] = chatHistoryFade[chatDrawIndex] - 1

			drawBGStr(
				canvas,
				chatHistory[chatDrawIndex],
				0, BUFFER_H - 32 - i * 9, chatHistoryFade[chatDrawIndex]
			)
		elseif chatHistory[chatDrawIndex] then
			chatHistory[chatDrawIndex] = nil
		end
	end

	if _input.manageInputBuffer(chatBox, inputs) then
		-- // 63 - max chatbox length
		-- // 7 - max username length
		-- // 2: ": " chars
		-- // 1: null

		local chatNameConcat = string.sub(("%s: %s"):format(options.options.username.buffer, chatBox.buffer), 1, 63 + 7 + 2 + 1)

		if chatBox.buffer == "/help" or string.sub(chatBox.buffer, 1, 6) == "/help " then
			chatAdd("Keybinds:")
			chatAdd("WASD - move")
			chatAdd("IJKL - look")
			chatAdd("E - inventory, T - chat")
			chatAdd("f1 - toggle hud")
			chatAdd("f2 - screenshot (WIP)")
			chatAdd("f3 - debug")
			chatAdd("f4 - chunk debug")
		else
			chatAdd(chatNameConcat)
		end

		chatBox.cursor = 0
		chatBox.buffer = ""
	end

	if chatBox.cursor == 63 then
		compat.setColor(canvas, 128, 0, 0, 128)
	else
		compat.setColor(canvas, 0, 0, 0, 128)
	end

	fill_rect(canvas, chatBoxRect)
	compat.setColor(canvas, 255, 255, 255)

	local x = drawStr(
		canvas, chatBox.buffer,
		0, BUFFER_H - 8
	)

	if flash < 8 then
		drawChar(
			canvas,
			"_",
			x,
			BUFFER_H - 8
		)
	end

	flash = flash + 1
	flash = flash % 16
end

function popup.pause(canvas, inputs, gamePopup, gameState, world)
	if button(canvas, "Back to Game", BUFFER_HALF_W - 64, 20, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gamePopup = popup.POPUP_HUD
	end

	if button(canvas, "Options...", BUFFER_HALF_W - 64, 42, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gamePopup = popup.POPUP_OPTIONS
	end

	if button(canvas, "Save and Quit", BUFFER_HALF_W - 64, 64, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		local err = terrain.World.save(world)

		if err then
			error("Could not save world")
			return
		end

		gameState = state.STATE_TITLE
		terrain.World.wipe(world)
	end

	return gamePopup, gameState
end

function popup.options(canvas, inputs, gamePopup)
	if menu.optionsMain(canvas, inputs) then
		gamePopup = 1
	end

	return gamePopup
end

function popup.debugTools(canvas, inputs, gamePopup)
	if button(canvas, "Chunk Peek", BUFFER_HALF_W - 64, 20, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gamePopup = popup.POPUP_CHUNK_PEEK
	end

	if button(canvas, "All Chunks", BUFFER_HALF_W - 64, 42, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gamePopup = popup.POPUP_ROLL_CALL
	end

	if button(canvas, "World Overview", BUFFER_HALF_W - 64, 64, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gamePopup = popup.POPUP_OVERVIEW
	end

	if button(canvas, "Done", BUFFER_HALF_W - 64, 86, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gamePopup = popup.POPUP_HUD
	end

	return gamePopup
end

function popup.chunkPeek(canvas, inputs, world, gamePopup, player)
	local chunkPeekText = {
		"coordHash: ",
		"loaded: "
	}

	local debugChunk = terrain.chunkLookup(
		world,
		floor(player.pos.x),
		floor(player.pos.y),
		floor(player.pos.z)
	)

	compat.setColor(canvas, 255, 255, 255)

	if debugChunk then
		chunkPeekText[1] = strnum(chunkPeekText[1], 11, debugChunk.coordHash)
		chunkPeekText[2] = strnum(chunkPeekText[2], 8, debugChunk.coordHash)

		for i = 1, 2 do
			drawStr(canvas, chunkPeekText[i], 0, lshift(i - 1, 3))
		end

		if inputs.mouse.wheel ~= 0 then
			chunkPeekRYMax = chunkPeekRYMax - inputs.mouse.wheel
			chunkPeekRYMax = nmod(chunkPeekRYMax, 64)
			inputs.mouse.wheel = 0
		end

		if inputs.mouse.x > 128 and inputs.mouse.y < 64 and inputs.mouse.left then
			chunkPeekRYMax = inputs.mouse.y
		end

		if button(canvas, "UP", 4, 56, 64, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
			chunkPeekRYMax = nmod(chunkPeekRYMax - 1, 64)
		end

		if button(canvas, "DOWN", 4, 78, 64, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
			chunkPeekRYMax = nmod(chunkPeekRYMax + 1, 64)
		end

		compat.setColor(canvas, 255, 255, 255)
		draw_line(canvas, 128, chunkPeekRYMax, 191, chunkPeekRYMax)

		for chunkPeekRY = 64, chunkPeekRYMax, -1 do
			for chunkPeekRX = 0, 63 do
				for chunkPeekRZ = 0, 62 do
					local currentBlock = debugChunk.blocks[
						chunkPeekRX +
						lshift(chunkPeekRY, 6) +
						lshift(chunkPeekRZ, 12)
					]

					local chunkPeekColor = texts.textures[currentBlock * 256 * 3 + 6 * 16]

					if chunkPeekColor and chunkPeekColor > 0 then
						compat.setColor(
							canvas,
							band(rshift(chunkPeekColor, 16), 0xFF),
							band(rshift(chunkPeekColor, 8), 0xFF),
							band(chunkPeekColor, 0xFF),
							(currentBlock == blocks.BLOCK_WATER and 64 or 255)
						)

						points(canvas, chunkPeekRX + 128, chunkPeekRY + chunkPeekRZ)

						compat.setColor(canvas, 0, 0, 0, 64)
						points(canvas, chunkPeekRX + 128, chunkPeekRY + chunkPeekRZ + 1)
					end
				end
			end
		end
	else
		drawStr(canvas, "Chunk not found", 0, 0)
	end

	if button(canvas, "Done", 4, 100, 64, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gamePopup = popup.POPUP_ADVANCED_DEBUG
	end

	return gamePopup
end

function popup.rollCall(canvas, inputs, world, gamePopup)
	if inputs.mouse.wheel ~= 0 then
		scroll = scroll + inputs.mouse.wheel
		inputs.mouse.wheel = 0
	end

	scroll = max(min(scroll, 0), 1 - Chunk.CHUNKARR_SIZE)

	compat.setColor(canvas, 255, 255, 255)
	drawStr(canvas, "x    y    z   stmp    hash", 8, 10)

	for index = 0, Chunk.CHUNKARR_SIZE - 1 do
		repeat
			local topMargin = 28
			local chunk = world.chunk[index]
			local y = (index + scroll) * 8 + topMargin

			if y < topMargin or y >= BUFFER_H then
				break
			end

			drawStr(canvas, ("%i"):format(chunk.center.x - 32), 0, y)
			drawStr(canvas, ("%i"):format(chunk.center.y - 32), 24, y)
			drawStr(canvas, ("%i"):format(chunk.center.z - 32), 48, y)

			drawStr(canvas, ("#%i"):format(chunk.loaded), 72, y)
			drawStr(canvas, ("#%016x"):format(chunk.coordHash), 96, y)
		until true
	end

	if button(canvas, "Done", BUFFER_W - 6 - 32, 6, 32, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gamePopup = popup.POPUP_ADVANCED_DEBUG
	end

	return gamePopup
end

function popup.overview(canvas, inputs, world, gamePopup)
	local worldEndingBound = int(Chunk.CHUNK_SIZE * (Chunk.CHUNKARR_RAD + 1))
	local worldStartingBound = int(Chunk.CHUNK_SIZE * Chunk.CHUNKARR_RAD * -1)

	for y = worldEndingBound, worldStartingBound + 1, -4 do
		for x = worldStartingBound, worldEndingBound - 1, 4 do
			for z = worldStartingBound, worldEndingBound - 1, 4 do
				local projectX = int((x - z) / 4)
				local projectY = int((int((x + z) / 2) + y) / 4)

				local color
				local alpha = 255
				local currentBlock = World.getBlock(world, x, y, z)

				if currentBlock < blocks.NUMBER_OF_BLOCKS then
					color = texts.textures[currentBlock * 256 * 3 + 6 * 16]
				else
					color = 0xFF0000
					alpha = 0
				end

				if color ~= 0 then
					if currentBlock == blocks.BLOCK_WATER then
						alpha = 64
					end

					compat.setColor(
						canvas,
						band(rshift(color, 16), 0xFF),
						band(rshift(color, 8), 0xFF),
						band(color, 0xFF),
						alpha
					)

					points(canvas, projectX + BUFFER_HALF_W, projectY + 32)
				end
			end
		end
	end

	if button(canvas, "Done", BUFFER_W - 6 - 32, 6, 32, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		gamePopup = popup.POPUP_ADVANCED_DEBUG
	end

	return gamePopup
end

function menu.optionsMain(canvas, inputs)
	if badUserName then
		redShadowCenterStr(canvas, "Bad username!", BUFFER_HALF_W, 6)
	end

	if page == 0 then
		if nameInput then
			_input.manageInputBuffer(options.options.username, inputs)
		end

		if input(
			canvas, "Username", options.options.username.buffer,
			BUFFER_HALF_W - 64, 20, 128,
			inputs.mouse.x, inputs.mouse.y, nameInput
		) and inputs.mouse.left then
			nameInput = true
		end

		if button(canvas, trapMouseTexts[options.options.trapMouse + 1], BUFFER_HALF_W - 64, 42, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
			options.options.trapMouse = ((options.options.trapMouse + 1) % 2)
		end

		local lookSpeedText = ("Keyboard look speed: %i"):format(options.options.lookSpeed)

		if button(canvas, lookSpeedText, BUFFER_HALF_W - 64, 64, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
			local cases = {
				[10] = 25,
				[25] = 40,
				[40] = 50,
				[50] = 70,
				[70] = 25
			}

			options.options.lookSpeed = cases[options.options.lookSpeed]
		end
	elseif page == 1 then
		nameInput = false

		local drawDistanceText = ("Draw distance: %i"):format(options.options.drawDistance)

		if button(canvas, drawDistanceText, BUFFER_HALF_W - 64, 20, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
			local cases = {
				[5] = 20,
				[20] = 32,
				[32] = 64,
				[64] = 96,
				[96] = 128,
				[128] = 5
			}

			options.options.drawDistance = cases[options.options.drawDistance]
		end

		local cases = {
			[60] = fovTexts[2],
			[90] = fovTexts[1],
			[140] = fovTexts[0]
		}

		local fovText = cases[options.options.fov] or fovTexts[4]

		if button(canvas, fovText, BUFFER_HALF_W - 64, 42, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
			local cases = {
				[60] = 140,
				[90] = 60,
				[140] = 90
			}

			options.options.fov = cases[options.options.fov]
		end

		if button(canvas, fogTexts[options.options.fogType], BUFFER_HALF_W - 64, 64, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
			options.options.fogType = (options.options.fogType == 0 and 1 or 0)
		end
	end

	if button(canvas, "<", BUFFER_HALF_W - 86, 20, 16, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		page = nmod(page - 1, 2)
	end

	if button(canvas, ">", BUFFER_HALF_W + 70, 20, 16, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		page = nmod(page + 1, 2)
	end

	if button(canvas, "Done", BUFFER_HALF_W - 64, 86, 128, inputs.mouse.x, inputs.mouse.y) and inputs.mouse.left then
		if #(options.options.username.buffer) <= 0 then
			badUserName = true
			return
		end

		if options.options.username.buffer:match("[^%w%s]+") then
			badUserName = true
			return
		end

		nameInput = false
		badUserName = false

		local err = options.save()

		if err then
			error("Could not save options")
		end

		page = 0
		return true
	end
end

return menus