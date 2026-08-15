-- Persistent on-screen furniture: money, carry weight, action buttons, toasts.
--
-- Teleport buttons are disabled underground. The client hides them for clarity;
-- the server refuses them regardless, because a hidden button is not a rule.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local OreData = require(ReplicatedStorage.Shared.Data.OreData)
local Theme = require(script.Parent.Theme)

local Hud = {}

local player = Players.LocalPlayer

local moneyLabel
local weightLabel
local weightFill
local toast
local toastToken = 0
local teleportButtons = {}
local buttonHandlers = {}

local SURFACE_MARGIN = 30

local function makeActionButton(text, accent, parent, order)
	local button = Theme.button({
		Parent = parent,
		Text = text,
		Color = Theme.Color.Panel,
		Size = UDim2.new(0, 96, 0, 42),
		CornerRadius = Theme.Size.CornerSmall,
	})
	button.LayoutOrder = order
	Theme.stroke(button, Theme.Color.Border)

	local bar = Theme.frame({
		Parent = button,
		Color = accent,
		Size = UDim2.new(0, 3, 0, 18),
		Position = UDim2.new(0, 7, 0.5, -9),
		ZIndex = 2,
	})
	Theme.corner(bar, 2)

	return button
end

function Hud.Build(parentGui)
	local root = Instance.new("ScreenGui")
	root.Name = "Hud"
	root.ResetOnSpawn = false
	root.DisplayOrder = 5
	root.Parent = parentGui

	-- Top left: money, then carry weight beneath it.
	local moneyCard = Theme.frame({
		Parent = root,
		Color = Theme.Color.Panel,
		Transparency = 0.08,
		Size = UDim2.new(0, 190, 0, 46),
		Position = UDim2.new(0, 16, 0, 16),
	})
	Theme.corner(moneyCard, Theme.Size.Corner)
	Theme.stroke(moneyCard, Theme.Color.Border)

	local coin = Theme.frame({
		Parent = moneyCard,
		Color = Theme.Color.Accent,
		Size = UDim2.new(0, 24, 0, 24),
		Position = UDim2.new(0, 12, 0.5, -12),
		ZIndex = 2,
	})
	Theme.corner(coin, 12)

	Theme.text({
		Parent = coin,
		Text = "$",
		Font = Theme.Font.Heading,
		TextSize = 15,
		Color = Theme.Color.Panel,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
	})

	moneyLabel = Theme.text({
		Parent = moneyCard,
		Text = "0",
		Font = Theme.Font.Number,
		TextSize = 20,
		Size = UDim2.new(1, -56, 1, 0),
		Position = UDim2.new(0, 46, 0, 0),
		ZIndex = 2,
	})

	local weightCard = Theme.frame({
		Parent = root,
		Color = Theme.Color.Panel,
		Transparency = 0.08,
		Size = UDim2.new(0, 190, 0, 52),
		Position = UDim2.new(0, 16, 0, 70),
	})
	Theme.corner(weightCard, Theme.Size.Corner)
	Theme.stroke(weightCard, Theme.Color.Border)

	Theme.text({
		Parent = weightCard,
		Text = "CARRYING",
		TextSize = 10,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(1, -24, 0, 12),
		Position = UDim2.new(0, 12, 0, 8),
		ZIndex = 2,
	})

	weightLabel = Theme.text({
		Parent = weightCard,
		Text = "0.0 / 50 kg",
		Font = Theme.Font.Number,
		TextSize = 12,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -24, 0, 12),
		Position = UDim2.new(0, 12, 0, 8),
		ZIndex = 2,
	})

	local track = Theme.frame({
		Parent = weightCard,
		Color = Theme.Color.PanelSunken,
		Size = UDim2.new(1, -24, 0, 10),
		Position = UDim2.new(0, 12, 0, 28),
		ZIndex = 2,
	})
	Theme.corner(track, 5)

	weightFill = Theme.frame({
		Parent = track,
		Color = Theme.Color.Success,
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 3,
	})
	Theme.corner(weightFill, 5)

	-- Bottom right: action buttons.
	local dock = Theme.frame({
		Parent = root,
		Transparency = 1,
		Size = UDim2.new(0, 100, 0, 240),
		Position = UDim2.new(1, -16, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
	})

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = dock

	local backpackBtn = makeActionButton("BACKPACK", Theme.Color.Accent, dock, 1)
	local marketBtn = makeActionButton("MARKET", Theme.Color.Success, dock, 2)
	local shopBtn = makeActionButton("SHOP", Theme.Color.Info, dock, 3)
	local mineBtn = makeActionButton("MINE", Theme.Color.Danger, dock, 4)

	teleportButtons = { marketBtn, shopBtn, mineBtn }

	backpackBtn.Activated:Connect(function()
		if buttonHandlers.Backpack then
			buttonHandlers.Backpack()
		end
	end)

	marketBtn.Activated:Connect(function()
		if buttonHandlers.Teleport then
			buttonHandlers.Teleport("Market")
		end
	end)

	shopBtn.Activated:Connect(function()
		if buttonHandlers.Teleport then
			buttonHandlers.Teleport("Shop")
		end
	end)

	mineBtn.Activated:Connect(function()
		if buttonHandlers.Teleport then
			buttonHandlers.Teleport("Entrance")
		end
	end)

	toast = Theme.text({
		Parent = root,
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = 17,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 400, 0, 30),
		Position = UDim2.new(0.5, 0, 0.66, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	toast.TextStrokeTransparency = 0.35

	return root
end

function Hud.OnButton(name, callback)
	buttonHandlers[name] = callback
end

function Hud.SetMoney(amount)
	if moneyLabel then
		moneyLabel.Text = tostring(amount)
	end
end

function Hud.SetInventory(payload)
	if weightFill == nil then
		return
	end

	local weight = payload.Weight or 0
	local capacity = payload.Capacity or 1
	local ratio = math.clamp(weight / capacity, 0, 1)

	TweenService:Create(
		weightFill,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad),
		{ Size = UDim2.new(ratio, 0, 1, 0) }
	):Play()

	if ratio > 0.9 then
		weightFill.BackgroundColor3 = Theme.Color.Danger
	elseif ratio > 0.65 then
		weightFill.BackgroundColor3 = Theme.Color.Accent
	else
		weightFill.BackgroundColor3 = Theme.Color.Success
	end

	weightLabel.Text = string.format("%.1f / %d kg", weight, capacity)
end

-- Teleports are surface-only so a player cannot skip the climb out. The
-- server enforces it too; this only removes the temptation.
function Hud.UpdateLocation()
	local character = player.Character
	if character == nil then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end

	local aboveGround = root.Position.Y > GameConfig.Surface.Y - SURFACE_MARGIN

	for _, button in ipairs(teleportButtons) do
		button.Active = aboveGround
		button.AutoButtonColor = false

		if aboveGround then
			button.TextColor3 = Theme.Color.TextPrimary
			button.BackgroundTransparency = 0
		else
			button.TextColor3 = Theme.Color.TextDim
			button.BackgroundTransparency = 0.55
		end
	end
end

function Hud.Toast(text, color)
	if toast == nil then
		return
	end

	toastToken = toastToken + 1
	local token = toastToken

	toast.Text = text
	toast.TextColor3 = color or Theme.Color.TextPrimary

	task.delay(1.5, function()
		if token == toastToken then
			toast.Text = ""
		end
	end)
end

function Hud.OreToast(oreId, units, bonus)
	local ore = OreData.ById[oreId]
	local name = oreId

	if ore then
		name = ore.DisplayName
	end

	if bonus then
		Hud.Toast("+" .. tostring(units) .. " " .. name .. "  (bonus)", Theme.Color.Accent)
	else
		Hud.Toast("+" .. tostring(units) .. " " .. name, Theme.Color.Success)
	end
end

return Hud
