local compat = require("libs/compat")
local texts = require("libs/textures")
local blocks = require("libs/blocks")
local utils = require("libs/utility")
local bit = require("libs/sbit32")
local font = require("libs/font")

local flash = 0
local band = bit.band
local rshift = bit.rshift

local min = math.min
local abs = math.abs
local ceil = math.ceil
local nmod = utils.nmod
local floor = math.floor

local utf8 = utf8 or require("utf8")
local codepoint = utf8.codepoint

local BUFFER_W = 214
local BUFFER_H = 120
local BUFFER_SCALE = 4
local BUFFER_HALF_W = BUFFER_W / 2
local BUFFER_HALF_H = BUFFER_H / 2
local WINDOW_W = BUFFER_W * BUFFER_SCALE
local WINDOW_H = BUFFER_H * BUFFER_SCALE

local chatHistory = {}
local chatHistoryIndex = 0
local chatStartingFade = 150
local chatHistoryFade = utils.create_array(11, chatStartingFade)

local setColor = compat.setColor
local BLOCK_DIRT = blocks.BLOCK_DIRT

local gui = {}
gui.BUFFER_W = BUFFER_W
gui.BUFFER_H = BUFFER_H
gui.WINDOW_W = WINDOW_W
gui.WINDOW_H = WINDOW_H
gui.BUFFER_SCALE = BUFFER_SCALE
gui.BUFFER_HALF_W = BUFFER_HALF_W
gui.BUFFER_HALF_H = BUFFER_HALF_H

gui.chatHistory = chatHistory
gui.chatHistoryFade = chatHistoryFade
gui.chatHistoryIndex = chatHistoryIndex

local sign = math.sign or function(x)
	if x ~= 0 then
		return (x < 0 and -1 or 1)
	else
		return 0
	end
end

local function fill_rect(canvas, rect)
	compat.rectangle(
		canvas,
		rect.x * BUFFER_SCALE,
		rect.y * BUFFER_SCALE,
		rect.w * BUFFER_SCALE,
		rect.h * BUFFER_SCALE
	)
end

local function draw_rect(canvas, rect, inset)
	local x, y, w, h = rect.x, rect.y, rect.w, rect.h

	if not inset then
		x = x - 1
		y = y - 1
		w = w + 2
		h = h + 2
	end

	for yy = 0, h - 1 do
		for xx = 0, w - 1 do
			if xx == 0 or yy == 0 or xx == w - 1 or yy == h - 1 then
				gui.points(canvas, x + xx, y + yy)
			end
		end
	end
end

local function draw_line(canvas, tx, ty, fx, fy)
	local inverted = false

	local x, y = fx, fy

	local dx, dy = tx - fx, ty - fy
	local step = sign(dx)
	local gstep = sign(dy)

	local longest = abs(dx)
	local shortest = abs(dy)

	if longest < shortest then
		inverted = true
		longest = abs(dy)
		shortest = abs(dx)

		step = sign(dy)
		gstep = sign(dx)
	end

	local accum = longest / 2

	for _ = 1, longest do
		gui.points(canvas, x, y)

		if inverted then
			y = y + step
		else
			x = x + step
		end

		accum = accum + shortest

		if accum >= longest then
			if inverted then
				x = x + gstep
			else
				y = y + gstep
			end

			accum = accum - longest
		end
	end
end

function gui.points(canvas, ...)
	local scale = BUFFER_SCALE
	local n = select("#", ...)

	for i = 1, n, 2 do
		local x = select(i, ...) * scale
		local y = select(i + 1, ...) * scale
		compat.rectangle(canvas, x, y, scale, scale)
	end
end

function gui.drawChar(canvas, c, x, y)
	c = codepoint(c)

	for yy = 0, 7 do
		for xx = 0, 7 do
			if bit.band(bit.rshift(font[c + 1][yy + 1], (7 - xx)), 0x1) > 0 then
				gui.points(canvas, x + xx, y + yy)
			end
		end
	end

	return font[c + 1][9]
end

function gui.drawStr(canvas, str, x, y)
	local i = 1

	while i <= #(str) do
		x = x + gui.drawChar(canvas, str:sub(i, i), x, y)
		i = i + 1
	end

	return x
end

function gui.shadowStr(canvas, str, x, y)
	setColor(canvas, 77, 77, 77)
	gui.drawStr(canvas, str, x + 1, y + 1)

	setColor(canvas, 255, 255, 255)
	return gui.drawStr(canvas, str, x, y)
end

function gui.centerStr(canvas, str, x, y)
	x = x * 2

	local i = 1

	while i <= #(str) do
		x = x - font[codepoint(str:sub(i, i)) + 1][9]
		i = i + 1
	end

	x = x / 2
	i = 1

	while i <= #(str) do
		x = x + gui.drawChar(canvas, str:sub(i, i), x, y)
		i = i + 1
	end

	return x
end

