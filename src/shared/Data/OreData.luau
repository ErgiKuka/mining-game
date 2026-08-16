-- Ore type definitions.
--
-- Ore is measured in KILOGRAMS, not unit counts. A node holds a rolled mass,
-- and breaking it yields chunks of varying mass, so a drop reads as "+4.7 kg
-- Iron" rather than a counter ticking up.
--
-- Storing mass instead of per-item objects keeps the inventory a flat
-- {oreId -> kg} dictionary: small saves, trivial UI, and carry capacity is
-- the inventory itself rather than a separate calculation. All the variety
-- lives in the drop event, which is where the player actually feels it.
--
-- RockColor is the host stone; OreColor is the vein running through it. A
-- node is mostly rock with the ore showing through, not a solid block of
-- metal.

local OreData = {}

OreData.Types = {
	{
		Id = "Stone",
		DisplayName = "Stone",
		ValuePerKg = 2,
		NodeMassMin = 4,
		NodeMassMax = 8,
		HitsToDeplete = 4,
		RockColor = Color3.fromRGB(122, 118, 112),
		OreColor = Color3.fromRGB(158, 154, 146),
		OreReflectance = 0,
		SmeltRatio = 0,          -- stone does not smelt
		TierWeights = { [1] = 60, [2] = 25, [3] = 8 },
	},
	{
		Id = "Copper",
		DisplayName = "Copper",
		ValuePerKg = 5,
		NodeMassMin = 5,
		NodeMassMax = 9,
		HitsToDeplete = 6,
		RockColor = Color3.fromRGB(116, 104, 94),
		OreColor = Color3.fromRGB(206, 116, 58),
		OreReflectance = 0.16,
		SmeltRatio = 2.6,        -- kg of raw ore per kg of ingot
		TierWeights = { [1] = 40, [2] = 25, [3] = 10 },
	},
	{
		Id = "Iron",
		DisplayName = "Iron",
		ValuePerKg = 8,
		NodeMassMin = 8,
		NodeMassMax = 14,
		HitsToDeplete = 8,
		RockColor = Color3.fromRGB(104, 100, 98),
		OreColor = Color3.fromRGB(178, 186, 196),
		OreReflectance = 0.22,
		SmeltRatio = 3.2,
		TierWeights = { [2] = 40, [3] = 22 },
	},
	{
		Id = "Silver",
		DisplayName = "Silver",
		ValuePerKg = 26,
		NodeMassMin = 5,
		NodeMassMax = 9,
		HitsToDeplete = 10,
		RockColor = Color3.fromRGB(92, 92, 100),
		OreColor = Color3.fromRGB(226, 232, 240),
		OreReflectance = 0.34,
		SmeltRatio = 4.0,
		TierWeights = { [2] = 10, [3] = 25 },
	},
	{
		Id = "Obsidian",
		DisplayName = "Obsidian",
		ValuePerKg = 22,
		NodeMassMin = 10,
		NodeMassMax = 18,
		HitsToDeplete = 14,
		RockColor = Color3.fromRGB(70, 62, 74),
		OreColor = Color3.fromRGB(46, 34, 66),
		OreReflectance = 0.30,
		SmeltRatio = 2.2,
		TierWeights = { [3] = 35 },
	},
}

OreData.ById = {}
for _, ore in ipairs(OreData.Types) do
	OreData.ById[ore.Id] = ore
end

-- Three breakable stages. The first two drop a modest chunk each; whatever is
-- left goes on the final break, so the last hit is always the big one.
OreData.StageCount = 3
OreData.StageShareMin = 0.15
OreData.StageShareMax = 0.25

function OreData.PickForTier(tier, rng)
	local total = 0
	for _, ore in ipairs(OreData.Types) do
		local w = ore.TierWeights[tier]
		if w ~= nil then
			total = total + w
		end
	end

	if total == 0 then
		return nil
	end

	local roll = rng:NextNumber(0, total)
	local running = 0

	for _, ore in ipairs(OreData.Types) do
		local w = ore.TierWeights[tier]
		if w ~= nil then
			running = running + w
			if roll <= running then
				return ore
			end
		end
	end

	return nil
end

-- Visual size follows mass, so a heavy node genuinely looks worth swinging at.
function OreData.NodeRadius(massKg)
	return 3.2 + massKg * 0.22
end

return OreData
