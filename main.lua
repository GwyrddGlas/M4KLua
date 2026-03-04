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

local dt = 0
local wheelY = 0
local mouseX = 0
local mouseY = 0
local recent_text
local recent_key
local key_presses = {}
local mouse_presses = {}
local keyboard = compat.isDown
local lg = love.graphics

local inputs = {}

function love.wheelmoved(w, y)
	wheelY = y
end

function love.mousepressed(_, _, b)
	mouse_presses[b] = true
end

function love.mousemoved(x, y, dx, dy)
	mouseX = x
	mouseY = y
end

function love.textinput(k)
	recent_text = string.byte(k)
end

function love.keypressed(k, _, rep)
	if k == "backspace" then
		recent_key = 8
	elseif k == "return" then
		recent_key = 13
	end
	if not rep then
		key_presses[k] = true
	end
end

function love.keyreleased(k)
	key_presses[k] = nil
end

local function buildInputs()
	inputs = { keyboard = {}, mouse = {} }

	inputs.keySym = recent_key
	inputs.keyTyped = recent_text

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

	local to_check = {
		"f1", "f2", "f3", "f4",
		"e", "t", "f", "n", "m", "0", "1",
		"2", "3", "4", "5", "6",
		"7", "8", "9"
	}

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
end

function love.load()
	love.keyboard.setTextInput(true)

	print("init M4Klua")
	love.window.setTitle("M4KLua")
	-- love.window.setMode(gui.WINDOW_W, gui.WINDOW_H)

	print("init data")
	data.init()

	print("init options")
	options.init()

	print("init textures")
	textures.genTextures(45390874)
end

function love.update(delta)
	dt = delta
	buildInputs()

	-- Clean up single-frame inputs
	wheelY = 0
	recent_text = nil
	recent_key = nil
	for i = 1, 3 do
		mouse_presses[i] = nil
	end
end

function love.draw()
     local stats = love.graphics.getStats()

	 gameloop.gameLoop(dt, inputs)
	 
	lg.setColor(1, 1, 1, 1)
    lg.printf("FPS: " .. love.timer.getFPS() ..
    "\nRam: " .. tostring(math.floor(collectgarbage("count") / 1024) + 100) .. " MB" ..
    "\nVRam: " .. tostring(math.floor(stats.texturememory / 1024 / 1024)) .. " MB" ..
    "\nDrawCalls: " .. tostring(math.floor(stats.drawcalls)),
    5, 12, lg.getWidth(), "left")
	
end