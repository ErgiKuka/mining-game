-- Server-authoritative carried ore.
--
-- The client never holds the real inventory; it receives a copy for display
-- only. Every mutation happens here, so a modified client can lie about what
-- it wants but not about what it has.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OreData = require(ReplicatedStorage.Shared.Data.OreData)
local GearData = require(ReplicatedStorage.Shared.Data.GearData)

local InventoryService = {}

local inventories = {}
local gearByPlayer = {}

local inventoryUpdated = ReplicatedStorage.Remotes.InventoryUpdated

local function ensure(player)
	if inventories[player] == nil then
		inventories[player] = {}
	end
	return inventories[player]
end

function InventoryService.GetGear(player)
	local id = gearByPlayer[player]
	if id == nil then
		id = GearData.StartingGearId
	end
	return GearData.Get(id)
end

function InventoryService.SetGear(player, gearId)
	gearByPlayer[player] = gearId
	InventoryService.Push(player)
end

function InventoryService.GetCapacity(player)
	return InventoryService.GetGear(player).CapacityKg
end

function InventoryService.GetWeight(player)
	local total = 0

	for oreId, units in pairs(ensure(player)) do
		local ore = OreData.ById[oreId]
		if ore ~= nil then
			total = total + ore.WeightKg * units
		end
	end

	return total
end

-- Whole units only; a partial add would silently destroy ore the player
-- believes they earned, which reads as a bug rather than a limit.
function InventoryService.CanFit(player, oreId, units)
	local ore = OreData.ById[oreId]
	if ore == nil then
		return false
	end

	local added = ore.WeightKg * units
	return InventoryService.GetWeight(player) + added <= InventoryService.GetCapacity(player)
end

function InventoryService.Add(player, oreId, units)
	if units <= 0 then
		return false
	end

	if not InventoryService.CanFit(player, oreId, units) then
		return false
	end

	local inv = ensure(player)
	inv[oreId] = (inv[oreId] or 0) + units
	InventoryService.Push(player)
	return true
end

-- Removes up to `units` and returns how many were actually taken, so callers
-- can price exactly what they received rather than what they asked for.
function InventoryService.Remove(player, oreId, units)
	local inv = ensure(player)
	local held = inv[oreId] or 0

	if held <= 0 or units <= 0 then
		return 0
	end

	local taken = math.min(held, units)
	local left = held - taken

	if left <= 0 then
		inv[oreId] = nil
	else
		inv[oreId] = left
	end

	InventoryService.Push(player)
	return taken
end

function InventoryService.Clear(player)
	inventories[player] = {}
	InventoryService.Push(player)
end

function InventoryService.Get(player)
	return ensure(player)
end

function InventoryService.Push(player)
	local gear = InventoryService.GetGear(player)

	inventoryUpdated:FireClient(player, {
		Items = ensure(player),
		Weight = InventoryService.GetWeight(player),
		Capacity = gear.CapacityKg,
		GearName = gear.DisplayName,
		GearId = gear.Id,
		SwingSeconds = gear.SwingSeconds,
	})
end

function InventoryService.Start()
	Players.PlayerAdded:Connect(function(player)
		ensure(player)
		gearByPlayer[player] = GearData.StartingGearId
		InventoryService.Push(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
		gearByPlayer[player] = nil
	end)

	print("InventoryService: started.")
end

return InventoryService
