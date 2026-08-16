-- Single source of truth for world dimensions and tier tuning.
-- The generators, node scatter, and (later) the map all read from here.
-- Changing a value means regenerating.

local GameConfig = {}

GameConfig.Grid = {
	CellSize = 32,          -- one tunnel kit piece
	CorridorWidth = 16,     -- normal passage width
	ChamberWidth = 28,      -- wide cells; nearly fills the grid cell
	ChamberChance = 0.22,   -- share of ordinary cells promoted to chambers
	WallThickness = 2,
}

GameConfig.Tiers = {
	[1] = {
		Name = "Surface Cut",
		FloorY = 0,
		CorridorHeight = 14,
		NodesPerCell = 2,
		RichNodesPerCell = 5,
	},
	[2] = {
		Name = "Deep Seam",
		FloorY = -160,
		CorridorHeight = 12,
		NodesPerCell = 3,
		RichNodesPerCell = 6,
	},
	[3] = {
		Name = "The Scald",
		FloorY = -340,
		CorridorHeight = 9,     -- lower ceiling; deliberately oppressive
		NodesPerCell = 3,
		RichNodesPerCell = 7,
	},
}

-- The above-ground hub. Tier 0 in elevator terms: its Down anchor pairs with
-- tier 1's Up anchor, so the mine entrance works like every other lift.
GameConfig.Surface = {
	Y = 90,                 -- clear of tier 1's ceiling
	PlazaRadius = 230,
	PlazaThickness = 6,

	HeadframeRadius = 26,   -- the lift structure at plaza centre
	HeadframeHeight = 34,

	PlotCount = 6,
	PlotRingRadius = 150,
	PlotSize = 46,

	BuildingRingRadius = 78, -- shop and market sit between pit and plots

	MountainRingRadius = 330,
	MountainCount = 26,
}

-- Depth hazard. Damage is a pure function of depth below Surface.Y, so these
-- numbers are the whole tuning surface - no per-tier or per-zone values.
--
-- Reference points with the current curve (resistance 1.0, 100 health):
--   Tier 1  (depth  90)  no damage
--   Tier 2  (depth 250)  ~1.29 dps -> ~77s
--   Tier 3  (depth 430)  ~4.29 dps -> ~23s
-- Gear resistance multiplies that: Tungsten (0.35) survives ~67s at tier 3.
--
-- Ore loss: ~44% at tier 2, capped 90% at tier 3. Set MaxOreLoss to 1.0 for a
-- full wipe if partial salvage still reads as too forgiving.
GameConfig.Hazard = {
	StartDepth = 120,        -- no damage above this depth
	Scale = 100,             -- studs per unit of the curve
	Coefficient = 0.9,       -- damage per second at one Scale below StartDepth
	Exponent = 1.4,          -- >1 so each tier is worse than proportionally
	MaxDisplayDamage = 4.0,  -- heat gauge normalises against this

	RegenPerSecond = 6,      -- only applies where the hazard does not reach
	SafePocketRadius = 22,

	RespawnSeconds = 15,     -- long enough to read the death screen; a button skips it

	MinOreLoss = 0.15,
	MaxOreLoss = 0.9,
	OreLossScale = 450,      -- +1% loss per 4.5 studs past StartDepth
}

-- Cargo securing. Disconnecting while unsecured is treated exactly as dying
-- at the deepest point reached this trip, reusing Hazard.GetOreLossFraction.
GameConfig.Cargo = {
	SecureSeconds = 10,
}

GameConfig.Elevator = {
	DescendHoldSeconds = 0.5,
	AscendHoldSeconds = 3.0,
}

GameConfig.Player = {
	HeadlampRange = 26,
	HeadlampBrightness = 1.6,
	CarryCapacityKg = 50,
}

return GameConfig
