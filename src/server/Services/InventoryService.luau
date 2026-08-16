-- Server-authoritative carried ore, measured in kilograms.
--
-- The inventory IS the weight: {oreId -> kg}. No separate unit count and no
-- per-item objects, so capacity checks are a sum and saves stay small.
--
-- The table lives on the saved profile (DataService), not in a local cache, so
-- what the player sees and what gets written are the same object.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OreData = require(ReplicatedStorage.Shared.Data.OreData)
local GearData = require(ReplicatedStorage.Shared.Data.GearData)
local DataService = require(script.Parent.DataService)

local InventoryService = {}

-- Masses are floats; round to grams so display and arithmetic never disagree
-- by a rounding hair.
local PRECISION = 1000

local inventoryUpdated = ReplicatedStorage.Remotes.InventoryUpdated

local function round(mass)
	return math.floor(mass * PRECISION + 0.5) / PRECISION
end

local EMPTY = {}

function InventoryService.Get(player)
	local data = DataService.Get(player)

	if data == nil then
		return EMPTY
	end

	return data.Inventory
end

function InventoryService.GetGear(player)
	local data = DataService.Get(player)

	if data == nil then
		return GearData.Get(GearData.StartingGearId)
	end

	return GearData.Get(data.GearId)
end

function InventoryService.SetGear(player, gearId)
	local data = DataService.Get(player)
	if data == nil then
		return
	end

	data.GearId = gearId
	InventoryService.Push(player)
end

function InventoryService.GetCapacity(player)
	return InventoryService.GetGear(player).CapacityKg
end

function InventoryService.GetWeight(player)
	local total = 0

	for _, mass in pairs(InventoryService.Get(player)) do
		total = total + mass
	end

	return round(total)
end

function InventoryService.GetFreeSpace(player)
	return math.max(0, InventoryService.GetCapacity(player) - InventoryService.GetWeight(player))
end

function InventoryService.CanFit(player, massKg)
	return InventoryService.GetFreeSpace(player) >= massKg
end

-- Adds up to massKg and returns how much actually fit. Partial adds are
-- correct here: a 4.7 kg chunk into 2.0 kg of space gives 2.0 kg, which is
-- what "your bag is nearly full" should mean.
function InventoryService.Add(player, oreId, massKg)
	if massKg <= 0 or OreData.ById[oreId] == nil then
		return 0
	end

	local data = DataService.Get(player)
	if data == nil then
		return 0
	end

	local space = InventoryService.GetFreeSpace(player)
	if space <= 0 then
		return 0
	end

	local added = round(math.min(massKg, space))
	if added <= 0 then
		return 0
	end

	data.Inventory[oreId] = round((data.Inventory[oreId] or 0) + added)

	InventoryService.Push(player)
	return added
end

-- Removes up to massKg and returns how much was actually taken, so callers
-- price exactly what they received rather than what they asked for.
function InventoryService.Remove(player, oreId, massKg)
	local data = DataService.Get(player)
	if data == nil then
		return 0
	end

	local held = data.Inventory[oreId] or 0

	if held <= 0 or massKg <= 0 then
		return 0
	end

	local taken = round(math.min(held, massKg))
	local left = round(held - taken)

	if left <= 0.0005 then
		data.Inventory[oreId] = nil
	else
		data.Inventory[oreId] = left
	end

	InventoryService.Push(player)
	return taken
end

function InventoryService.Clear(player)
	local data = DataService.Get(player)
	if data == nil then
		return
	end

	data.Inventory = {}
	InventoryService.Push(player)
end

function InventoryService.Push(player)
	local gear = InventoryService.GetGear(player)

	inventoryUpdated:FireClient(player, {
		Items = InventoryService.Get(player),
		Weight = InventoryService.GetWeight(player),
		Capacity = gear.CapacityKg,
		GearName = gear.DisplayName,
		GearId = gear.Id,
		SwingSeconds = gear.SwingSeconds,
	})
end

function InventoryService.Start()
	DataService.OnLoaded(function(player)
		InventoryService.Push(player)
	end)

	print("InventoryService: started.")
end

return InventoryService
