-- Handles travel between tiers.
--
-- Elevators are teleport pads, not shafts: layouts on different tiers do not
-- need to align vertically, so each tier's layout can change independently.
--
-- Pairing is data-driven from the anchors the generator placed:
--   tier N "Down"  ->  tier N+1 "Up"
--   tier N "Up"    ->  tier N-1 "Down"
--
-- The hold duration is the ascent cost: leaving a deep tier means standing
-- exposed on the pad while the hold completes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local ElevatorService = {}

local TAG_ELEVATOR = "ElevatorAnchor"
local ARRIVAL_HEIGHT = 4
local COOLDOWN_SECONDS = 1

local lastUseByPlayer = {}

local function findAnchor(anchors, tier, direction)
	for _, anchor in ipairs(anchors) do
		if anchor:GetAttribute("Tier") == tier and anchor:GetAttribute("Direction") == direction then
			return anchor
		end
	end
	return nil
end

local function resolveDestination(anchors, anchor)
	local tier = anchor:GetAttribute("Tier")
	local direction = anchor:GetAttribute("Direction")

	if direction == "Down" then
		return findAnchor(anchors, tier + 1, "Up")
	elseif direction == "Up" then
		return findAnchor(anchors, tier - 1, "Down")
	end

	return nil
end

local function onTriggered(player, destination)
	-- Guard clauses: the character can be missing mid-respawn.
	local character = player.Character
	if character == nil then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end

	-- Debounce. ProximityPrompt already enforces distance server-side,
	-- but nothing stops repeated triggers.
	local now = os.clock()
	local last = lastUseByPlayer[player]
	if last ~= nil and now - last < COOLDOWN_SECONDS then
		return
	end
	lastUseByPlayer[player] = now

	local arrival = destination.Position + Vector3.new(0, ARRIVAL_HEIGHT, 0)
	character:PivotTo(CFrame.new(arrival))
end

local function setupAnchor(anchors, anchor)
	local destination = resolveDestination(anchors, anchor)

	if destination == nil then
		warn(
			"ElevatorService: no destination for "
				.. anchor:GetFullName()
				.. " (tier "
				.. tostring(anchor:GetAttribute("Tier"))
				.. ", "
				.. tostring(anchor:GetAttribute("Direction"))
				.. ")"
		)
		return
	end

	local direction = anchor:GetAttribute("Direction")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ElevatorPrompt"
	prompt.ObjectText = "Elevator"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false

	if direction == "Down" then
		prompt.ActionText = "Descend"
		prompt.HoldDuration = GameConfig.Elevator.DescendHoldSeconds
	else
		prompt.ActionText = "Ascend"
		prompt.HoldDuration = GameConfig.Elevator.AscendHoldSeconds
	end

	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player)
		onTriggered(player, destination)
	end)
end

function ElevatorService.Start()
	local anchors = CollectionService:GetTagged(TAG_ELEVATOR)

	if #anchors == 0 then
		warn("ElevatorService: no elevator anchors found. Has the mine been generated?")
		return
	end

	for _, anchor in ipairs(anchors) do
		setupAnchor(anchors, anchor)
	end

	print("ElevatorService: wired " .. tostring(#anchors) .. " elevator anchors.")
end

return ElevatorService
