-- Builds the pickaxe Tool out of Parts and grants it on spawn.
--
-- Uses WeldConstraint rather than Weld: it locks parts at whatever relative
-- positions they already hold, and survives the Tool repositioning the Handle
-- on equip. Manually computed Weld C0 offsets do not.
--
-- Greybox: replace the Part construction with a mesh later. Nothing outside
-- this file refers to the geometry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearData = require(ReplicatedStorage.Shared.Data.GearData)
local InventoryService = require(script.Parent.InventoryService)

local PickaxeService = {}

local TOOL_NAME = "Pickaxe"

local function makePart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weldTo(handle, part)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = handle
	constraint.Part1 = part
	constraint.Parent = handle
end

local function buildPickaxe(gear)
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = gear.DisplayName

	-- Handle runs along Y. Everything else is positioned relative to it and
	-- welded in place before the Tool is ever parented anywhere.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 4.0, 0.35)
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Color = gear.HandleColor
	handle.Material = Enum.Material.Wood
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local headY = 1.75
	local half = gear.HeadWidth / 2

	-- Central block where the head meets the shaft.
	local collar = makePart(
		"Collar",
		Vector3.new(0.6, 0.7, 0.6),
		CFrame.new(0, headY, 0),
		gear.HeadColor,
		Enum.Material.Metal,
		tool
	)

	-- Two tapered arms sweeping out from the collar, angled slightly down
	-- so the silhouette reads as a pick rather than a hammer.
	local leftArm = makePart(
		"LeftArm",
		Vector3.new(half, 0.45, 0.5),
		CFrame.new(-half / 2, headY + 0.1, 0) * CFrame.Angles(0, 0, math.rad(-8)),
		gear.HeadColor,
		Enum.Material.Metal,
		tool
	)

	local rightArm = makePart(
		"RightArm",
		Vector3.new(half, 0.45, 0.5),
		CFrame.new(half / 2, headY + 0.1, 0) * CFrame.Angles(0, 0, math.rad(8)),
		gear.HeadColor,
		Enum.Material.Metal,
		tool
	)

	local leftTip = makePart(
		"LeftTip",
		Vector3.new(0.45, 0.35, 0.4),
		CFrame.new(-half - 0.15, headY - 0.15, 0) * CFrame.Angles(0, 0, math.rad(-22)),
		gear.HeadColor,
		Enum.Material.Metal,
		tool
	)

	local rightTip = makePart(
		"RightTip",
		Vector3.new(0.45, 0.35, 0.4),
		CFrame.new(half + 0.15, headY - 0.15, 0) * CFrame.Angles(0, 0, math.rad(22)),
		gear.HeadColor,
		Enum.Material.Metal,
		tool
	)

	local grip = makePart(
		"Grip",
		Vector3.new(0.45, 0.9, 0.45),
		CFrame.new(0, -1.4, 0),
		Color3.fromRGB(40, 34, 30),
		Enum.Material.Fabric,
		tool
	)

	weldTo(handle, collar)
	weldTo(handle, leftArm)
	weldTo(handle, rightArm)
	weldTo(handle, leftTip)
	weldTo(handle, rightTip)
	weldTo(handle, grip)

	-- Held low on the shaft, head forward and up.
	tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(90))

	tool:SetAttribute("GearId", gear.Id)
	return tool
end

local function grant(player)
	local gear = InventoryService.GetGear(player)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		return
	end

	local existing = backpack:FindFirstChild(TOOL_NAME)
	if existing then
		existing:Destroy()
	end

	if player.Character then
		local held = player.Character:FindFirstChild(TOOL_NAME)
		if held then
			held:Destroy()
		end
	end

	buildPickaxe(gear).Parent = backpack
end

function PickaxeService.Regrant(player)
	grant(player)
end

function PickaxeService.Start()
	local function setup(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			grant(player)
		end)

		if player.Character then
			grant(player)
		end
	end

	Players.PlayerAdded:Connect(setup)

	for _, player in ipairs(Players:GetPlayers()) do
		setup(player)
	end

	print("PickaxeService: started.")
end

return PickaxeService
