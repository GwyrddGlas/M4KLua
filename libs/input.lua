local input = {}

local SDLK_RETURN = 13
local SDLK_BACKSPACE = 8

function input.insert(original, substring, offset)
	assert(not (offset < 1 or offset > #(original)), "offset is out of bounds")

	local newString = original:sub(1, offset) .. substring .. original:sub(offset + 1)

	return newString
end

function input.manageInputBuffer(inputBuffer, inputs)
	if not inputs.keyTyped or not inputs.keySym then
		return
	end

	if inputs.keySym == SDLK_BACKSPACE and inputBuffer.cursor > 0 then
		inputBuffer.buffer = inputBuffer.buffer:sub(1, #(inputBuffer.buffer) - 1)
		inputBuffer.cursor = inputBuffer.cursor - 1
	elseif inputs.keySym == SDLK_RETURN and inputBuffer.cursor > 0 then
		return 1
	elseif inputs.keyTyped > 31 and inputs.keyTyped < 127 and inputBuffer.cursor < inputBuffer.len then
		-- // inputBuffer.buffer = input.insert(inputBuffer.buffer, string.char(inputs.keyTyped), inputBuffer.cursor)
		inputBuffer.buffer = inputBuffer.buffer:sub(1, inputBuffer.cursor) .. string.char(inputs.keyTyped)
		inputBuffer.cursor = inputBuffer.cursor + 1
		-- // inputBuffer.buffer = input.insert(inputBuffer.buffer, "", inputBuffer.cursor)
	end
end

return input