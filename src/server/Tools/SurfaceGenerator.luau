-- Builds the above-ground hub. Run from the Studio command bar in edit mode:
--   require(game.ServerScriptService.Server.Tools.SurfaceGenerator).Build()
--
-- Independent of MineGenerator: separate folder, separate command, so you can
-- rebuild one without touching the other.
--
-- Everything is greybox. Tagged pads are the contract with the services:
-- ElevatorAnchor, SellTerminal, ShopTerminal, PlotPad. Services find their
-- own furniture by tag and never care how it was placed.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local SurfaceGenerator = {}

local GENERATED_FOLDER = "GeneratedSurface"

local TAG_ELEVATOR = "ElevatorAnchor"
local TAG_SELL = "SellTerminal"
local TAG_SHOP = "ShopTerminal"
local TAG_PLOT = "PlotPad"

local COLOR_PLAZA = Color3.fromRGB(112, 108, 98)
local COLOR_STRUCTURE = Color3.fromRGB(88, 84, 80)
local COLOR_MOUNTAIN = Color3.fromRGB(74, 70, 66)
local COLOR_PLOT = Color3.fromRGB(96, 112, 92)
local COLOR_PLOT_EDGE = Color3.fromRGB(70, 82, 68)
local COLOR_SELL = Color3.fromRGB(206, 168, 74)
local COLOR_SHOP = Color3.fromRGB(96, 148, 196)

local function part(name, size, cframe, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(text, size, cframe, parent, color)
	local sign = part("Sign", size, cframe, COLOR_STRUCTURE, Enum.Material.SmoothPlastic, parent)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 120)
	gui.Parent = sign

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = color
	textLabel.Text = text
	textLabel.Parent = gui

	return sign
end

-- The lift headframe at plaza centre. No shaft: elevators are teleports
-- everywhere in this game, so the entrance is a structure, not a hole.
local function buildHeadframe(surface, parent)
	local y = surface.Y
	local r = surface.HeadframeRadius
	local h = surface.HeadframeHeight

	local folder = Instance.new("Folder")
	folder.Name = "MineEntrance"
	folder.Parent = parent

	-- Four corner pillars.
	local corners = {
		Vector3.new(-r, 0, -r),
		Vector3.new(-r, 0, r),
		Vector3.new(r, 0, -r),
		Vector3.new(r, 0, r),
	}

	for index, offset in ipairs(corners) do
		part(
			"Pillar" .. tostring(index),
			Vector3.new(5, h, 5),
			CFrame.new(offset.X, y + h / 2, offset.Z),
			COLOR_STRUCTURE,
			Enum.Material.Metal,
			folder
		)
	end

	-- Roof beams.
	part("BeamA", Vector3.new(r * 2 + 5, 3, 5), CFrame.new(0, y + h, -r), COLOR_STRUCTURE, Enum.Material.Metal, folder)
	part("BeamB", Vector3.new(r * 2 + 5, 3, 5), CFrame.new(0, y + h, r), COLOR_STRUCTURE, Enum.Material.Metal, folder)
	part("BeamC", Vector3.new(5, 3, r * 2 + 5), CFrame.new(-r, y + h, 0), COLOR_STRUCTURE, Enum.Material.Metal, folder)
	part("BeamD", Vector3.new(5, 3, r * 2 + 5), CFrame.new(r, y + h, 0), COLOR_STRUCTURE, Enum.Material.Metal, folder)

	-- Winch housing on top, purely to give the silhouette something to read.
	part("Winch", Vector3.new(14, 8, 14), CFrame.new(0, y + h + 5, 0), COLOR_STRUCTURE, Enum.Material.Metal, folder)

	-- The elevator pad itself. Tier 0 Down pairs with tier 1 Up.
	local pad = part(
		"ElevatorDown",
		Vector3.new(14, 1, 14),
		CFrame.new(0, y + 0.5, 0),
		Color3.fromRGB(200, 90, 60),
		Enum.Material.DiamondPlate,
		folder
	)
	pad:SetAttribute("Tier", 0)
	pad:SetAttribute("Direction", "Down")
	CollectionService:AddTag(pad, TAG_ELEVATOR)

	label(
		"MINE ENTRANCE",
		Vector3.new(28, 7, 1),
		CFrame.new(0, y + 16, -r - 3),
		folder,
		Color3.fromRGB(240, 200, 160)
	)

	return folder
end

local function buildTerminal(name, tag, text, color, position, parent)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	-- Small building shell so the terminal reads as a place, not a floating pad.
	part("BackWall", Vector3.new(30, 16, 2), CFrame.new(position + Vector3.new(0, 8, 10)), COLOR_STRUCTURE, Enum.Material.Concrete, folder)
	part("SideA", Vector3.new(2, 16, 20), CFrame.new(position + Vector3.new(-14, 8, 0)), COLOR_STRUCTURE, Enum.Material.Concrete, folder)
	part("SideB", Vector3.new(2, 16, 20), CFrame.new(position + Vector3.new(14, 8, 0)), COLOR_STRUCTURE, Enum.Material.Concrete, folder)
	part("Roof", Vector3.new(32, 2, 24), CFrame.new(position + Vector3.new(0, 17, 2)), COLOR_STRUCTURE, Enum.Material.Concrete, folder)
	part("Counter", Vector3.new(24, 5, 4), CFrame.new(position + Vector3.new(0, 2.5, 2)), color, Enum.Material.WoodPlanks, folder)

	local pad = part(
		"Terminal",
		Vector3.new(10, 1, 8),
		CFrame.new(position + Vector3.new(0, 0.5, -5)),
		color,
		Enum.Material.DiamondPlate,
		folder
	)
	CollectionService:AddTag(pad, tag)

	label(text, Vector3.new(26, 6, 1), CFrame.new(position + Vector3.new(0, 12, -9)), folder, color)

	return folder