function gui.shadowCenterStr(canvas, str, x, y)
	setColor(canvas, 77, 77, 77)
	gui.centerStr(canvas, str, x + 1, y + 1)

	setColor(canvas, 255, 255, 255)
	return gui.centerStr(canvas, str, x, y)
end

function gui.redShadowCenterStr(canvas, str, x, y)
	setColor(canvas, 128, 64, 64)
	gui.centerStr(canvas, str, x + 1, y + 1)

	setColor(canvas, 255, 128, .128)
	return gui.centerStr(canvas, str, x, y)
end

function gui.drawBig(canvas, str, x, y)
	local i = 1

	while i <= #(str) do
		x = x - font[codepoint(str:sub(i, i)) + 1][9]
		i = i + 1
	end

	i = 1

	while i <= #(str) do
		local c = codepoint(str:sub(i, i))
		i = i + 1

		for yy = 0, 15 do
			for xx = 0, 15 do
				if bit.band(bit.rshift(font[c + 1][floor(yy / 2) + 1], (7 - floor(xx / 2))), 0x1) > 0 then
					gui.points(canvas, x + xx, y + yy)
				end
			end
		end

		x = x + font[c + 1][9] * 2
	end
end

function gui.drawBigShadow(canvas, str, x, y)
	setColor(canvas, 77, 77, 77)
	gui.drawBig(canvas, str, x + 1, y + 1)

	setColor(canvas, 255, 255, 255)
	return gui.drawBig(canvas, str, x, y)
end

function gui.drawBGStr(canvas, str, x, y, t)
	t = min(t or 50, 50)

	local i = 1
	local len = 1
	local bg = {x = x, y = y, w = 0, h = 9}

	while i <= #(str) do
		len = len + font[codepoint(str:sub(i, i)) + 1][9]
		i = i + 1
	end

	bg.w = len
	setColor(canvas, 0, 0, 0, (t / 50) * 128)
	fill_rect(canvas, bg)

	setColor(canvas, 255, 255, 255, (t / 50) * 255)
	return gui.drawStr(canvas, str, x + 1, y + 1)
end

function gui.button(canvas, str, x, y, w, mouseX, mouseY)
	local rect = {x = x, y = y, w = w, h = 16}
	local hover = (mouseX >= x and mouseY >= y and mouseX < x + w and mouseY < y + 16)

	if hover then
		setColor(canvas, 116, 134, 230)
	else
		setColor(canvas, 139, 139, 139)
	end

	fill_rect(canvas, rect)
	x = x + (w / 2) + 1
	y = y + 5

	if hover then
		setColor(canvas, 63, 63, 40)
	else
		setColor(canvas, 56, 56, 56)
	end

	gui.centerStr(canvas, str, x, y)
	x = x - 1
	y = y - 1

	if hover then
		setColor(canvas, 255, 255, 160)
	else
		setColor(canvas, 255, 255, 255)
	end

	gui.centerStr(canvas, str, x, y)

	if hover then
		setColor(canvas, 255, 255, 255)
	else
		setColor(canvas, 0, 0, 0)
	end

	draw_rect(canvas, rect)

	return hover
end

function gui.input(canvas, placeholder, buffer, x, y, w, mouseX, mouseY, active)
	local rect = {x = x, y = y, w = w, h = 16}
	local hover = (mouseX >= x and mouseY >= y and mouseX < x + w and mouseY < y + 16)

	setColor(canvas, 0, 0, 0)
	fill_rect(canvas, rect)

	if hover or active then
		setColor(canvas, 255, 255, 255)
	else
		setColor(canvas, 139, 139, 139)
	end

	draw_rect(canvas, rect)

	local textX = x + 4

	if #(buffer) > 0 then
		setColor(canvas, 255, 255, 255)
		textX = gui.drawStr(canvas, buffer, x + 4, y + 4)
	elseif not active then
		setColor(canvas, 63, 63, 63)
		gui.drawStr(canvas, placeholder, x + 4, y + 4)
	end

	if flash < 32 and active then
		setColor(canvas, 255, 255, 255)
		gui.drawChar(canvas, "_", textX, y + 4)
	end

	if active then
		flash = flash + 1
		flash = flash % 64
	end

	return hover
end

function gui.scrollbar(canvas, x, y, length, mouseX, mouseY, mouseLeft, level, max)
	local sectionLength = (length / max)
	local background = {x = x, y = y, w = 4, h = length}
	local foreground = {x = x, y = level * sectionLength, w = 4, h = ceil(sectionLength)}

	local hover = (mouseX >= background.x and mouseY >= background.y and mouseX < background.x + background.w and mouseY < background.y + background.h)

	if hover and mouseLeft then
		level = (mouseY - background.y) / sectionLength
	end

	setColor(canvas, 0, 0, 0, 128)
	fill_rect(canvas, background)

	setColor(canvas, 200, 200, 200)
	fill_rect(canvas, foreground)

	setColor(canvas, 139, 139, 139)

	draw_line(canvas,
		foreground.x + foreground.w - 1,
		foreground.y,
		foreground.x + foreground.w - 1,
		foreground.y + foreground.h - 1
	)

	return level
