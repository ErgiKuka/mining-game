-- Studio-only movement helpers for inspecting the mine.
--
-- Hard-guarded on RunService:IsStudio(). This never runs on a live server,
-- so it cannot become an exploit surface. Do not remove that guard, and do
-- not move any of this to the server.
--
--   F  toggle fly (WASD + Space/Ctrl, relative to camera)
--   G  cycle walk speed: 16 -> 60 -> 150 -> 16
--   H  print current position and nearest tier

local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FLY_SPEED = 90
local SPEEDS = { 16, 60, 150 }

local flying = false
local speedIndex = 1
local flyConnection = nil

local function getCharacterParts()
	local character = player.Character
	if character == nil then
		return nil, nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function stopFlying()
	flying = false

	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end

	local root, humanoid = getCharacterParts()
	if root then
		root.Anchored = false
	end
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function startFlying()
	local root, humanoid = getCharacterParts()
	if root == nil or humanoid == nil then
		return
	end

	flying = true
	root.Anchored = true
	humanoid.PlatformStand = true

	flyConnection = RunService.RenderStepped:Connect(function(dt)
		local currentRoot = getCharacterParts()
		if currentRoot == nil then
			stopFlying()
			return
		end

		local direction = Vector3.zero

		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			direction = direction + camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			direction = direction - camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			direction = direction + camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			direction = direction - camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			direction = direction + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			direction = direction - Vector3.new(0, 1, 0)
		end

		if direction.Magnitude > 0 then
			currentRoot.CFrame = currentRoot.CFrame + direction.Unit * FLY_SPEED * dt
		end
	end)
end

local function onInput(input, processed)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F then
		if flying then
			stopFlying()
			print("[Dev] Fly OFF")
		else
			startFlying()
			print("[Dev] Fly ON - WASD, Space up, Ctrl down")
		end
	elseif input.KeyCode == Enum.KeyCode.G then
		local _, humanoid = getCharacterParts()
		if humanoid then
			speedIndex = speedIndex % #SPEEDS + 1
			humanoid.WalkSpeed = SPEEDS[speedIndex]
			print("[Dev] WalkSpeed = " .. tostring(SPEEDS[speedIndex]))
		end
	elseif input.KeyCode == Enum.KeyCode.H then
		local root = getCharacterParts()
		if root then
			local p = root.Position
			print(string.format("[Dev] Position: %.0f, %.0f, %.0f", p.X, p.Y, p.Z))
		end
	end
end

UserInputService.InputBegan:Connect(onInput)

player.CharacterAdded:Connect(function()
	if flying then
		stopFlying()
	end
end)

print("[Dev] DevTools loaded. F = fly, G = speed, H = position.")