end

local function buildPlots(surface, parent)
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = parent

	local y = surface.Y
	local half = surface.PlotSize / 2

	for index = 1, surface.PlotCount do
		local angle = (index - 1) / surface.PlotCount * math.pi * 2
		local x = math.cos(angle) * surface.PlotRingRadius
		local z = math.sin(angle) * surface.PlotRingRadius

		local plotFolder = Instance.new("Folder")
		plotFolder.Name = "Plot" .. tostring(index)
		plotFolder.Parent = folder

		local pad = part(
			"PlotFloor",
			Vector3.new(surface.PlotSize, 2, surface.PlotSize),
			CFrame.new(x, y + 1, z),
			COLOR_PLOT,
			Enum.Material.Concrete,
			plotFolder
		)
		pad:SetAttribute("PlotIndex", index)
		CollectionService:AddTag(pad, TAG_PLOT)

		-- Low kerb so the plot boundary is legible from the ground.
		part("KerbA", Vector3.new(surface.PlotSize, 2, 2), CFrame.new(x, y + 3, z - half), COLOR_PLOT_EDGE, Enum.Material.Concrete, plotFolder)
		part("KerbB", Vector3.new(surface.PlotSize, 2, 2), CFrame.new(x, y + 3, z + half), COLOR_PLOT_EDGE, Enum.Material.Concrete, plotFolder)
		part("KerbC", Vector3.new(2, 2, surface.PlotSize), CFrame.new(x - half, y + 3, z), COLOR_PLOT_EDGE, Enum.Material.Concrete, plotFolder)
		part("KerbD", Vector3.new(2, 2, surface.PlotSize), CFrame.new(x + half, y + 3, z), COLOR_PLOT_EDGE, Enum.Material.Concrete, plotFolder)

		-- Sign faces the plaza centre.
		local inward = CFrame.new(Vector3.new(x, y + 9, z), Vector3.new(0, y + 9, 0))
		label(
			"PLOT " .. tostring(index),
			Vector3.new(16, 5, 1),
			inward * CFrame.new(0, 0, -half - 2),
			plotFolder,
			Color3.fromRGB(200, 230, 200)
		)
	end

	return folder
end

-- Ring of large rotated blocks. Cheap, and it stops the plaza reading as a
-- slab floating in the sky.
local function buildMountains(surface, parent)
	local folder = Instance.new("Folder")
	folder.Name = "Mountains"
	folder.Parent = parent

	local rng = Random.new(20260815)

	for index = 1, surface.MountainCount do
		local angle = (index - 1) / surface.MountainCount * math.pi * 2
		local radius = surface.MountainRingRadius + rng:NextNumber(-30, 30)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius

		local height = rng:NextNumber(90, 210)
		local width = rng:NextNumber(90, 160)

		part(
			"Peak" .. tostring(index),
			Vector3.new(width, height, width),
			CFrame.new(x, surface.Y + height / 2 - 30, z)
				* CFrame.Angles(
					rng:NextNumber(-0.12, 0.12),
					rng:NextNumber(0, 6.28),
					rng:NextNumber(-0.12, 0.12)
				),
			COLOR_MOUNTAIN,
			Enum.Material.Rock,
			folder
		)
	end

	return folder
end

local function buildSpawn(surface, parent)
	for _, child in ipairs(workspace:GetDescendants()) do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SurfaceSpawn"
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.CFrame = CFrame.new(0, surface.Y + 0.5, -surface.BuildingRingRadius - 40)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(120, 200, 120)
	spawn.Material = Enum.Material.DiamondPlate
	spawn.Duration = 0     -- no forcefield bubble on spawn
	spawn.Parent = parent

	return spawn
end

function SurfaceGenerator.Build()
	local existing = workspace:FindFirstChild(GENERATED_FOLDER)
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = GENERATED_FOLDER
	root.Parent = workspace

	local surface = GameConfig.Surface

	local plaza = part(
		"Plaza",
		Vector3.new(surface.PlazaRadius * 2, surface.PlazaThickness, surface.PlazaRadius * 2),
		CFrame.new(0, surface.Y - surface.PlazaThickness / 2, 0),
		COLOR_PLAZA,
		Enum.Material.Ground,
		root
	)
	plaza.Shape = Enum.PartType.Block

	buildHeadframe(surface, root)

	buildTerminal(
		"Market",
		TAG_SELL,
		"MARKET - SELL ORE",
		COLOR_SELL,
		Vector3.new(-surface.BuildingRingRadius, surface.Y, -surface.BuildingRingRadius),
		root
	)

	buildTerminal(
		"Shop",
		TAG_SHOP,
		"SHOP - GEAR",
		COLOR_SHOP,
		Vector3.new(surface.BuildingRingRadius, surface.Y, -surface.BuildingRingRadius),
		root
	)

	buildPlots(surface, root)
	buildMountains(surface, root)
	buildSpawn(surface, root)

	print(
		"SurfaceGenerator: built plaza, entrance, market, shop, "
			.. tostring(surface.PlotCount) .. " plots."
	)
end

return SurfaceGenerator
