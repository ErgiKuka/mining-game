-- Client entry point. Builds the UI and wires it to the server's remotes.
--
-- Mirrors Main.server.luau: one script owns startup order, everything else is
-- a module. Nothing here holds game state; it renders what the server sends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearData = require(ReplicatedStorage:WaitForChild("Shared").Data.GearData)

local UI = script.Parent.UI
local Theme = require(UI.Theme)
local Panel = require(UI.Panel)
local Hud = require(UI.Hud)
local BackpackPanel = require(UI.BackpackPanel)
local MarketPanel = require(UI.MarketPanel)
local ShopPanel = require(UI.ShopPanel)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local inventoryUpdated = remotes:WaitForChild("InventoryUpdated")
local miningFeedback = remotes:WaitForChild("MiningFeedback")
local currencyUpdated = remotes:WaitForChild("CurrencyUpdated")
local requestTeleport = remotes:WaitForChild("RequestTeleport")
local openPanel = remotes:WaitForChild("OpenPanel")
local requestSell = remotes:WaitForChild("RequestSell")
local sellResult = remotes:WaitForChild("SellResult")
local requestBuy = remotes:WaitForChild("RequestBuy")
local buyResult = remotes:WaitForChild("BuyResult")

Hud.Build(playerGui)
BackpackPanel.Build(playerGui)
MarketPanel.Build(playerGui)
ShopPanel.Build(playerGui)

Hud.OnButton("Backpack", function()
	BackpackPanel.Toggle()
end)

Hud.OnButton("Teleport", function(destination)
	requestTeleport:FireServer(destination)
end)

MarketPanel.OnSell(function(oreId)
	requestSell:FireServer(oreId)
end)

ShopPanel.OnBuy(function(gearId)
	requestBuy:FireServer(gearId)
end)

inventoryUpdated.OnClientEvent:Connect(function(payload)
	Hud.SetInventory(payload)
	BackpackPanel.Update(payload)
	MarketPanel.Update(payload)

	if payload.GearId then
		ShopPanel.SetGear(payload.GearId)
	end
end)

currencyUpdated.OnClientEvent:Connect(function(balance)
	Hud.SetMoney(balance)
	ShopPanel.SetBalance(balance)
end)

miningFeedback.OnClientEvent:Connect(function(payload)
	if payload.Full then
		Hud.Toast("Backpack full", Theme.Color.Danger)
		return
	end

	Hud.OreToast(payload.OreId, payload.Units, payload.Bonus)
end)

openPanel.OnClientEvent:Connect(function(which)
	if which == "Market" then
		MarketPanel.Show()
	elseif which == "Shop" then
		ShopPanel.Show()
	end
end)

sellResult.OnClientEvent:Connect(function(payload)
	if payload.Value and payload.Value > 0 then
		Hud.Toast("Sold " .. tostring(payload.Units) .. " ore for $" .. tostring(payload.Value), Theme.Color.Accent)
	else
		Hud.Toast("Nothing to sell", Theme.Color.TextMuted)
	end
end)

buyResult.OnClientEvent:Connect(function(payload)
	if payload.Success then
		Hud.Toast("Bought " .. tostring(payload.GearName), Theme.Color.Success)
	else
		Hud.Toast(payload.Reason or "Purchase failed", Theme.Color.Danger)
	end
end)

-- Cheap poll rather than a per-frame check; location only gates button state.
task.spawn(function()
	while true do
		Hud.UpdateLocation()
		task.wait(0.5)
	end
end)
