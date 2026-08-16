-- Player balance. Server-owned; the client is told, never asked.
--
-- Backed by DataService, so every change is on the saved profile - there is no
-- separate in-memory balance that could drift from what gets written.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local CurrencyService = {}

local currencyUpdated = ReplicatedStorage.Remotes.CurrencyUpdated

function CurrencyService.Get(player)
	local data = DataService.Get(player)

	if data == nil then
		return 0
	end

	return data.Balance or 0
end

function CurrencyService.Push(player)
	currencyUpdated:FireClient(player, CurrencyService.Get(player))
end

function CurrencyService.Add(player, amount)
	if amount <= 0 then
		return false
	end

	local data = DataService.Get(player)
	if data == nil then
		return false
	end

	data.Balance = (data.Balance or 0) + amount
	data.Stats.TotalEarned = (data.Stats.TotalEarned or 0) + amount

	CurrencyService.Push(player)
	return true
end

-- Atomic: returns false and changes nothing when the balance is short, so
-- callers never need a separate check that could race.
function CurrencyService.TrySpend(player, amount)
	if amount <= 0 then
		return false
	end

	local data = DataService.Get(player)
	if data == nil then
		return false
	end

	local current = data.Balance or 0
	if current < amount then
		return false
	end

	data.Balance = current - amount
	CurrencyService.Push(player)
	return true
end

function CurrencyService.Start()
	DataService.OnLoaded(function(player)
		CurrencyService.Push(player)
	end)

	print("CurrencyService: started.")
end

return CurrencyService
