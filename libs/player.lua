local data = require("libs/data")
local utils = require("libs/utility")

local Player = {}
Player.ARMOR_SIZE = 4
Player.HOTBAR_SIZE = 9
Player.INVENTORY_ROWS = 3
Player.INVENTORY_SIZE = Player.HOTBAR_SIZE * Player.INVENTORY_ROWS

local InvSlot = {}
local Inventory = {}
Player.InvSlot = InvSlot
Player.Inventory = Inventory

function Player.save(player, path)
	if not data.fileExists(path) then
		data.filesystem:create_file(path)
	end

	data.filesystem:write_file(
		path, string.format(
			"%d\n%16.4f %16.4f %16.4f\n%16.4f %16.4f\n%d %d %d\n%d\n\n",
			0, player.pos.x, player.pos.y, player.pos.z, player.hRot, player.vRot,
			player.health, player.hunger, player.breath, player.xp
		) .. Inventory.save(player.inventory)
	)
end

function Player.load(player, path)
	local file = data.filesystem:read_file(path)

	if not file then
		return 0
	end

	local version = utils.fscanf(file, "%d")

	if version ~= 0 then
		return 2
	end

	local px, py, pz, hr, vr, health, hunger, breath, xp = utils.fscanf(
		file,
		"%f %s %f %s %f\n%f %s %f\n%d %d %d\n%d"
	)

	player.xp = xp
	player.hRot = hr
	player.vRot = vr
	player.pos.x = px
	player.pos.y = py
	player.pos.z = pz
	player.breath = breath
	player.health = health
	player.hunger = hunger
	Inventory.load(file, player.inventory)
end

function Inventory.transferIn(dest, src)
	for i = 0, Player.HOTBAR_SIZE - 1 do
		if dest.hotbar[i].blockid == src.blockid then
			if InvSlot.transfer(dest.hotbar[i], src) then
				return true
			end
		end
	end

	for i = 0, Player.INVENTORY_SIZE - 1 do
        if dest.slots[i].blockid == src.blockid then
            if InvSlot.transfer(dest.slots[i], src) then
                return true
            end
        end
    end

	for i = 0, Player.HOTBAR_SIZE - 1 do
		if dest.hotbar[i].blockid == 0 then
			if InvSlot.transfer(dest.hotbar[i], src) then
				return true
			end
		end
	end

	for i = 0, Player.INVENTORY_SIZE - 1 do
        if dest.slots[i].blockid == 0 then
            if InvSlot.transfer(dest.slots[i], src) then
                return true
            end
        end
    end
end

function Inventory.save(inventory)
	local final = InvSlot.save(inventory.offhand)

	for i = 0, Player.HOTBAR_SIZE - 1 do
		final = final .. InvSlot.save(inventory.hotbar[i])
	end

	for i = 0, Player.INVENTORY_SIZE - 1 do
		final = final .. InvSlot.save(inventory.slots[i])
	end

	for i = 0, Player.ARMOR_SIZE - 1 do
		final = final .. InvSlot.save(inventory.armor[i])
	end

	return final .. string.format("%d\n", inventory.hotbarSelect)
end

function Inventory.load(file, inventory)
	InvSlot.load(file, inventory.offhand)

	for i = 0, Player.HOTBAR_SIZE - 1 do
		InvSlot.load(file, inventory.hotbar[i])
	end

	for i = 0, Player.INVENTORY_SIZE - 1 do
		InvSlot.load(file, inventory.slots[i])
	end

	for i = 0, Player.ARMOR_SIZE - 1 do
		InvSlot.load(file, inventory.armor[i])
	end

	utils.fscanf("%d\n", inventory.hotbarSelect)
end

function InvSlot.save(invSlot)
	return string.format("%d %d %d\n", invSlot.blockid, invSlot.amount, invSlot.durability)
end

function InvSlot.load(file, invSlot)
	local blockid, amount, durability = utils.fscanf(file, "%d %d %d\n")

	invSlot.amount = amount
	invSlot.blockid = blockid
	invSlot.durability = durability
end

function InvSlot.transfer(dest, src)
	local want = 64 - dest.amount

	if want > src.amount then
		want = src.amount
	end

	dest.amount = dest.amount + want
	src.amount = src.amount - want

	dest.blockid = src.blockid
	dest.durability = src.durability

	return src.amount == 0
end

function InvSlot.swap(left, right)
	return right, left
end

return Player