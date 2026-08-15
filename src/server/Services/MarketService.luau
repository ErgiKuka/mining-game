-- Selling ore.
--
-- The client asks to sell; this decides what that was worth. Prices are
-- recomputed here at sell time rather than trusted from the request, and the
-- payout is based on what was actually removed from the inventory, not what
-- the client claimed to hold.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pricing = require(ReplicatedStorage.Shared.Pricing)
local OreData = require(ReplicatedStorage.Shared.Data.OreData)
local InventoryService = require(script.Parent.InventoryService)
local CurrencyService = require(script.Parent.CurrencyService)

local MarketService = {}

local TAG_SELL = "SellTerminal"
local MAX_TERMINAL_DISTANCE = 30

local requestSell = ReplicatedStorage.Remotes.RequestSell
local sellResult = ReplicatedStorage.Remotes.SellResult
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

	for _, pad in ipairs(CollectionService:GetTagged(TAG_SELL)) do
		if (root.Position - pad.Position).Magnitude <= MAX_TERMINAL_DISTANCE then
			return true
		end
	end

	return false
end

local function sellOne(player, oreId, window)
	local held = InventoryService.Get(player)[oreId]
	if held == nil or held <= 0 then
		return 0, 0
	end

	-- Remove first, then pay for exactly what came back. Pricing what the
	-- client asked for rather than what was removed is how duplication bugs
	-- get in.
	local taken = InventoryService.Remove(player, oreId, held)
	if taken <= 0 then
		return 0, 0
	end

	local price = Pricing.GetPrice(oreId, window)
	return taken, taken * price
end

local function onRequestSell(player, oreId)
	if not nearTerminal(player) then
		return
	end

	local window = Pricing.GetWindow()
	local totalUnits = 0
	local totalValue = 0
	local lines = {}

	if oreId == "ALL" then
		-- Snapshot the ids first: Remove mutates the table being iterated.
		local ids = {}
		for id in pairs(InventoryService.Get(player)) do
			table.insert(ids, id)
		end

		for _, id in ipairs(ids) do
			local units, value = sellOne(player, id, window)
			if units > 0 then
				totalUnits = totalUnits + units
				totalValue = totalValue + value
				table.insert(lines, { OreId = id, Units = units, Value = value })
			end
		end
	else
		if typeof(oreId) ~= "string" or OreData.ById[oreId] == nil then
			return
		end

		local units, value = sellOne(player, oreId, window)
		totalUnits = units
		totalValue = value

		if units > 0 then
			table.insert(lines, { OreId = oreId, Units = units, Value = value })
		end
	end

	if totalValue > 0 then
		CurrencyService.Add(player, totalValue)
	end

	sellResult:FireClient(player, {
		Units = totalUnits,
		Value = totalValue,
		Lines = lines,
	})
end

function MarketService.Start()
	requestSell.OnServerEvent:Connect(onRequestSell)

	for _, pad in ipairs(CollectionService:GetTagged(TAG_SELL)) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Sell Ore"
		prompt.ObjectText = "Market"
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = pad

		prompt.Triggered:Connect(function(player)
			openPanel:FireClient(player, "Market")
		end)
	end

	print("MarketService: started.")
end

return MarketService
