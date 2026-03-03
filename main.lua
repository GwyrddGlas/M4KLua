local gui = require("libs/gui")
local data = require("libs/data")
local menus = require("libs/menus")
local compat = require("libs/compat")
local terrain = require("libs/terrain")
local options = require("libs/options")
local textures = require("libs/textures")
local gameloop = require("libs/gameloop")

--[[
	* Minecraft 4k, Lua edition
	* Credits:
	*   notch		- creating the original game
	*   sashakoshka - Creating the C port
]]

local recent
local wheelY = 0
local mouseX = 0
local mouseY = 0
local key_presses = {}
local mouse_presses = {}
local keyboard = compat.isDown

local MAX_FPS = 60
local MIN_FRAME_MILLISECONDS = (1000 / MAX_FPS)

local to_check = {
	"f1", "f2", "f3", "f4",
	"e", "t", "f", "n", "m", "0", "1",
	"2", "3", "4", "5", "6",
	"7", "8","9"
}

function love.wheelmoved(w, y)
	wheelY = y
end

function love.mousepressed(_, _, b)
	mouse_presses[b] = true
end

function love.textinput(k)
	recent = string.byte(k)
end

function love.mousemoved(x, y, dx, dy)
	mouseX = x
	mouseY = y
end

function love.keypressed(k, _, rep)
	if k == "backspace" then
		recent = 8
	elseif k == "return" then
		recent = 13
	end

	if not rep then
		key_presses[k] = true
	end
end

function love.keyreleased(k)
	key_presses[k] = nil
end

function love.load()
	main()
end

local function controlLoop()
	local inputs = {keyboard = {}, mouse = {}}
	inputs.keySym = recent
	inputs.keyTyped = recent

	inputs.keyboard.space = keyboard("space")
	inputs.keyboard.w = keyboard("w")
	inputs.keyboard.s = keyboard("s")
	inputs.keyboard.a = keyboard("a")
	inputs.keyboard.d = keyboard("d")
	inputs.keyboard.i = keyboard("i")
	inputs.keyboard.j = keyboard("j")
	inputs.keyboard.k = keyboard("k")
	inputs.keyboard.l = keyboard("l")

	inputs.keyboard.esc = key_presses["escape"]
	key_presses["escape"] = nil

	for _, v in pairs(to_check) do
		inputs.keyboard[tonumber(v) and "num" .. v or v] = key_presses[v]
		key_presses[v] = nil
	end

	inputs.keyboard.e_fix = inputs.keyboard.e

	inputs.mouse.x = mouseX
	inputs.mouse.y = mouseY
	inputs.mouse.wheel = wheelY
	inputs.mouse.left = mouse_presses[1]
	inputs.mouse.right = mouse_presses[2]

	return inputs
end

function main()
	print("init M4Klua")
	love.window.setTitle("M4KLua")
	love.window.setMode(gui.WINDOW_W, gui.WINDOW_H)

	print("init data")
	data.init()

	print("init options")
	options.init()

	print("init textures")
	textures.genTextures(45390874)

	local gameStart = os.clock()

	love.draw = function()
		local frameStartTime = os.clock() - gameStart
		gameloop.gameLoop(nil, controlLoop())

		-- // clean up inputs
		wheelY = 0

		if recent then
			recent = nil
		end

		for i = 1, 3 do
			mouse_presses[i] = nil
		end

		local frameDuration = (os.clock() - gameStart) - frameStartTime

		if frameDuration < MIN_FRAME_MILLISECONDS then
			love.timer.sleep((MIN_FRAME_MILLISECONDS - frameDuration * 1000) / 1000)
		end
	end
end