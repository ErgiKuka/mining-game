-- Depth hazard.
--
-- Damage is a PURE FUNCTION OF DEPTH BELOW THE SURFACE. It reads one number
-- off a position and knows nothing about tiers, zones, or map layout. Reshape
-- the caves, add a fourth layer, dig to Y = -2000, switch to terrain - none of
-- it touches this file. That independence is deliberate: hazard tuning and map
-- work must never block each other.
--
-- Shared so the client can render the same curve it is being damaged by,
-- without a remote per tick. The server applies damage independently; the
-- client only draws.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Hazard = {}

function Hazard.GetDepth(position)
	return math.max(0, GameConfig.Surface.Y - position.Y)
end

-- Damage per second before gear resistance. Zero above the threshold, then
-- rising faster than linearly, so each tier down is meaningfully worse rather
-- than proportionally worse.
function Hazard.GetBaseDamage(depth)
	local hazard = GameConfig.Hazard
	local excess = depth - hazard.StartDepth

	if excess <= 0 then
		return 0
	end

	return hazard.Coefficient * (excess / hazard.Scale) ^ hazard.Exponent
end

function Hazard.GetDamage(depth, resistance)
	return Hazard.GetBaseDamage(depth) * (resistance or 1)
end

-- 0..1, for the heat gauge. Normalised against the deepest damage the player
-- could currently be taking, so the bar always means the same thing.
function Hazard.GetHeatRatio(depth, resistance)
	local damage = Hazard.GetDamage(depth, resistance)
	return math.clamp(damage / GameConfig.Hazard.MaxDisplayDamage, 0, 1)
end

-- Seconds to death at this depth from full health, for the warning readout.
function Hazard.GetSurvivalSeconds(depth, resistance, health)
	local damage = Hazard.GetDamage(depth, resistance)

	if damage <= 0 then
		return math.huge
	end

	return (health or 100) / damage
end

-- Percentage of carried ore lost on death, scaling with how deep it happened.
function Hazard.GetOreLossFraction(depth)
	local hazard = GameConfig.Hazard
	local excess = math.max(0, depth - hazard.StartDepth)

	return math.clamp(
		hazard.MinOreLoss + excess / hazard.OreLossScale,
		hazard.MinOreLoss,
		hazard.MaxOreLoss
	)
end

return Hazard
