-- Depth readout and heat gauge. Only visible underground.
--
-- The curve is computed locally from the shared Hazard module rather than
-- pushed from the server: it is a pure function of position and gear, so both
-- sides derive the same number without a remote every tick. The server still
-- applies the damage; this only draws it.
--
-- Telegraphing matters here. Unexplained damage reads as a bug; a rising
-- gauge and a visible countdown make the same damage read as tension.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Hazard = require(ReplicatedStorage.Shared.Hazard)
local GearData = require(ReplicatedStorage.Shared.Data.GearData)
local Theme = require(script.Parent.Theme)

local DepthMeter = {}

local player = Players.LocalPlayer

local root
local card
local depthLabel
local heatFill
local heatLabel
local vignette
local cargoCard
local cargoLabel
local cargoDetail

local currentGearId = GearData.StartingGearId

local SHOW_ABOVE_DEPTH = 20

function DepthMeter.Build(parentGui)
	root = Instance.new("ScreenGui")
	root.Name = "DepthMeter"
	root.ResetOnSpawn = false
	root.DisplayOrder = 4
	root.IgnoreGuiInset = true
	root.Parent = parentGui

	-- Full-screen red wash driven by heat. Sits behind everything else.
	vignette = Theme.frame({
		Parent = root,
		Color = Color3.fromRGB(180, 40, 26),
		Transparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 1,
	})

	card = Theme.frame({
		Parent = root,
		Color = Theme.Color.Panel,
		Transparency = 0.1,
		Size = UDim2.new(0, 216, 0, 66),
		Position = UDim2.new(0.5, 0, 0, 14),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 2,
	})
	Theme.corner(card, Theme.Size.Corner)
	Theme.stroke(card, Theme.Color.Border)
	card.Visible = false

	Theme.text({
		Parent = card,
		Text = "DEPTH",
		TextSize = 10,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(0, 100, 0, 12),
		Position = UDim2.new(0, 12, 0, 8),
		ZIndex = 3,
	})

	depthLabel = Theme.text({
		Parent = card,
		Text = "0 m",
		Font = Theme.Font.Number,
		TextSize = 22,
		Size = UDim2.new(0, 120, 0, 24),
		Position = UDim2.new(0, 12, 0, 20),
		ZIndex = 3,
	})

	heatLabel = Theme.text({
		Parent = card,
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = 12,
		Color = Theme.Color.TextMuted,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 100, 0, 16),
		Position = UDim2.new(1, -112, 0, 16),
		ZIndex = 3,
	})

	local track = Theme.frame({
		Parent = card,
		Color = Theme.Color.PanelSunken,
		Size = UDim2.new(1, -24, 0, 8),
		Position = UDim2.new(0, 12, 1, -16),
		ZIndex = 3,
	})
	Theme.corner(track, 4)

	heatFill = Theme.frame({
		Parent = track,
		Color = Theme.Color.Success,
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 4,
	})
	Theme.corner(heatFill, 4)

	-- Cargo status. A penalty the player cannot see coming is indistinguishable
	-- from a bug, so this is always on screen while cargo is at risk.
	cargoCard = Theme.frame({
		Parent = root,
		Color = Theme.Color.Panel,
		Transparency = 0.1,
		Size = UDim2.new(0, 216, 0, 44),
		Position = UDim2.new(0.5, 0, 0, 88),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 2,
	})
	Theme.corner(cargoCard, Theme.Size.Corner)
	Theme.stroke(cargoCard, Theme.Color.Border)
	cargoCard.Visible = false

	cargoLabel = Theme.text({
		Parent = cargoCard,
		Text = "CARGO UNSECURED",
		Font = Theme.Font.Heading,
		TextSize = 12,
		Color = Theme.Color.Danger,
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.new(0, 12, 0, 8),
		ZIndex = 3,
	})

	cargoDetail = Theme.text({
		Parent = cargoCard,
		Text = "",
		TextSize = 11,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.new(0, 12, 0, 23),
		ZIndex = 3,
	})

	return root
end

-- Driven by CargoStatus from the server rather than computed locally: the
-- securing clock is server-owned, and the client must not be able to disagree
-- with it about whether a penalty applies.
function DepthMeter.SetCargo(payload)
	if cargoCard == nil then
		return
	end

	if payload.Secured then
		cargoCard.Visible = false
		return
	end

	cargoCard.Visible = true

	local remaining = payload.Remaining or 0

	if remaining > 0 and remaining < GameConfig.Cargo.SecureSeconds then
		cargoLabel.Text = "SECURING CARGO - " .. tostring(math.ceil(remaining)) .. "s"
		cargoLabel.TextColor3 = Theme.Color.Accent
		cargoDetail.Text = "Stay above ground to keep your haul"
	else
		cargoLabel.Text = "CARGO UNSECURED"
		cargoLabel.TextColor3 = Theme.Color.Danger
		cargoDetail.Text = string.format(
			"Leaving now costs %d%% of your ore",
			math.floor((payload.Fraction or 0) * 100)
		)
	end
end

function DepthMeter.SetGear(gearId)
	currentGearId = gearId or GearData.StartingGearId
end

function DepthMeter.Update()
	if card == nil then
		return
	end

	local character = player.Character
	if character == nil then
		card.Visible = false
		vignette.BackgroundTransparency = 1
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if hrp == nil or humanoid == nil then
		card.Visible = false
		vignette.BackgroundTransparency = 1
		return
	end

	local depth = Hazard.GetDepth(hrp.Position)

	if depth < SHOW_ABOVE_DEPTH then
		card.Visible = false
		vignette.BackgroundTransparency = 1
		return
	end

	card.Visible = true
	depthLabel.Text = tostring(math.floor(depth)) .. " m"

	local gear = GearData.Get(currentGearId)
	local resistance = gear.DamageResistance or 1
	local ratio = Hazard.GetHeatRatio(depth, resistance)
	local damage = Hazard.GetDamage(depth, resistance)

	TweenService:Create(
		heatFill,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad),
		{ Size = UDim2.new(math.max(ratio, 0.02), 0, 1, 0) }
	):Play()

	if damage <= 0 then
		heatFill.BackgroundColor3 = Theme.Color.Success
		heatLabel.Text = "STABLE"
		heatLabel.TextColor3 = Theme.Color.TextMuted
		vignette.BackgroundTransparency = 1
		return
	end

	local survival = Hazard.GetSurvivalSeconds(depth, resistance, humanoid.Health)

	if ratio > 0.62 then
		heatFill.BackgroundColor3 = Theme.Color.Danger
	elseif ratio > 0.3 then
		heatFill.BackgroundColor3 = Theme.Color.Accent
	else
		heatFill.BackgroundColor3 = Theme.Color.Success
	end

	-- Countdown, not a damage number: the useful question underground is
	-- "how long can I stay", not "how much am I taking".
	heatLabel.Text = tostring(math.floor(survival)) .. "s"

	if survival < 12 then
		heatLabel.TextColor3 = Theme.Color.Danger
	elseif survival < 30 then
		heatLabel.TextColor3 = Theme.Color.Accent
	else
		heatLabel.TextColor3 = Theme.Color.TextMuted
	end

	-- Wash only becomes visible once the situation is genuinely bad, so it
	-- means something when it appears.
	local healthRatio = 1 - (humanoid.Health / humanoid.MaxHealth)
	local intensity = math.max(ratio - 0.35, 0) * 0.5 + healthRatio * 0.28

	vignette.BackgroundTransparency = 1 - math.clamp(intensity, 0, 0.34)
end

return DepthMeter
