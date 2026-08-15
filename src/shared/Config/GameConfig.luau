--!strict

-- Single source of truth for world dimensions.
-- The generator, node placer, and (later) the map all read from here.
-- Changing a value means regenerating the mine — never hardcode these elsewhere.

local GameConfig = {}

GameConfig.Grid = {
	CellSize = 32,        -- one tunnel kit piece
	CorridorWidth = 12,
	CorridorHeight = 10,
	WallThickness = 2,
}

GameConfig.Tiers = {
	-- FloorY drives hazard scaling, so these are gameplay numbers, not art placement.
	[1] = { Name = "Surface Cut", FloorY = 0 },
	[2] = { Name = "Deep Seam", FloorY = -160 },
	[3] = { Name = "The Scald", FloorY = -340 },
}

return GameConfig