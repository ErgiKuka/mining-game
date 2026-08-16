-- Greybox mine generator. Run from the Studio command bar in edit mode:
--   require(game.ServerScriptService.Server.Tools.MineGenerator).Build()
--
-- Idempotent: destroys any previous generation before building.
-- Everything it creates lives under Workspace/GeneratedMine.
--
-- Randomness is SEEDED PER CELL. The same layout always produces the same
-- mine, so regeneration is repeatable and the map stays something you can
-- reason about. Never swap these for math.random.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MineLayout = require(ReplicatedStorage.Shared.Data.MineLayout)
local OreData = require(ReplicatedStorage.Shared.Data.OreData)

local MineGenerator = {}

local GENERATED_FOLDER = "GeneratedMine"
local TAG_ORE_NODE = "OreNode"
local TAG_ELEVATOR = "ElevatorAnchor"

local CHAR_ROCK = "."
local CHAR_RICH = "N"
local CHAR_SPAWN = "S"
local CHAR_DOWN = "D"
local CHAR_UP = "U"

local TIER_COLORS = {
	[1] = Color3.fromRGB(130, 122, 110),
	[2] = Color3.fromRGB(96, 84, 78),
	[3] = Color3.fromRGB(78, 58, 54),
}

local DIRECTIONS = {
	{ dCol = 1, dRow = 0 },
	{ dCol = -1, dRow = 0 },
	{ dCol = 0, dRow = 1 },
	{ dCol = 0, dRow = -1 },
}

local CORNER_SIGNS = {
	{ x = -1, z = -1 },
	{ x = -1, z = 1 },
	{ x = 1, z = -1 },
	{ x = 1, z = 1 },
}

local function cellRng(tier, col, row)
	return Random.new(tier * 1000000 + col * 1000 + row)
end

