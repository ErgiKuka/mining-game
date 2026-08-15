-- Buying gear.
--
-- Upgrades only: a player can buy any tier above their current one they can
-- afford, but never sidegrade or downgrade. That keeps progression monotonic
-- so no purchase can leave someone worse off or refundable for profit.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearData = require(ReplicatedStorage.Shared.Data.GearData)
local InventoryService = require(script.Parent.InventoryService)
local CurrencyService = require(script.Parent.CurrencyService)
local PickaxeService = require(script.Parent.PickaxeService)

local ShopService = {}

local TAG_SHOP = "ShopTerminal"
local MAX_TERMINAL_DISTANCE = 30

local requestBuy = ReplicatedStorage.Remotes.RequestBuy
local buyResult = ReplicatedStorage.Remotes.BuyResult
local openPanel = ReplicatedStorage.Remotes.OpenPanel

local function nearTerminal(player)
	local character = player.Character
	if character == nil then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return false
	end

	for _, pad in ipairs(CollectionService:GetTagged(TAG_SHOP)) do
		if (root.Position - pad.Position).Magnitude <= MAX_TERMINAL_DISTANCE then
			return true
		end
	end

	return false
end

local function fail(player, reason)
	buyResult:FireClient(player, { Success = false, Reason = reason })
end

local function onRequestBuy(player, gearId)
	if typeof(gearId) ~= "string" then
		return
	end

	if not nearTerminal(player) then
		return
	end

	local gear = GearData.ById[gearId]
	if gear == nil then
		return
	end

	local current = InventoryService.GetGear(player)

	if gear.TierIndex <= current.TierIndex then
		fail(player, "You already have better gear.")
		return
	end

	-- TrySpend is atomic: it returns false and changes nothing when the
	-- balance is short, so there is no check-then-act gap to race.
	if not CurrencyService.TrySpend(player, gear.Cost) then
		fail(player, "Not enough money.")
		return
	end

	InventoryService.SetGear(player, gear.Id)
	PickaxeService.Regrant(player)

	buyResult:FireClient(player, {
		Success = true,
		GearId = gear.Id,
		GearName = gear.DisplayName,
	})
end

function ShopService.Start()
	requestBuy.OnServerEvent:Connect(onRequestBuy)

	for _, pad in ipairs(CollectionService:GetTagged(TAG_SHOP)) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Browse Gear"
		prompt.ObjectText = "Shop"
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = pad

		prompt.Triggered:Connect(function(player)
			openPanel:FireClient(player, "Shop")
		end)
	end

	print("ShopService: started.")
end

return ShopService
