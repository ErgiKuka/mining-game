-- Server-authoritative mining.
--
-- The client sends INTENT ("I swung at this node"). This service decides
-- whether that was possible: is it a real node, is it alive, is the player
-- close enough, has their swing cooldown elapsed. Nothing the client sends
-- is trusted, including the timing.
--
-- Yield is split: PARTIAL_SHARE of a node's ore is paid out progressively as
-- it is broken, the rest is a bonus on depletion divided by hit contribution.
-- That means a player who arrives for the last swing receives only the share
-- their hits earned, so sniping a nearly-broken node is not worth doing.
--
-- A node is a Model of several parts. Shrinking scales every part's size and
-- pulls it toward the cluster centre, so the whole formation crumbles.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OreData = require(ReplicatedStorage.Shared.Data.OreData)
local InventoryService = require(script.Parent.InventoryService)

local MiningService = {}

local TAG_ORE_NODE = "OreNode"
local MAX_MINE_DISTANCE = 18
local RESPAWN_SECONDS = 25
local PARTIAL_SHARE = 0.6
local MIN_SHRINK = 0.3

local mineNodeRemote = ReplicatedStorage.Remotes.MineNode
local miningFeedback = ReplicatedStorage.Remotes.MiningFeedback

local nodeState = {}
local lastSwing = {}

local function captureShape(node)
	local origin = node:GetPivot().Position
	local pieces = {}

	for _, part in ipairs(node:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(pieces, {
				part = part,
				size = part.Size,
				offset = part.Position - origin,
				rotation = part.CFrame - part.CFrame.Position,
			})
		end
	end

	return origin, pieces
end

local function getState(node)
	local state = nodeState[node]

	if state == nil then
		local maxHits = node:GetAttribute("MaxHits")
		if maxHits == nil then
			return nil
		end

		local origin, pieces = captureShape(node)

		state = {
			hitsLeft = maxHits,
			maxHits = maxHits,
			contributions = {},
			progress = {},
			origin = origin,
			pieces = pieces,
			depleted = false,
		}
		nodeState[node] = state
	end

	return state
end

local function applyScale(state, scale)
	for _, piece in ipairs(state.pieces) do
		if piece.part.Parent ~= nil then
			piece.part.Size = piece.size * scale
			piece.part.CFrame = CFrame.new(state.origin + piece.offset * scale) * piece.rotation
		end
	end
end

local function setVisible(state, visible)
	for _, piece in ipairs(state.pieces) do
		if piece.part.Parent ~= nil then
			if visible then
				piece.part.Transparency = 0
				piece.part.CanCollide = true
			else
				piece.part.Transparency = 1
				piece.part.CanCollide = false
			end
		end
	end
end

local function resetNode(state)
	state.hitsLeft = state.maxHits
	state.contributions = {}
	state.progress = {}
	state.depleted = false

	applyScale(state, 1)
	setVisible(state, true)
end

local function depleteNode(node, state, ore)
	state.depleted = true
	setVisible(state, false)

	local totalHits = 0
	for _, hits in pairs(state.contributions) do
		totalHits = totalHits + hits
	end

	local bonusPool = ore.UnitsPerNode * (1 - PARTIAL_SHARE)

	if totalHits > 0 then
		for player, hits in pairs(state.contributions) do
			if player.Parent ~= nil then
				local share = math.floor(bonusPool * (hits / totalHits) + 0.5)
				if share > 0 then
					if InventoryService.Add(player, ore.Id, share) then
						miningFeedback:FireClient(player, {
							OreId = ore.Id,
							Units = share,
							Bonus = true,
						})
					end
				end
			end
		end
	end

	task.delay(RESPAWN_SECONDS, function()
		if node.Parent ~= nil then
			resetNode(state)
		end
	end)
end

local function applyHit(player, node, state, ore)
	state.hitsLeft = state.hitsLeft - 1
	state.contributions[player] = (state.contributions[player] or 0) + 1

	local remaining = state.hitsLeft / state.maxHits
	applyScale(state, MIN_SHRINK + (1 - MIN_SHRINK) * remaining)

	-- Progressive payout. Fractions carry between hits so small nodes still
	-- yield whole units instead of rounding away to nothing.
	local perHit = (ore.UnitsPerNode * PARTIAL_SHARE) / state.maxHits
	state.progress[player] = (state.progress[player] or 0) + perHit

	local whole = math.floor(state.progress[player])
	if whole >= 1 then
		if InventoryService.Add(player, ore.Id, whole) then
			state.progress[player] = state.progress[player] - whole
			miningFeedback:FireClient(player, {
				OreId = ore.Id,
				Units = whole,
				Bonus = false,
			})
		end
	end

	if state.hitsLeft <= 0 then
		depleteNode(node, state, ore)
	end
end

local function onMineRequest(player, node)
	-- Guard clauses, cheapest first.
	if typeof(node) ~= "Instance" then
		return
	end

	if not node:IsA("Model") then
		return
	end

	if not CollectionService:HasTag(node, TAG_ORE_NODE) then
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

	if (root.Position - node:GetPivot().Position).Magnitude > MAX_MINE_DISTANCE then
		return
	end

	-- Swing cooldown is the authoritative rate limit. A client firing the
	-- remote in a loop gains nothing.
	local gear = InventoryService.GetGear(player)
	local now = os.clock()
	local last = lastSwing[player]

	if last ~= nil and now - last < gear.SwingSeconds then
		return
	end
	lastSwing[player] = now

	local state = getState(node)
	if state == nil or state.depleted then
		return
	end

	local ore = OreData.ById[node:GetAttribute("OreId")]
	if ore == nil then
		return
	end

	-- Backpack full: the swing is refused entirely rather than damaging the
	-- node for nothing. The player keeps the rock and gets a clear reason.
	if not InventoryService.CanFit(player, ore.Id, 1) then
		miningFeedback:FireClient(player, { Full = true })
		return
	end

	applyHit(player, node, state, ore)
end

function MiningService.Start()
	mineNodeRemote.OnServerEvent:Connect(onMineRequest)

	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil

		for _, state in pairs(nodeState) do
			state.contributions[player] = nil
			state.progress[player] = nil
		end
	end)

	local count = #CollectionService:GetTagged(TAG_ORE_NODE)
	print("MiningService: started. " .. tostring(count) .. " nodes available.")
end

return MiningService
