-- Market pricing.
--
-- Prices are a pure function of the clock, not of stored state. Every server
-- computes the same number for the same 15-minute window with no cross-server
-- traffic, no DataStore budget, and no way to server-hop for a better price.
--
-- Deliberately floor-plus-bonus, never base-minus-penalty: base price is the
-- floor and movement is always upward. A market that pays less the more you
-- play punishes the core loop, and hits new players hardest because everyone
-- mines the entry-tier ore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OreData = require(ReplicatedStorage.Shared.Data.OreData)

local Pricing = {}

Pricing.WindowSeconds = 900          -- 15 minutes
Pricing.MaxDrift = 0.15              -- ambient wobble, 0 to +15%
Pricing.EventBonus = 0.60            -- demand spike on one rotating ore

function Pricing.GetWindow()
	return math.floor(os.time() / Pricing.WindowSeconds)
end

function Pricing.SecondsRemaining()
	return Pricing.WindowSeconds - (os.time() % Pricing.WindowSeconds)
end

-- Which ore is in demand this window. Same input on every server, so the
-- announcement is globally consistent without anyone broadcasting it.
function Pricing.GetEventOreId(window)
	local rng = Random.new(window * 7919)
	local index = rng:NextInteger(1, #OreData.Types)
	return OreData.Types[index].Id
end

function Pricing.GetPrice(oreId, window)
	local ore = OreData.ById[oreId]
	if ore == nil then
		return 0, false
	end

	local currentWindow = window or Pricing.GetWindow()

	-- Seeded per ore per window: deterministic, but uncorrelated between ores.
	local rng = Random.new(currentWindow * 104729 + string.len(oreId) * 31 + string.byte(oreId, 1))
	local drift = rng:NextNumber(0, Pricing.MaxDrift)

	local isEvent = Pricing.GetEventOreId(currentWindow) == oreId
	local bonus = 0

	if isEvent then
		bonus = Pricing.EventBonus
	end

	local price = ore.ValuePerUnit * (1 + drift + bonus)
	return math.max(ore.ValuePerUnit, math.floor(price + 0.5)), isEvent
end

return Pricing
