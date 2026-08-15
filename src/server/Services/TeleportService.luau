-- Surface-only fast travel between hub locations.
--
-- The client hides these buttons underground, but that is a convenience, not a
-- rule: every request is re-checked here. A hidden button stops an honest
-- player, not a modified client.
--
-- Destinations are resolved from tagged parts the surface generator placed, so
-- moving a building in the generator moves the teleport with it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local TeleportService = {}

local SURFACE_MARGIN = 30
local COOLDOWN_SECONDS = 1.5
local ARRIVAL_HEIGHT = 5

local DESTINATION_TAGS = {
	Market = "SellTerminal",
	Shop = "ShopTerminal",
}

local requestTeleport = ReplicatedStorage.Remotes.RequestTeleport
local lastUse = {}

local function findTagged(tag)
	local tagged = CollectionService:GetTagged(tag)
	if #tagged == 0 then
		return nil
	end
	return tagged[1]
end

local function findEntrance()
	for _, anchor in ipairs(CollectionService:GetTagged("ElevatorAnchor")) do
		if anchor:GetAttribute("Tier") == 0 and anchor:GetAttribute("Direction") == "Down" then
			return anchor
		end
	end
	return nil
end

local function resolveDestination(name)
	if name == "Entrance" then
		return findEntrance()
	end

	local tag = DESTINATION_TAGS[name]
	if tag == nil then
		return nil
	end

	return findTagged(tag)
end

local function onRequest(player, destinationName)
	if typeof(destinationName) ~= "string" then
		return
	end

	local character = player.Character
	if character == nil then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	-- The rule that matters: no fast travel while underground.
	if root.Position.Y <= GameConfig.Surface.Y - SURFACE_MARGIN then
		return
	end

	local now = os.clock()
	local last = lastUse[player]
	if last ~= nil and now - last < COOLDOWN_SECONDS then
		return
	end

	local target = resolveDestination(destinationName)
	if target == nil then
		warn("TeleportService: no destination found for " .. destinationName)
		return
	end

	lastUse[player] = now

	local arrival = target.Position + Vector3.new(0, ARRIVAL_HEIGHT, 0)
	character:PivotTo(CFrame.new(arrival))
end

function TeleportService.Start()
	requestTeleport.OnServerEvent:Connect(onRequest)

	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)

	print("TeleportService: started.")
end

return TeleportService