local function createPart(name, size, cframe, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Slate
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function isTunnel(rows, row, col)
	local line = rows[row]
	if line == nil then
		return false
	end
	if col < 1 or col > string.len(line) then
		return false
	end
	return string.sub(line, col, col) ~= CHAR_ROCK
end

-- Cells are chambers (wide) or corridors (narrow). Rich cells are always
-- chambers so the good ore always sits somewhere that feels like a find.
local function cellWidth(rows, row, col, tier)
	local grid = GameConfig.Grid
	local char = string.sub(rows[row], col, col)

	if char == CHAR_RICH then
		return grid.ChamberWidth
	end

	local rng = cellRng(tier, col, row)
	if rng:NextNumber() < grid.ChamberChance then
		return grid.ChamberWidth
	end

	return grid.CorridorWidth
end

local function buildCell(rows, row, col, tierConfig, tier, color, parent)
	local grid = GameConfig.Grid
	local height = tierConfig.CorridorHeight
	local floorY = tierConfig.FloorY

	local width = cellWidth(rows, row, col, tier)
	local cellHalf = grid.CellSize / 2
	local halfWidth = width / 2
	local rockDepth = cellHalf - halfWidth
	local rockOffset = halfWidth + rockDepth / 2
	local rockCenterY = floorY + height / 2

	local originX = (col - 1) * grid.CellSize
	local originZ = (row - 1) * grid.CellSize

	createPart(
		"Floor",
		Vector3.new(grid.CellSize, grid.WallThickness, grid.CellSize),
		CFrame.new(originX, floorY - grid.WallThickness / 2, originZ),
		color,
		parent
	)

	createPart(
		"Ceiling",
		Vector3.new(grid.CellSize, grid.WallThickness, grid.CellSize),
		CFrame.new(originX, floorY + height + grid.WallThickness / 2, originZ),
		color,
		parent
	)

	if rockDepth > 0.05 then
		for _, sign in ipairs(CORNER_SIGNS) do
			createPart(
				"Corner",
				Vector3.new(rockDepth, height, rockDepth),
				CFrame.new(originX + sign.x * rockOffset, rockCenterY, originZ + sign.z * rockOffset),
				color,
				parent
			)
		end
	end

	-- Solid faces are those with no neighbouring tunnel. They are also the
	-- faces the node scatter can embed rocks into, so collect them.
	local solidFaces = {}

	for _, dir in ipairs(DIRECTIONS) do
		if isTunnel(rows, row + dir.dRow, col + dir.dCol) then
			-- open; nothing to build
		else
			local sizeX = width
			local sizeZ = width

			if dir.dCol ~= 0 then
				sizeX = math.max(rockDepth, grid.WallThickness)
			end
			if dir.dRow ~= 0 then
				sizeZ = math.max(rockDepth, grid.WallThickness)
			end

			local offset = rockOffset
			if rockDepth <= 0.05 then
				offset = halfWidth + grid.WallThickness / 2
			end

			createPart(
				"Wall",
				Vector3.new(sizeX, height, sizeZ),
				CFrame.new(originX + dir.dCol * offset, rockCenterY, originZ + dir.dRow * offset),
				color,
				parent
			)

			table.insert(solidFaces, dir)
		end
	end

	return {
		originX = originX,
		originZ = originZ,
		halfWidth = halfWidth,
		height = height,
		floorY = floorY,
		solidFaces = solidFaces,
	}
end

-- Loose rock along the wall bases. Purely visual, but it does more to break
-- up the boxy look than any amount of geometry cleverness.
local function scatterRubble(cell, color, rng, parent)
	local count = rng:NextInteger(3, 6)

	for _ = 1, count do
		local size = rng:NextNumber(1.5, 4)
		local x = cell.originX + rng:NextNumber(-cell.halfWidth, cell.halfWidth)
		local z = cell.originZ + rng:NextNumber(-cell.halfWidth, cell.halfWidth)

		local part = createPart(
			"Rubble",
			Vector3.new(size, size * 0.6, size),
			CFrame.new(x, cell.floorY + size * 0.25, z)
				* CFrame.Angles(
					rng:NextNumber(-0.3, 0.3),
					rng:NextNumber(0, 6.28),
					rng:NextNumber(-0.3, 0.3)
				),
			color,
			parent
		)
		part.CanCollide = false
	end
end

-- A node is a MODEL built like a real ore deposit: a chunky mass of host rock
-- with veins of ore showing through it. Not a solid block of metal, and not a
-- die on the floor.
--
-- Mass is rolled per node and drives both the visual size and what the node
-- yields, so a big-looking node genuinely is worth more.
local function createOreNode(ore, position, tier, massKg, radius, shapeRng, parent)
	local model = Instance.new("Model")
	model.Name = "OreNode_" .. ore.Id

	local function rock(name, size, offset, tilt, color, material, reflectance)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(position + offset) * tilt
		p.Color = color
		p.Material = material
		p.Reflectance = reflectance or 0
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local function tilt(spread)
		return CFrame.Angles(
			shapeRng:NextNumber(-spread, spread),
			shapeRng:NextNumber(0, 6.28),
			shapeRng:NextNumber(-spread, spread)
		)
	end

	-- Host rock: one broad core plus overlapping boulders, so the silhouette
		-- is lumpy rather than a single shape.
	local core = rock(
		"Core",
		Vector3.new(
			radius * shapeRng:NextNumber(1.5, 1.9),
			radius * shapeRng:NextNumber(1.1, 1.5),
			radius * shapeRng:NextNumber(1.5, 1.9)
		),
		Vector3.zero,
		tilt(0.16),
		ore.RockColor,
		Enum.Material.Slate
	)

	model.PrimaryPart = core

	local boulderCount = shapeRng:NextInteger(3, 5)

	for i = 1, boulderCount do
		local angle = (i / boulderCount) * 6.28 + shapeRng:NextNumber(-0.6, 0.6)
		local dist = radius * shapeRng:NextNumber(0.35, 0.7)
		local scale = shapeRng:NextNumber(0.55, 0.95)

		rock(
			"Rock",
			Vector3.new(
				radius * scale * shapeRng:NextNumber(0.9, 1.3),
				radius * scale * shapeRng:NextNumber(0.7, 1.1),
				radius * scale * shapeRng:NextNumber(0.9, 1.3)
			),
			Vector3.new(
				math.cos(angle) * dist,
				shapeRng:NextNumber(-radius * 0.3, radius * 0.5),
				math.sin(angle) * dist
			),
			tilt(0.5),
			ore.RockColor,
			Enum.Material.Slate
		)
	end

	-- Ore veins: small bright slabs pushed out through the rock face. These are
	-- what tell the player at a glance what they are looking at.
	local veinCount = shapeRng:NextInteger(5, 9)

	for i = 1, veinCount do
		local angle = (i / veinCount) * 6.28 + shapeRng:NextNumber(-0.4, 0.4)
		local dist = radius * shapeRng:NextNumber(0.55, 0.9)
		local scale = shapeRng:NextNumber(0.18, 0.36)

		rock(
			"Vein",
			Vector3.new(
				radius * scale * shapeRng:NextNumber(0.8, 1.6),
				radius * scale * shapeRng:NextNumber(0.6, 1.0),
				radius * scale * shapeRng:NextNumber(0.8, 1.6)
			),
			Vector3.new(
				math.cos(angle) * dist,
				shapeRng:NextNumber(-radius * 0.4, radius * 0.6),
				math.sin(angle) * dist
			),
			tilt(0.8),
			ore.OreColor,
			Enum.Material.Metal,
			ore.OreReflectance
		)
	end

	-- Debris burst, fired by MiningService on every hit. Built here so the
	-- mining code never has to know how a node is put together.
	local attachment = Instance.new("Attachment")
	attachment.Name = "HitFx"
	attachment.Parent = core

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Debris"
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(9, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -70, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-220, 220)
	emitter.Drag = 1.5
	emitter.Color = ColorSequence.new(ore.OreColor, ore.RockColor)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 0.16),
		NumberSequenceKeypoint.new(1, radius * 0.05),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment

	model.Parent = parent

	model:SetAttribute("OreId", ore.Id)
	model:SetAttribute("Tier", tier)
	model:SetAttribute("MaxHits", ore.HitsToDeplete)
	model:SetAttribute("MassKg", massKg)

	CollectionService:AddTag(model, TAG_ORE_NODE)
	return model
