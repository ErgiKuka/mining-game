-- Persistence. Owns every profile; CurrencyService and InventoryService read
-- and write through it rather than holding their own copies, so there is
-- exactly one source of truth per player and nothing to keep in sync.
--
-- ProfileStore handles session locking, retries and auto-saving. Hand-rolled
-- session locks are one of the top causes of lost player data, and this is not
-- the place to be clever.
--
-- SchemaVersion is here from day one. Retrofitting migrations after you have
-- live players is miserable; the same discipline as an EF migration.
--
-- Declaration order in this file matters: Lua locals are invisible above their
-- own declaration, so every helper is defined before the function that calls
-- it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)

local GearData = require(ReplicatedStorage.Shared.Data.GearData)
local OreData = require(ReplicatedStorage.Shared.Data.OreData)
local Hazard = require(ReplicatedStorage.Shared.Hazard)
local CargoService = require(script.Parent.CargoService)

local DataService = {}

local SCHEMA_VERSION = 1

local TEMPLATE = {
	SchemaVersion = SCHEMA_VERSION,
	Balance = 0,
	Inventory = {},              -- oreId -> kilograms
	GearId = GearData.StartingGearId,
	Stats = {
		DeepestDepth = 0,
		TotalEarned = 0,
	},
}

local store = ProfileStore.New("PlayerData_v1", TEMPLATE)
local profiles = {}
local clientReady = {}
local loadedCallbacks = {}

local requestNotice = ReplicatedStorage.Remotes.RequestNotice
local showNotice = ReplicatedStorage.Remotes.ShowNotice

function DataService.Get(player)
	local profile = profiles[player]

	if profile == nil or not profile:IsActive() then
		return nil
	end

	return profile.Data
end

function DataService.IsLoaded(player)
	return DataService.Get(player) ~= nil
end

-- Services register here instead of polling, so nothing reads a profile that
-- has not finished loading.
function DataService.OnLoaded(callback)
	table.insert(loadedCallbacks, callback)
end

local function migrate(data)
	if data.SchemaVersion == nil then
		data.SchemaVersion = 1
	end

	-- Future migrations chain here:
	--   if data.SchemaVersion == 1 then ... data.SchemaVersion = 2 end

	return data
end

-- Delivering the notice needs TWO things that arrive in an unpredictable
-- order: the profile finishing its async load, and the client's UI being ready
-- to receive. Waiting on either alone drops the notice - so this fires only
-- when whichever one is second arrives, and is called from both places.
local function tryDeliverNotice(player)
	if clientReady[player] ~= true then
		return
	end

	local data = DataService.Get(player)

	if data == nil or data.PendingNotice == nil then
		return
	end

	local notice = data.PendingNotice
	data.PendingNotice = nil

	showNotice:FireClient(player, notice)
end

local function onRequestNotice(player)
	clientReady[player] = true
	tryDeliverNotice(player)
end

-- The logout penalty. Reason "Shutdown" is excluded deliberately: Roblox
-- restarts servers on its own schedule and that is not the player's fault.
--
-- What was lost is recorded on the profile rather than sent to the client -
-- the client is already gone. It is delivered on their next join, so ore never
-- disappears without an explanation.
local function applyLogoutPenalty(player, profile, reason)
	if reason == "Shutdown" then
		return
	end

	if CargoService.IsSecured(player) then
		return
	end

	local depth = CargoService.GetDeepestDepth(player)
	local fraction = Hazard.GetOreLossFraction(depth)
	local inventory = profile.Data.Inventory

	local lostMass = 0
	local lostValue = 0

	for oreId, mass in pairs(inventory) do
		local lost = mass * fraction
		local left = mass - lost

		lostMass = lostMass + lost

		local ore = OreData.ById[oreId]
		if ore ~= nil then
			lostValue = lostValue + ore.ValuePerKg * lost
		end

		if left <= 0.0005 then
			inventory[oreId] = nil
		else
			inventory[oreId] = left
		end
	end

	if lostMass <= 0.005 then
		return
	end

	profile.Data.PendingNotice = {
		Type = "Logout",
		Depth = math.floor(depth),
		Fraction = fraction,
		LostMass = lostMass,
		LostValue = math.floor(lostValue + 0.5),
	}
end

local function onPlayerAdded(player)
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player:IsDescendantOf(Players) == false
		end,
	})

	if profile == nil then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	migrate(profile.Data)

	profile.OnLastSave:Connect(function(reason)
		applyLogoutPenalty(player, profile, reason)
	end)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil

		if player:IsDescendantOf(Players) then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
	end)

	if not player:IsDescendantOf(Players) then
		profile:EndSession()
		return
	end

	profiles[player] = profile

	for _, callback in ipairs(loadedCallbacks) do
		task.spawn(callback, player, profile.Data)
	end

	tryDeliverNotice(player)
end

function DataService.Start()
	requestNotice.OnServerEvent:Connect(onRequestNotice)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		clientReady[player] = nil

		local profile = profiles[player]

		if profile ~= nil then
			profile:EndSession()
			profiles[player] = nil
		end
	end)

	print("DataService: started.")
end

return DataService
