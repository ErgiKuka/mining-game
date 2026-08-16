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
local DepthMeter = require(UI.DepthMeter)
local NoticePanel = require(UI.NoticePanel)
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
local deathFeedback = remotes:WaitForChild("DeathFeedback")
local cargoStatus = remotes:WaitForChild("CargoStatus")
local requestNotice = remotes:WaitForChild("RequestNotice")
local showNotice = remotes:WaitForChild("ShowNotice")
local requestRespawn = remotes:WaitForChild("RequestRespawn")

Hud.Build(playerGui)
BackpackPanel.Build(playerGui)
MarketPanel.Build(playerGui)
ShopPanel.Build(playerGui)
DepthMeter.Build(playerGui)
NoticePanel.Build(playerGui)

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
		DepthMeter.SetGear(payload.GearId)
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

	Hud.OreToast(payload.OreId, payload.Mass, payload.Final)
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
		Hud.Toast(string.format("Sold %.1f kg for $%d", payload.Mass or 0, payload.Value), Theme.Color.Accent)
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

cargoStatus.OnClientEvent:Connect(function(payload)
	DepthMeter.SetCargo(payload)
end)

NoticePanel.OnRespawn(function()
	requestRespawn:FireServer()
end)

deathFeedback.OnClientEvent:Connect(function(payload)
	NoticePanel.ShowDeath(payload)
end)

showNotice.OnClientEvent:Connect(function(payload)
	NoticePanel.ShowNotice(payload)
end)

-- Ask only once the UI exists, rather than having the server fire on load and
-- race this script's own startup.
requestNotice:FireServer()

-- Cheap poll rather than a per-frame check; neither the location gate nor the
-- depth readout needs frame accuracy.
task.spawn(function()
	while true do
		Hud.UpdateLocation()
		DepthMeter.Update()
		task.wait(0.25)
	end
end)
