-- Player balance. Server-owned; the client is told, never asked.
--
-- In-memory only for now. When ProfileStore lands, this is the module that
-- gains load/save - nothing that calls it will need to change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyService = {}

local STARTING_BALANCE = 0

local balances = {}
local currencyUpdated = ReplicatedStorage.Remotes.CurrencyUpdated

function CurrencyService.Get(player)
	return balances[player] or 0
end

function CurrencyService.Push(player)
	currencyUpdated:FireClient(player, CurrencyService.Get(player))
end

function CurrencyService.Add(player, amount)
	if amount <= 0 then
		return false
	end

	balances[player] = CurrencyService.Get(player) + amount
	CurrencyService.Push(player)
	return true
end

-- Returns false and changes nothing if the player cannot afford it, so callers
-- never need to check the balance separately and race themselves.
function CurrencyService.TrySpend(player, amount)
	if amount <= 0 then
		return false
	end

	local current = CurrencyService.Get(player)
	if current < amount then
		return false
	end

	balances[player] = current - amount
	CurrencyService.Push(player)
	return true
end

function CurrencyService.Start()
	Players.PlayerAdded:Connect(function(player)
		balances[player] = STARTING_BALANCE
		CurrencyService.Push(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		balances[player] = nil
	end)

	print("CurrencyService: started.")
end

return CurrencyService
