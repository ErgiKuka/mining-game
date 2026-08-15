-- Per-character setup on spawn. Currently the headlamp; inventory and gear
-- attachment will hang off the same CharacterAdded path.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local PlayerService = {}

local function attachHeadlamp(character)
	local head = character:WaitForChild("Head", 5)
	if head == nil then
		return
	end

	local existing = head:FindFirstChild("Headlamp")
	if existing then
		existing:Destroy()
	end

	local light = Instance.new("SpotLight")
	light.Name = "Headlamp"
	light.Range = GameConfig.Player.HeadlampRange
	light.Brightness = GameConfig.Player.HeadlampBrightness
	light.Angle = 75
	light.Face = Enum.NormalId.Front
	light.Color = Color3.fromRGB(255, 244, 214)
	light.Shadows = false -- shadow-casting lights are expensive with many players
	light.Parent = head
end

local function onCharacterAdded(character)
	attachHeadlamp(character)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)

	if player.Character then
		onCharacterAdded(player.Character)
	end
end

function PlayerService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	print("PlayerService: started.")
end

return PlayerService
