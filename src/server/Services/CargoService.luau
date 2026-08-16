-- Cargo securing.
--
-- One rule, stated once so players only learn it once:
--
--   Disconnecting while your cargo is UNSECURED is treated exactly as dying
--   at the deepest point you reached this trip.
--
-- Same formula, same percentage, same message as death. Cargo becomes secured
-- after spending SecureSeconds above the hazard threshold, which resets the
-- recorded depth. A player working tier 1 never sees this - tier 1 is above
-- the threshold, so nothing is ever unsecured there.
--
-- Deliberately has no dependencies on inventory or data: it only watches
-- positions. That keeps the require graph acyclic (DataService needs this,
-- and inventory needs DataService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Hazard = require(ReplicatedStorage.Shared.Hazard)

local CargoService = {}

local TICK_SECONDS = 0.5

local cargoStatus = ReplicatedStorage.Remotes.CargoStatus

local state = {}

local function ensure(player)
	if state[player] == nil then
		state[player] = {
			deepestDepth = 0,
			securedAt = 0,
			secured = true,
		}
	end
	return state[player]
end

function CargoService.IsSecured(player)
	local entry = state[player]
	if entry == nil then
		return true
	end
	return entry.secured
end

function CargoService.GetDeepestDepth(player)
	local entry = state[player]
	if entry == nil then
		return 0
	end
	return entry.deepestDepth
end

-- Called after death: the penalty has already been paid, so the trip resets.
--
-- Pushes immediately. Changing state without notifying leaves the client
-- rendering the last thing it heard, which is what made the indicator stick
-- around after respawning.
function CargoService.Reset(player)
	local entry = ensure(player)
	entry.deepestDepth = 0
	entry.secured = true
	entry.securedAt = 0

	CargoService.Push(player)
end

function CargoService.Push(player)
	local entry = ensure(player)

	cargoStatus:FireClient(player, {
		Secured = entry.secured,
		Remaining = 0,
		Depth = math.floor(entry.deepestDepth),
		Fraction = Hazard.GetOreLossFraction(entry.deepestDepth),
	})
end

local function push(player, entry, remaining)
	cargoStatus:FireClient(player, {
		Secured = entry.secured,
		Remaining = remaining,
		Depth = math.floor(entry.deepestDepth),
		Fraction = Hazard.GetOreLossFraction(entry.deepestDepth),
	})
end

local function tickPlayer(player)
	local entry = ensure(player)

	local character = player.Character
	if character == nil then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end

	-- A corpse stays at depth for the whole respawn wait. Reading its position
	-- would re-flag the cargo as unsecured one tick after death reset it.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	local depth = Hazard.GetDepth(root.Position)
	local threshold = GameConfig.Hazard.StartDepth

	if depth > threshold then
		-- Below the hazard line: cargo is at risk and the clock is void.
		entry.deepestDepth = math.max(entry.deepestDepth, depth)
		entry.secured = false
		entry.securedAt = 0
		push(player, entry, GameConfig.Cargo.SecureSeconds)
		return
	end

	if entry.secured then
		return
	end

	-- Above the line and counting down.
	if entry.securedAt == 0 then
		entry.securedAt = os.clock() + GameConfig.Cargo.SecureSeconds
	end

	local remaining = entry.securedAt - os.clock()

	if remaining <= 0 then
		entry.secured = true
		entry.deepestDepth = 0
		entry.securedAt = 0
		push(player, entry, 0)
		return
	end

	push(player, entry, remaining)
end

function CargoService.Start()
	Players.PlayerAdded:Connect(function(player)
		ensure(player)
		CargoService.Push(player)

		-- The client rebuilds its UI on respawn, so re-state the status.
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			CargoService.Push(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)

			for _, player in ipairs(Players:GetPlayers()) do
				tickPlayer(player)
			end
		end
	end)

	print("CargoService: started.")
end

return CargoService
