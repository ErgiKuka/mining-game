-- Applies depth damage, handles death, and owns surface regeneration.
--
-- Roblox's default Health script regenerates about 1% of max health per second,
-- which would cancel out most of the hazard curve. It is overridden by an empty
-- Script of the same name in StarterCharacterScripts; regen is handled here
-- instead so it only happens where the design wants it: above ground.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Hazard = require(ReplicatedStorage.Shared.Hazard)
local OreData = require(ReplicatedStorage.Shared.Data.OreData)
local InventoryService = require(script.Parent.InventoryService)
local CargoService = require(script.Parent.CargoService)

local HazardService = {}

local TAG_SAFE_POCKET = "SafePocket"
local TICK_SECONDS = 0.5

local deathFeedback = ReplicatedStorage.Remotes.DeathFeedback
local requestRespawn = ReplicatedStorage.Remotes.RequestRespawn

local trackedDeaths = {}

local function nearSafePocket(position)
	for _, pocket in ipairs(CollectionService:GetTagged(TAG_SAFE_POCKET)) do
		if (position - pocket.Position).Magnitude <= GameConfig.Hazard.SafePocketRadius then
			return true
		end
	end

	return false
end

local function onDeath(player, depth)
	local fraction = Hazard.GetOreLossFraction(depth)
	local inventory = InventoryService.Get(player)

	-- Snapshot ids: Remove mutates the table being iterated.
	local ids = {}
	for id in pairs(inventory) do
		table.insert(ids, id)
	end

	local lostMass = 0
	local lostValue = 0

	for _, id in ipairs(ids) do
		local held = inventory[id]

		if held ~= nil and held > 0 then
			local taken = InventoryService.Remove(player, id, held * fraction)
			lostMass = lostMass + taken

			local ore = OreData.ById[id]
			if ore ~= nil then
				lostValue = lostValue + ore.ValuePerKg * taken
			end
		end
	end

	-- The penalty for this trip has been paid; do not charge it again on
	-- logout.
	CargoService.Reset(player)

	deathFeedback:FireClient(player, {
		Depth = math.floor(depth),
		Fraction = fraction,
		LostMass = lostMass,
		LostValue = math.floor(lostValue + 0.5),
		RespawnSeconds = GameConfig.Hazard.RespawnSeconds,
	})
end

-- Manual respawn. Roblox will respawn automatically after RespawnTime anyway;
-- this only lets a player skip the wait once they have read the screen.
-- Guarded on the character actually being dead so it cannot be used as a
-- free teleport to spawn from anywhere in the mine.
local function onRequestRespawn(player)
	local character = player.Character

	if character == nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid == nil or humanoid.Health > 0 then
		return
	end

	player:LoadCharacter()
end

local function watchCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid == nil then
		return
	end

	humanoid.BreakJointsOnDeath = true
	trackedDeaths[player] = false

	humanoid.Died:Connect(function()
		if trackedDeaths[player] then
			return
		end
		trackedDeaths[player] = true

		local root = character:FindFirstChild("HumanoidRootPart")
		local depth = 0

		if root ~= nil then
			depth = Hazard.GetDepth(root.Position)
		end

		onDeath(player, depth)
	end)
end

local function tickPlayer(player, dt)
	local character = player.Character
	if character == nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if humanoid == nil or root == nil or humanoid.Health <= 0 then
		return
	end

	local depth = Hazard.GetDepth(root.Position)
	local gear = InventoryService.GetGear(player)
	local damage = Hazard.GetDamage(depth, gear.DamageResistance or 1)

	if damage > 0 and not nearSafePocket(root.Position) then
		humanoid.Health = math.max(0, humanoid.Health - damage * dt)
		return
	end

	-- Safe: regenerate. Only somewhere the hazard does not reach, so retreating
	-- is the recovery mechanic rather than waiting out a cooldown at depth.
	if humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(
			humanoid.MaxHealth,
			humanoid.Health + GameConfig.Hazard.RegenPerSecond * dt
		)
	end
end

function HazardService.Start()
	Players.RespawnTime = GameConfig.Hazard.RespawnSeconds
	requestRespawn.OnServerEvent:Connect(onRequestRespawn)

	local function setup(player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)

		if player.Character then
			watchCharacter(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(setup)

	for _, player in ipairs(Players:GetPlayers()) do
		setup(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		trackedDeaths[player] = nil
	end)

	-- Fixed cadence rather than per-frame: damage is a slow effect and this is
	-- a loop over every player on the server.
	task.spawn(function()
		while true do
			local dt = task.wait(TICK_SECONDS)

			for _, player in ipairs(Players:GetPlayers()) do
				tickPlayer(player, dt)
			end
		end
	end)

	print("HazardService: started.")
end

return HazardService
