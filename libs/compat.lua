local event = love.event
local mouse = love.mouse
local graphics = love.graphics

local clear = graphics.clear
local setColor = graphics.setColor
local rectangle = graphics.rectangle

local compat = {}
compat.quit = event.quit
compat.isDown = love.keyboard.isDown
compat.setMouse = mouse.setRelativeMode

function compat.clear(canvas, r, g, b, a)
	r = r / 255
	g = g / 255
	b = b / 255
	a = (a or 255) / 255

	clear(r, g, b, a)
end

function compat.setColor(canvas, r, g, b, a)
	r = r / 255
	g = g / 255
	b = b / 255
	a = (a or 255) / 255

	setColor(r, g, b, a)
end

function compat.rectangle(canvas, x, y, w, h)
	rectangle("fill", x, y, w, h)
end

return compat