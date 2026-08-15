-- Client-side mining input and swing animation.
--
-- This fires INTENT only. The server decides whether a swing lands, so the
-- local cooldown here exists purely to avoid spamming the network - removing
-- it would gain a cheater nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GearData = require(ReplicatedStorage:WaitForChild("Shared").Data.GearData)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- WaitForChild, not direct indexing: client scripts can start before
-- ReplicatedStorage has finished replicating.
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local mineNodeRemote = remotes:WaitForChild("MineNode")

local MAX_REACH = 18

local holding = false
local equipped = nil
local lastSent = 0
local loadedTrack = nil

local function getGear()
	if equipped == nil then
		return GearData.Get(GearData.StartingGearId)
	end
	return GearData.Get(equipped:GetAttribute("GearId"))
end

-- Plays the uploaded swing animation for the equipped gear.
--
-- Rotating Motor6D.C0 by hand is NOT an option: Roblox's character animation
-- system owns those joints and the property is read-only. A published
-- animation asset is the only way to drive the arm, and it has the side
-- benefit of replicating, so other players see the swing too.
--
-- No-op while SwingAnimationId is unset, so mining still works without it.
local function playSwing()
	local character = player.Character
	if character == nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return
	end

	local id = getGear().SwingAnimationId
	if id == nil or id == "" then
		return
	end

	if loadedTrack == nil or loadedTrack.Animation.AnimationId ~= id then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		loadedTrack = animator:LoadAnimation(animation)
		loadedTrack.Priority = Enum.AnimationPriority.Action
	end

	loadedTrack:Play(0.05)
end

-- A node is a Model of several parts, so the part under the mouse has to be
-- resolved up to its tagged ancestor before anything is sent to the server.
local function resolveNode(target)
	if target == nil then
		return nil
	end

	local current = target.Parent

	while current ~= nil and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("OreId") ~= nil then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function trySwing()
	if equipped == nil then
		return
	end

	local node = resolveNode(mouse.Target)
	if node == nil then
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

	if (root.Position - node:GetPivot().Position).Magnitude > MAX_REACH then
		return
	end

	local now = os.clock()
	if now - lastSent < getGear().SwingSeconds then
		return
	end
	lastSent = now

	playSwing()
	mineNodeRemote:FireServer(node)
end

local function onCharacterAdded(character)
	equipped = nil
	loadedTrack = nil

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			equipped = child
		end
	end

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			equipped = child
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child == equipped then
			equipped = nil
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		holding = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		holding = false
	end
end)

RunService.Heartbeat:Connect(function()
	if holding then
		trySwing()
	end
end)

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end
