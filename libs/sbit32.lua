local floor = math.floor
local og = bit32 or bit

local bit32 = {}
setmetatable(bit32, {__index = og})

--[[
function bit32.bor(x, disp)
	local y = og.bor(x, disp)

	if y > (2 ^ 32) then
		return y - 2 ^ 32
	else
		return y
	end
end

function bit32.band(...)
	local y = og.band(...)

	if y > (2 ^ 32) then
		return y - 2 ^ 32
	else
		return y
	end
end
]]

function bit32.lshift(x, disp)
	local y = og.lshift(x, disp)

	if x < 0 and not love then
		return y - 2 ^ 32
	else
		return y
	end
end

function bit32.rshift(x, disp)
	local y = og.arshift(x, disp)

	if x < 0 and not love then
		return y - 2 ^ 32
	else
		return y
	end
end

return bit32