end

function gui.drawSlot(canvas, slot, x, y, mouseX, mouseY)
	local count = ""
	local hover = (mouseX >= x and mouseY >= y and mouseX < x + 16 and mouseY < y + 16)

	if slot.amount == 0 then
		return hover
	end

	local i = slot.blockid * 256 * 3

	for yy = 0, 15 do
		for xx = 0, 15 do
			local color = texts.textures[
				i + texts.BLOCK_TEXTURE_H *
				texts.BLOCK_TEXTURE_W
			]

			setColor(
				canvas,
				band(rshift(color, 16), 0xFF),
				band(rshift(color, 8), 0xFF),
				band(color, 0xFF)
			)

			if color > 0 then
				gui.points(canvas, x + xx, y + yy)
			end

			i = i + 1
		end
	end

	gui.shadowStr(canvas, utils.strnum(count, 0, slot.amount), x + (slot.amount >= 10 and 4 or 10), y + 8)

	return hover
end

function gui.drawWorldListItem(canvas, item, x, y, mouseX, mouseY)
	local hover = (mouseX >= x and mouseY >= y and mouseX < x + 128 and mouseY < y + 16)
	hover = (hover and 1 or 0)

	local rect = {x = x - 1, y = y - 1, w = 130, h = 18}
	local thumbnailShadow = {x = x + 1, y = y + 1, w = 16, h = 16}

	setColor(canvas, 0, 0, 0, 128)
	fill_rect(canvas, thumbnailShadow)

	local pixel = 0
	local thumbnail = item.thumbnail

	for yy = 0, 15 do
		for xx = 0, 15 do
			local color = thumbnail[pixel]

			setColor(
				canvas,
				band(rshift(color, 16), 0xFF),
				band(rshift(color, 8), 0xFF) ,
				band(color, 0xFF)
			)

			gui.points(canvas, x + xx, y + yy)
			pixel = pixel + 1
		end
	end

	gui.shadowStr(canvas, item.name, x + 20, y + 4)

	if gui.button(canvas, "x", x + 128 - 16, y, 16, mouseX, mouseY) then
		hover = 2
	end

	if hover == 1 then
		setColor(canvas, 255, 255, 255)
		draw_rect(canvas, rect)
	end

	return hover
end

local function renderDirtToCanvas(canvas)
	love.graphics.setCanvas(canvas)

	for y = 0, BUFFER_H - 1 do
		for x = 0, BUFFER_W - 1 do
			local color = texts.textures[(
				band(x, 0xF) +
				band(y, 0xF) * 16 +
				BLOCK_DIRT * 256 * 3
			)]

			setColor(
				canvas,
				rshift(band(rshift(color, 16), 0xFF), 1),
				rshift(band(rshift(color, 8), 0xFF), 1),
				rshift(band(color, 0xFF), 1)
			)

			compat.rectangle(canvas, x, y, 1, 1)
		end
	end

	love.graphics.setCanvas()
end

function gui.dirtBg(canvas)
	for y = 0, BUFFER_H - 1 do
		for x = 0, BUFFER_W - 1 do
			local color = texts.textures[(
				band(x, 0xF) +
				band(y, 0xF) * 16 +
				BLOCK_DIRT * 256 * 3
			)]

			setColor(
				canvas,
				rshift(band(rshift(color, 16), 0xFF), 1),
				rshift(band(rshift(color, 8), 0xFF), 1),
				rshift(band(color, 0xFF), 1)
			)

			gui.points(canvas, x, y)
		end
	end
end

function gui.loadScreen(canvas, str, prog, max)
	gui.dirtBg(canvas)
	gui.shadowCenterStr(canvas, str, BUFFER_HALF_W, BUFFER_HALF_H - 8)

	setColor(canvas, 77, 77, 77)

	draw_line(canvas,
		BUFFER_HALF_W - 32,
		BUFFER_HALF_H + 6,
		BUFFER_HALF_W + 32,
		BUFFER_HALF_H + 6
	)

	setColor(canvas, 132, 255, 132)

	draw_line(canvas,
		BUFFER_HALF_W - 32,
		BUFFER_HALF_H + 6,
		BUFFER_HALF_W - 32 + (prog / max) * 64,
		BUFFER_HALF_H + 6
	)
end

function gui.chatAdd(str)
	chatHistory[chatHistoryIndex] = str
	chatHistoryFade[chatHistoryIndex] = chatStartingFade

	chatHistoryIndex = chatHistoryIndex + 1
	chatHistoryIndex = nmod(chatHistoryIndex, 11)
	gui.chatHistoryIndex = chatHistoryIndex
end

gui.fill_rect = fill_rect
gui.draw_rect = draw_rect
gui.draw_line = draw_line

return gui