end

-- Nodes go on the floor, embedded in solid walls, and hanging from the
-- ceiling, so the cave reads as three-dimensional rather than a corridor
-- with rocks on the carpet.
local function scatterNodes(cell, tier, count, rng, parent)
	for _ = 1, count do
		local ore = OreData.PickForTier(tier, rng)

		if ore ~= nil then
			-- Mass is rolled here, not inside createOreNode, because the node's
			-- physical size follows from it and placement needs that size.
			local massKg = rng:NextNumber(ore.NodeMassMin, ore.NodeMassMax)
			local radius = OreData.NodeRadius(massKg)

			local roll = rng:NextNumber()
			local position

			if roll < 0.45 and #cell.solidFaces > 0 then
				-- Wall: sit the node half-buried in the rock face.
				local face = cell.solidFaces[rng:NextInteger(1, #cell.solidFaces)]
				local along = rng:NextNumber(-cell.halfWidth * 0.7, cell.halfWidth * 0.7)
				local y = cell.floorY + math.clamp(
					rng:NextNumber(radius, cell.height - radius),
					radius * 0.6,
					math.max(radius * 0.6, cell.height - radius * 0.6)
				)

				local x = cell.originX + face.dCol * cell.halfWidth
				local z = cell.originZ + face.dRow * cell.halfWidth

				if face.dCol ~= 0 then
					z = z + along
				else
					x = x + along
				end

				position = Vector3.new(x, y, z)
			elseif roll < 0.62 then
				-- Ceiling.
				position = Vector3.new(
					cell.originX + rng:NextNumber(-cell.halfWidth * 0.8, cell.halfWidth * 0.8),
					cell.floorY + cell.height - radius * 0.5,
					cell.originZ + rng:NextNumber(-cell.halfWidth * 0.8, cell.halfWidth * 0.8)
				)
			else
				-- Floor.
				position = Vector3.new(
					cell.originX + rng:NextNumber(-cell.halfWidth * 0.75, cell.halfWidth * 0.75),
					cell.floorY + radius * 0.55,
					cell.originZ + rng:NextNumber(-cell.halfWidth * 0.75, cell.halfWidth * 0.75)
				)
			end

			createOreNode(ore, position, tier, massKg, radius, rng, parent)
		end
	end
end

local function createElevatorAnchor(position, tier, direction, parent)
	local pad = Instance.new("Part")
	pad.Name = "Elevator" .. direction
	pad.Size = Vector3.new(10, 1, 10)
	pad.Position = position
	pad.Anchored = true
	pad.Material = Enum.Material.DiamondPlate

	if direction == "Down" then
		pad.Color = Color3.fromRGB(200, 90, 60)
	else
		pad.Color = Color3.fromRGB(80, 170, 200)
	end

	pad.Parent = parent
	pad:SetAttribute("Tier", tier)
	pad:SetAttribute("Direction", direction)
	CollectionService:AddTag(pad, TAG_ELEVATOR)
	return pad
end

local function createSpawn(position, parent)
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SurfaceSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = position
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(120, 200, 120)
	spawn.Material = Enum.Material.DiamondPlate
	spawn.Parent = parent
	return spawn
end

local function buildTier(tierLayout, root)
	local tier = tierLayout.Tier
	local tierConfig = GameConfig.Tiers[tier]

	if tierConfig == nil then
		warn("MineGenerator: no GameConfig.Tiers entry for tier " .. tostring(tier))
		return 0, 0
	end

	local tierFolder = Instance.new("Folder")
	tierFolder.Name = "Tier" .. tostring(tier) .. "_" .. tierConfig.Name
	tierFolder.Parent = root

	local geometryFolder = Instance.new("Folder")
	geometryFolder.Name = "Geometry"
	geometryFolder.Parent = tierFolder

	local nodeFolder = Instance.new("Folder")
	nodeFolder.Name = "Nodes"
	nodeFolder.Parent = tierFolder

	local color = TIER_COLORS[tier]
	if color == nil then
		color = Color3.fromRGB(120, 120, 120)
	end

	local cellCount = 0
	local nodeCount = 0

	for row, line in ipairs(tierLayout.Rows) do
		for col = 1, string.len(line) do
			local char = string.sub(line, col, col)

			if char ~= CHAR_ROCK then
				local cell = buildCell(tierLayout.Rows, row, col, tierConfig, tier, color, geometryFolder)
				cellCount = cellCount + 1

				local rng = cellRng(tier, col, row)
				scatterRubble(cell, color, rng, geometryFolder)

				local count = tierConfig.NodesPerCell
				if char == CHAR_RICH then
					count = tierConfig.RichNodesPerCell
				end

				scatterNodes(cell, tier, count, rng, nodeFolder)
				nodeCount = nodeCount + count

				local centerX = cell.originX
				local centerZ = cell.originZ

				if char == CHAR_DOWN then
					createElevatorAnchor(
						Vector3.new(centerX, tierConfig.FloorY + 0.5, centerZ),
						tier, "Down", tierFolder
					)
				elseif char == CHAR_UP then
					createElevatorAnchor(
						Vector3.new(centerX, tierConfig.FloorY + 0.5, centerZ),
						tier, "Up", tierFolder
					)
				elseif char == CHAR_SPAWN then
					createSpawn(Vector3.new(centerX, tierConfig.FloorY + 0.5, centerZ), tierFolder)
				end
			end
		end
	end

	return cellCount, nodeCount
end

function MineGenerator.Build()
	local existing = workspace:FindFirstChild(GENERATED_FOLDER)
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = GENERATED_FOLDER
	root.Parent = workspace

	local totalCells = 0
	local totalNodes = 0

	for _, tierLayout in ipairs(MineLayout) do
		local cells, nodes = buildTier(tierLayout, root)
		totalCells = totalCells + cells
		totalNodes = totalNodes + nodes
	end

	print(
		"MineGenerator: built " .. tostring(totalCells) .. " cells, "
			.. tostring(totalNodes) .. " ore nodes."
	)
end

return MineGenerator
