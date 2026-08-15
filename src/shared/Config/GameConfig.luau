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
