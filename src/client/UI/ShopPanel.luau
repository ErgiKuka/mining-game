-- Gear shop. Upgrades only, so every tier renders in one of four states:
-- owned, equipped, affordable, or too expensive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearData = require(ReplicatedStorage.Shared.Data.GearData)
local Theme = require(script.Parent.Theme)
local Panel = require(script.Parent.Panel)

local ShopPanel = {}

local panel
local list
local balanceLabel
local onBuy

local currentGearId = GearData.StartingGearId
local currentBalance = 0

local function statChip(text, parent, x)
	local chip = Theme.frame({
		Parent = parent,
		Color = Theme.Color.Panel,
		Size = UDim2.new(0, 104, 0, 22),
		Position = UDim2.new(0, x, 0, 44),
		ZIndex = 5,
	})
	Theme.corner(chip, 4)

	Theme.text({
		Parent = chip,
		Text = text,
		TextSize = 11,
		Color = Theme.Color.TextMuted,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 6,
	})

	return chip
end

local function makeGearRow(gear, order, parent)
	local currentGear = GearData.Get(currentGearId)
	local owned = gear.TierIndex <= currentGear.TierIndex
	local equipped = gear.Id == currentGearId
	local affordable = currentBalance >= gear.Cost

	local row = Theme.frame({
		Parent = parent,
		Color = Theme.Color.PanelSunken,
		Size = UDim2.new(1, 0, 0, 78),
		ZIndex = 4,
	})
	row.LayoutOrder = order
	Theme.corner(row, Theme.Size.CornerSmall)

	if equipped then
		Theme.stroke(row, Theme.Color.Accent)
	end

	local swatch = Theme.frame({
		Parent = row,
		Color = gear.HeadColor,
		Size = UDim2.new(0, 40, 0, 40),
		Position = UDim2.new(0, 12, 0, 10),
		ZIndex = 5,
	})
	Theme.corner(swatch, Theme.Size.CornerSmall)
	Theme.stroke(swatch, Theme.Color.Border)

	local nameColor = Theme.Color.TextPrimary
	if owned then
		nameColor = Theme.Color.TextMuted
	end

	Theme.text({
		Parent = row,
		Text = gear.DisplayName,
		Font = Theme.Font.Heading,
		TextSize = 15,
		Color = nameColor,
		Size = UDim2.new(0, 220, 0, 20),
		Position = UDim2.new(0, 62, 0, 12),
		ZIndex = 5,
	})

	statChip(string.format("%.2fs swing", gear.SwingSeconds), row, 62)
	statChip(string.format("%d kg carry", gear.CapacityKg), row, 172)

	local action = Theme.button({
		Parent = row,
		Text = "BUY",
		Size = UDim2.new(0, 130, 0, 40),
		Position = UDim2.new(1, -144, 0.5, -20),
		ZIndex = 5,
	})

	local price = Theme.text({
		Parent = row,
		Text = "$" .. tostring(gear.Cost),
		Font = Theme.Font.Number,
		TextSize = 15,
		Color = Theme.Color.Accent,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 120, 1, 0),
		Position = UDim2.new(1, -278, 0, 0),
		ZIndex = 5,
	})

	if equipped then
		action.Text = "EQUIPPED"
		action.BackgroundColor3 = Theme.Color.AccentDim
		action.TextColor3 = Theme.Color.TextPrimary
		action.Active = false
		price.Text = ""
	elseif owned then
		action.Text = "OWNED"
		action.BackgroundColor3 = Theme.Color.Panel
		action.TextColor3 = Theme.Color.TextDim
		action.Active = false
		price.Text = ""
	elseif affordable then
		action.BackgroundColor3 = Theme.Color.Success
		action.TextColor3 = Theme.Color.Backdrop
		action.Active = true

		action.Activated:Connect(function()
			if onBuy then
				onBuy(gear.Id)
			end
		end)
	else
		action.Text = "TOO EXPENSIVE"
		action.TextSize = 11
		action.BackgroundColor3 = Theme.Color.Panel
		action.TextColor3 = Theme.Color.TextDim
		action.Active = false
		price.TextColor3 = Theme.Color.TextDim
	end

	Theme.stroke(action, Theme.Color.Border)
end

function ShopPanel.Build(parentGui)
	panel = Panel.new({
		Name = "Shop",
		Title = "Gear Shop",
		Parent = parentGui,
		Size = UDim2.new(0, 620, 0, 520),
		Accent = Theme.Color.Info,
	})

	local body = Theme.frame({
		Parent = panel.content,
		Transparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
	})
	Theme.padding(body, 14)

	local header = Theme.frame({
		Parent = body,
		Color = Theme.Color.PanelRaised,
		Size = UDim2.new(1, 0, 0, 46),
		ZIndex = 4,
	})
	Theme.corner(header, Theme.Size.CornerSmall)

	Theme.text({
		Parent = header,
		Text = "BALANCE",
		TextSize = 10,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(0, 200, 0, 12),
		Position = UDim2.new(0, 14, 0, 8),
		ZIndex = 5,
	})

	balanceLabel = Theme.text({
		Parent = header,
		Text = "$0",
		Font = Theme.Font.Number,
		TextSize = 18,
		Color = Theme.Color.Accent,
		Size = UDim2.new(0, 300, 0, 20),
		Position = UDim2.new(0, 14, 0, 22),
		ZIndex = 5,
	})

	Theme.text({
		Parent = header,
		Text = "Upgrades only. Each tier swings faster and carries more.",
		TextSize = 12,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 340, 1, 0),
		Position = UDim2.new(1, -354, 0, 0),
		ZIndex = 5,
	})

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -60)
	scroll.Position = UDim2.new(0, 0, 0, 60)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.Color.Border
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 4
	scroll.Parent = body

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	list = scroll

	return panel
end

function ShopPanel.OnBuy(callback)
	onBuy = callback
end

function ShopPanel.SetBalance(amount)
	currentBalance = amount

	if balanceLabel then
		balanceLabel.Text = "$" .. tostring(amount)
	end

	ShopPanel.Refresh()
end

function ShopPanel.SetGear(gearId)
	currentGearId = gearId or GearData.StartingGearId
	ShopPanel.Refresh()
end

function ShopPanel.Refresh()
	if list == nil then
		return
	end

	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, gear in ipairs(GearData.Tiers) do
		makeGearRow(gear, index, list)
	end
end

function ShopPanel.Show()
	if panel then
		ShopPanel.Refresh()
		panel:Show()
	end
end

return ShopPanel
