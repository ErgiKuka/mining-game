-- Ore type definitions. Values mirror the economy model spreadsheet;
-- change them together or the model stops predicting the game.
--
-- TierWeights are spawn weights per mine tier, not probabilities.
-- A tier absent from the table means that ore never spawns there.

local OreData = {}

OreData.Types = {
	{
		Id = "Stone",
		DisplayName = "Stone",
		WeightKg = 1.0,
		ValuePerUnit = 2,
		UnitsPerNode = 5,
		HitsToDeplete = 4,
		Color = Color3.fromRGB(140, 138, 132),
		NodeSize = 4.5,
		TierWeights = { [1] = 60, [2] = 25, [3] = 8 },
	},
	{
		Id = "Copper",
		DisplayName = "Copper",
		WeightKg = 1.5,
		ValuePerUnit = 8,
		UnitsPerNode = 4,
		HitsToDeplete = 6,
		Color = Color3.fromRGB(196, 112, 62),
		NodeSize = 4.5,
		TierWeights = { [1] = 40, [2] = 25, [3] = 10 },
	},
	{
		Id = "Iron",
		DisplayName = "Iron",
		WeightKg = 2.5,
		ValuePerUnit = 20,
		UnitsPerNode = 4,
		HitsToDeplete = 8,
		Color = Color3.fromRGB(150, 158, 168),
		NodeSize = 5,
		TierWeights = { [2] = 40, [3] = 22 },
	},
	{
		Id = "Silver",
		DisplayName = "Silver",
		WeightKg = 2.0,
		ValuePerUnit = 45,
		UnitsPerNode = 3,
		HitsToDeplete = 10,
		Color = Color3.fromRGB(214, 220, 228),
		NodeSize = 5,
		TierWeights = { [2] = 10, [3] = 25 },
	},
	{
		Id = "Obsidian",
		DisplayName = "Obsidian",
		WeightKg = 4.0,
		ValuePerUnit = 90,
		UnitsPerNode = 3,
		HitsToDeplete = 14,
		Color = Color3.fromRGB(48, 40, 62),
		NodeSize = 5.5,
		TierWeights = { [3] = 35 },
	},
}

-- Index by Id for O(1) lookup from the mining service.
OreData.ById = {}
for _, ore in ipairs(OreData.Types) do
	OreData.ById[ore.Id] = ore
end

-- Weighted pick for a given tier. rng is a Random so generation stays
-- deterministic per cell; pass the cell-seeded generator, not math.random.
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

return OreData
