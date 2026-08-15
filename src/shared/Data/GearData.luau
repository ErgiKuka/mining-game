-- Pickaxe tiers. Costs and capacities mirror the economy model spreadsheet;
-- change them together or the model stops predicting the game.
--
-- Visual fields describe the Part-built greybox pickaxe. Replace with a mesh
-- later; nothing outside PickaxeService reads them.

local GearData = {}

GearData.Tiers = {
	{
		Id = "RustyPick",
		DisplayName = "Rusty Pick",
		Cost = 0,
		SwingSeconds = 1.20,
		CapacityKg = 50,
		DamagePerHit = 1,
		HandleColor = Color3.fromRGB(94, 68, 44),
		HeadColor = Color3.fromRGB(122, 96, 78),
		HeadWidth = 3.2,
	},
	{
		Id = "SteelPick",
		DisplayName = "Steel Pick",
		Cost = 900,
		SwingSeconds = 1.00,
		CapacityKg = 80,
		DamagePerHit = 1,
		HandleColor = Color3.fromRGB(78, 60, 42),
		HeadColor = Color3.fromRGB(168, 176, 186),
		HeadWidth = 3.6,
	},
	{
		Id = "ReinforcedPick",
		DisplayName = "Reinforced Pick",
		Cost = 2700,
		SwingSeconds = 0.85,
		CapacityKg = 120,
		DamagePerHit = 1,
		HandleColor = Color3.fromRGB(56, 56, 62),
		HeadColor = Color3.fromRGB(96, 132, 158),
		HeadWidth = 4.0,
	},
	{
		Id = "TungstenPick",
		DisplayName = "Tungsten Pick",
		Cost = 4000,
		SwingSeconds = 0.70,
		CapacityKg = 180,
		DamagePerHit = 1,
		HandleColor = Color3.fromRGB(40, 40, 46),
		HeadColor = Color3.fromRGB(214, 198, 120),
		HeadWidth = 4.4,
	},
	{
		Id = "DiamondPick",
		DisplayName = "Diamond Pick",
		Cost = 15000,
		SwingSeconds = 0.55,
		CapacityKg = 260,
		DamagePerHit = 1,
		HandleColor = Color3.fromRGB(32, 34, 44),
		HeadColor = Color3.fromRGB(120, 226, 226),
		HeadWidth = 4.8,
	},
}

GearData.ById = {}
for index, gear in ipairs(GearData.Tiers) do
	gear.TierIndex = index
	GearData.ById[gear.Id] = gear
end

GearData.StartingGearId = "RustyPick"

function GearData.Get(id)
	local gear = GearData.ById[id]
	if gear == nil then
		return GearData.ById[GearData.StartingGearId]
	end
	return gear
end

return GearData
