-- Full-screen notices: the death screen, and the "you lost cargo by
-- disconnecting" explanation shown on the next join.
--
-- Both exist for the same reason. Ore vanishing without a stated cause is
-- indistinguishable from a bug, and a player who thinks the game ate their
-- haul stops trusting the game long before they stop playing it.
--
-- The death screen auto-clears on respawn. The logout notice needs an explicit
-- dismissal, because the event it describes happened while the player was not
-- looking at the screen.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local NoticePanel = {}

local player = Players.LocalPlayer

local gui
local veil
local card
local title
local subtitle
local statsHolder
local dismiss
local timerBadge
local timerLabel
local timerToken = 0
local onRespawn

local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function clearStats()
	for _, child in ipairs(statsHolder:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function addStat(label, value, color, order)
	local row = Theme.frame({
		Parent = statsHolder,
		Color = Theme.Color.PanelSunken,
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 12,
	})
	row.LayoutOrder = order
	Theme.corner(row, Theme.Size.CornerSmall)

	Theme.text({
		Parent = row,
		Text = label,
		TextSize = 12,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(0.6, -16, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		ZIndex = 13,
	})

	Theme.text({
		Parent = row,
		Text = value,
		Font = Theme.Font.Number,
		TextSize = 16,
		Color = color or Theme.Color.TextPrimary,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0.4, -16, 1, 0),
		Position = UDim2.new(0.6, 0, 0, 0),
		ZIndex = 13,
	})
end

local function show()
	gui.Enabled = true
	veil.BackgroundTransparency = 1
	card.BackgroundTransparency = 1

	TweenService:Create(veil, FADE, { BackgroundTransparency = 0.28 }):Play()
	TweenService:Create(card, FADE, { BackgroundTransparency = 0 }):Play()
end

function NoticePanel.Hide()
	timerToken = timerToken + 1

	if timerBadge then
		timerBadge.Visible = false
	end

	if gui then
		gui.Enabled = false
	end
end

function NoticePanel.OnRespawn(callback)
	onRespawn = callback
end

local function runCountdown(seconds)
	timerToken = timerToken + 1
	local token = timerToken

	timerBadge.Visible = true

	task.spawn(function()
		local remaining = seconds

		while remaining > 0 and token == timerToken do
			timerLabel.Text = tostring(math.ceil(remaining))

			if remaining <= 5 then
				timerLabel.TextColor3 = Theme.Color.Danger
			else
				timerLabel.TextColor3 = Theme.Color.TextPrimary
			end

			task.wait(0.25)
			remaining = remaining - 0.25
		end

		if token == timerToken then
			timerLabel.Text = "0"
		end
	end)
end

function NoticePanel.Build(parentGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "NoticePanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = parentGui

	veil = Theme.frame({
		Parent = gui,
		Color = Color3.fromRGB(4, 4, 6),
		Transparency = 0.28,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 10,
	})

	card = Theme.frame({
		Parent = gui,
		Color = Theme.Color.Panel,
		Size = UDim2.new(0, 380, 0, 300),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 11,
	})
	Theme.corner(card, Theme.Size.Corner)
	Theme.stroke(card, Theme.Color.Border)
	Theme.padding(card, 20)

	title = Theme.text({
		Parent = card,
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = 24,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 12,
	})

	subtitle = Theme.text({
		Parent = card,
		Text = "",
		TextSize = 13,
		Color = Theme.Color.TextMuted,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 0, 32),
		ZIndex = 12,
	})
	subtitle.TextWrapped = true

	statsHolder = Theme.frame({
		Parent = card,
		Transparency = 1,
		Size = UDim2.new(1, 0, 0, 140),
		Position = UDim2.new(0, 0, 0, 74),
		ZIndex = 12,
	})

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = statsHolder

	-- Countdown badge, top right of the card.
	timerBadge = Theme.frame({
		Parent = card,
		Color = Theme.Color.PanelSunken,
		Size = UDim2.new(0, 44, 0, 44),
		Position = UDim2.new(1, -44, 0, -4),
		ZIndex = 13,
	})
	Theme.corner(timerBadge, 22)
	Theme.stroke(timerBadge, Theme.Color.Danger, 2)
	timerBadge.Visible = false

	timerLabel = Theme.text({
		Parent = timerBadge,
		Text = "0",
		Font = Theme.Font.Number,
		TextSize = 18,
		Color = Theme.Color.TextPrimary,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 14,
	})

	dismiss = Theme.button({
		Parent = card,
		Text = "OK",
		Color = Theme.Color.PanelRaised,
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 1, -42),
		ZIndex = 12,
	})
	Theme.stroke(dismiss, Theme.Color.Border)
	dismiss.Activated:Connect(function()
		if card:GetAttribute("Mode") == "Death" then
			-- Skipping the wait; the server still checks the character is
			-- actually dead before honouring it.
			if onRespawn then
				onRespawn()
			end
		end

		NoticePanel.Hide()
	end)

	-- Respawning clears the death screen; no button needed for that case.
	player.CharacterAdded:Connect(function()
		if gui.Enabled and card:GetAttribute("Mode") == "Death" then
			NoticePanel.Hide()
		end
	end)

	return gui
end

function NoticePanel.ShowDeath(payload)
	if gui == nil then
		return
	end

	card:SetAttribute("Mode", "Death")

	title.Text = "YOU DIED"
	title.TextColor3 = Theme.Color.Danger
	subtitle.Text = "The heat got you. Some of your haul was left behind."

	clearStats()
	addStat("Depth", tostring(payload.Depth or 0) .. " m", Theme.Color.TextPrimary, 1)
	addStat(
		"Ore lost",
		string.format("%.1f kg", payload.LostMass or 0),
		Theme.Color.Danger,
		2
	)
	addStat(
		"Value lost",
		"$" .. tostring(payload.LostValue or 0),
		Theme.Color.Danger,
		3
	)

	dismiss.Text = "RESPAWN NOW"
	runCountdown(payload.RespawnSeconds or 15)
	show()
end

function NoticePanel.ShowNotice(payload)
	if gui == nil then
		return
	end

	card:SetAttribute("Mode", "Notice")

	title.Text = "CARGO LOST"
	title.TextColor3 = Theme.Color.Accent
	subtitle.Text = string.format(
		"You disconnected at %d m with your cargo unsecured, so %d%% of your ore was lost.",
		payload.Depth or 0,
		math.floor((payload.Fraction or 0) * 100)
	)

	clearStats()
	addStat("Depth on exit", tostring(payload.Depth or 0) .. " m", Theme.Color.TextPrimary, 1)
	addStat(
		"Ore lost",
		string.format("%.1f kg", payload.LostMass or 0),
		Theme.Color.Danger,
		2
	)
	addStat(
		"Value lost",
		"$" .. tostring(payload.LostValue or 0),
		Theme.Color.Danger,
		3
	)

	dismiss.Text = "OK"
	timerBadge.Visible = false
	show()
end

return NoticePanel
