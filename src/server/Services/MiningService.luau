-- Server-authoritative mining.
--
-- The client sends INTENT ("I swung at this node"). This service decides
-- whether that was possible: is it a real node, is it alive, is the player
-- close enough, has their swing cooldown elapsed. Nothing the client sends is
-- trusted, including the timing.
--
-- A node holds a rolled mass and breaks in three stages. The first two stages
-- each drop 15-25% of that mass to whoever landed the breaking hit; the final
-- break splits everything remaining in proportion to hits landed. So a player
-- who turns up for the last swing takes only the share their damage earned,
-- while a solo miner gets the whole final chunk.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OreData = require(ReplicatedStorage.Shared.Data.OreData)
local InventoryService = require(script.Parent.InventoryService)

local MiningService = {}

local TAG_ORE_NODE = "OreNode"
local MAX_MINE_DISTANCE = 18
local RESPAWN_SECONDS = 25
local MIN_SHRINK = 0.28

local mineNodeRemote = ReplicatedStorage.Remotes.MineNode
local miningFeedback = ReplicatedStorage.Remotes.MiningFeedback

local nodeState = {}
local lastSwing = {}

local function captureShape(node)
	local origin = node:GetPivot().Position
	local pieces = {}

	for _, p in ipairs(node:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(pieces, {
				part = p,
				size = p.Size,
				offset = p.Position - origin,
				rotation = p.CFrame - p.CFrame.Position,
			})
		end
	end

	return origin, pieces
end

-- Chunk masses are rolled once per node so the same node always breaks into
-- the same pieces, and the final chunk absorbs the remainder exactly.
local function rollChunks(massKg, seed)
	local rng = Random.new(seed)
	local chunks = {}
	local used = 0

	for _ = 1, OreData.StageCount - 1 do
		local share = rng:NextNumber(OreData.StageShareMin, OreData.StageShareMax)
		local chunk = massKg * share
		used = used + chunk
		table.insert(chunks, chunk)
	end

	table.insert(chunks, math.max(0, massKg - used))
	return chunks
end

local function getState(node)
	local state = nodeState[node]

	if state == nil then
		local maxHits = node:GetAttribute("MaxHits")
		local massKg = node:GetAttribute("MassKg")

		if maxHits == nil or massKg == nil then
			return nil
		end

		local origin, pieces = captureShape(node)
		local seed = math.floor(origin.X * 13 + origin.Y * 7 + origin.Z * 3)

		state = {
			hitsLeft = maxHits,
			maxHits = maxHits,
			massKg = massKg,
			chunks = rollChunks(massKg, seed),
			stage = 1,
			hitsPerStage = math.max(1, math.ceil(maxHits / OreData.StageCount)),
			contributions = {},
			origin = origin,
			pieces = pieces,
			emitter = node:FindFirstChild("Debris", true),
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
			piece.part.Transparency = if visible then 0 else 1
			piece.part.CanCollide = visible
		end
	end
end

local function burst(state, count)
	if state.emitter ~= nil and state.emitter.Parent ~= nil then
		state.emitter:Emit(count)
	end
end

local function award(player, oreId, massKg, isFinal)
	if massKg <= 0 then
		return
	end

	local added = InventoryService.Add(player, oreId, massKg)

	if added > 0 then
		miningFeedback:FireClient(player, {
			OreId = oreId,
			Mass = added,
			Final = isFinal,
		})
	end

	-- Bag filled mid-chunk: say so rather than silently dropping the rest.
	if added < massKg - 0.001 then
		miningFeedback:FireClient(player, { Full = true })
	end
end

local function resetNode(state)
	state.hitsLeft = state.maxHits
	state.stage = 1
	state.contributions = {}
	state.depleted = false

	applyScale(state, 1)
	setVisible(state, true)
end

local function depleteNode(node, state, ore)
	state.depleted = true
	burst(state, 34)
	setVisible(state, false)

	local finalChunk = state.chunks[OreData.StageCount] or 0

	local totalHits = 0
	for _, hits in pairs(state.contributions) do
		totalHits = totalHits + hits
	end

	if totalHits > 0 and finalChunk > 0 then
		for player, hits in pairs(state.contributions) do
			if player.Parent ~= nil then
				award(player, ore.Id, finalChunk * (hits / totalHits), true)
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

	local hitsLanded = state.maxHits - state.hitsLeft

	local remaining = state.hitsLeft / state.maxHits
	applyScale(state, MIN_SHRINK + (1 - MIN_SHRINK) * remaining)
	burst(state, 8)

	if state.hitsLeft <= 0 then
		depleteNode(node, state, ore)
		return
	end

	-- Stage boundary: the player who landed this hit takes the chunk.
	if state.stage < OreData.StageCount and hitsLanded >= state.stage * state.hitsPerStage then
		burst(state, 20)
		award(player, ore.Id, state.chunks[state.stage] or 0, false)
		state.stage = state.stage + 1
	end
end

local function onMineRequest(player, node)
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

	-- Full bag refuses the swing outright rather than damaging the node for
	-- nothing, so the player keeps the rock and gets a clear reason.
	if InventoryService.GetFreeSpace(player) <= 0 then
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
		end
	end)

	local count = #CollectionService:GetTagged(TAG_ORE_NODE)
	print("MiningService: started. " .. tostring(count) .. " nodes available.")
end

return MiningService
