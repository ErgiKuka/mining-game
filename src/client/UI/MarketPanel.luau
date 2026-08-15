-- Sell ore. Shows the live price per ore, which one is in demand this window,
-- and how long that lasts.
--
-- Prices are computed locally from the shared Pricing module rather than
-- fetched, because pricing is a pure function of the clock. The server
-- recomputes at sell time and its number is the one that pays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OreData = require(ReplicatedStorage.Shared.Data.OreData)
local Pricing = require(ReplicatedStorage.Shared.Pricing)
local Theme = require(script.Parent.Theme)
local Panel = require(script.Parent.Panel)

local MarketPanel = {}

local panel
local list
local banner
local bannerTimer
local totalLabel
local sellAllButton
local emptyLabel
local onSell

local lastPayload = { Items = {} }

local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local rest = seconds % 60
	return string.format("%d:%02d", minutes, rest)
end

local function makeRow(oreId, units, order, parent)
	local ore = OreData.ById[oreId]
	if ore == nil then
		return 0
	end

	local price, isEvent = Pricing.GetPrice(oreId)
	local lineTotal = price * units

	local row = Theme.frame({
		Parent = parent,
		Color = Theme.Color.PanelSunken,
		Size = UDim2.new(1, 0, 0, 58),
		ZIndex = 4,
	})
	row.LayoutOrder = order
	Theme.corner(row, Theme.Size.CornerSmall)

	if isEvent then
		Theme.stroke(row, Theme.Color.Accent)
	end

	local swatch = Theme.frame({
		Parent = row,
		Color = ore.Color,
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(0, 10, 0.5, -17),
		ZIndex = 5,
	})
	Theme.corner(swatch, Theme.Size.CornerSmall)
	Theme.stroke(swatch, Theme.Color.Border)

	Theme.text({
		Parent = row,
		Text = ore.DisplayName .. "  x" .. tostring(units),
		Font = Theme.Font.Heading,
		TextSize = 14,
		Size = UDim2.new(0, 200, 0, 18),
		Position = UDim2.new(0, 54, 0, 10),
		ZIndex = 5,
	})

	local priceText = "$" .. tostring(price) .. " each"
	local priceColor = Theme.Color.TextDim

	if isEvent then
		priceText = priceText .. "   IN DEMAND"
		priceColor = Theme.Color.Accent
	elseif price > ore.ValuePerUnit then
		priceText = priceText .. "   (base $" .. tostring(ore.ValuePerUnit) .. ")"
	end

	Theme.text({
		Parent = row,
		Text = priceText,
		TextSize = 12,
		Color = priceColor,
		Size = UDim2.new(0, 240, 0, 16),
		Position = UDim2.new(0, 54, 0, 30),
		ZIndex = 5,
	})

	Theme.text({
		Parent = row,
		Text = "$" .. tostring(lineTotal),
		Font = Theme.Font.Number,
		TextSize = 16,
		Color = Theme.Color.Accent,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 100, 1, 0),
		Position = UDim2.new(1, -206, 0, 0),
		ZIndex = 5,
	})

	local sell = Theme.button({
		Parent = row,
		Text = "SELL",
		Color = Theme.Color.PanelRaised,
		TextSize = 13,
		Size = UDim2.new(0, 84, 0, 34),
		Position = UDim2.new(1, -96, 0.5, -17),
		ZIndex = 5,
	})
	Theme.stroke(sell, Theme.Color.Border)

	sell.Activated:Connect(function()
		if onSell then
			onSell(oreId)
		end
	end)

	return lineTotal
end

function MarketPanel.Build(parentGui)
	panel = Panel.new({
		Name = "Market",
		Title = "Market",
		Parent = parentGui,
		Size = UDim2.new(0, 600, 0, 500),
		Accent = Theme.Color.Success,
	})

	local body = Theme.frame({
		Parent = panel.content,
		Transparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
	})
	Theme.padding(body, 14)

	banner = Theme.frame({
		Parent = body,
		Color = Theme.Color.PanelRaised,
		Size = UDim2.new(1, 0, 0, 52),
		ZIndex = 4,
	})
	Theme.corner(banner, Theme.Size.CornerSmall)
	Theme.stroke(banner, Theme.Color.AccentDim)

	Theme.text({
		Parent = banner,
		Text = "DEMAND SPIKE",
		TextSize = 10,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(0, 300, 0, 14),
		Position = UDim2.new(0, 14, 0, 9),
		ZIndex = 5,
	})

	bannerTimer = Theme.text({
		Parent = banner,
		Text = "-",
		Font = Theme.Font.Heading,
		TextSize = 14,
		Color = Theme.Color.Accent,
		Size = UDim2.new(0, 400, 0, 20),
		Position = UDim2.new(0, 14, 0, 24),
		ZIndex = 5,
	})

	Theme.text({
		Parent = body,
		Text = "YOUR ORE",
		TextSize = 11,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 2, 0, 62),
		ZIndex = 4,
	})

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -146)
	scroll.Position = UDim2.new(0, 0, 0, 82)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.Color.Border
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 4
	scroll.Parent = body

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	list = scroll

	emptyLabel = Theme.text({
		Parent = body,
		Text = "Nothing to sell.",
		TextSize = 13,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 150),
		ZIndex = 4,
	})

	local footer = Theme.frame({
		Parent = body,
		Color = Theme.Color.PanelSunken,
		Size = UDim2.new(1, 0, 0, 54),
		Position = UDim2.new(0, 0, 1, -54),
		ZIndex = 4,
	})
	Theme.corner(footer, Theme.Size.CornerSmall)

	totalLabel = Theme.text({
		Parent = footer,
		Text = "$0",
		Font = Theme.Font.Number,
		TextSize = 20,
		Color = Theme.Color.Accent,
		Size = UDim2.new(0, 220, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		ZIndex = 5,
	})

	sellAllButton = Theme.button({
		Parent = footer,
		Text = "SELL EVERYTHING",
		Color = Theme.Color.Success,
		TextColor = Theme.Color.Backdrop,
		TextSize = 14,
		Size = UDim2.new(0, 190, 0, 38),
		Position = UDim2.new(1, -204, 0.5, -19),
		ZIndex = 5,
	})

	sellAllButton.Activated:Connect(function()
		if onSell then
			onSell("ALL")
		end
	end)

	-- Ticks while open so the demand window never shows a stale countdown.
	task.spawn(function()
		while true do
			if panel and panel:IsOpen() then
				MarketPanel.RefreshBanner()
			end
			task.wait(1)
		end
	end)

	return panel
end

function MarketPanel.RefreshBanner()
	local window = Pricing.GetWindow()
	local eventId = Pricing.GetEventOreId(window)
	local ore = OreData.ById[eventId]
	local name = eventId

	if ore then
		name = ore.DisplayName
	end

	bannerTimer.Text = name
		.. " +"
		.. tostring(math.floor(Pricing.EventBonus * 100))
		.. "%   -   "
		.. formatTime(Pricing.SecondsRemaining())
		.. " left"
end

function MarketPanel.OnSell(callback)
	onSell = callback
end

function MarketPanel.Update(payload)
	lastPayload = payload

	if list == nil then
		return
	end

	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local sorted = {}
	for oreId, units in pairs(payload.Items or {}) do
		table.insert(sorted, { id = oreId, units = units })
	end

	table.sort(sorted, function(a, b)
		return Pricing.GetPrice(a.id) * a.units > Pricing.GetPrice(b.id) * b.units
	end)

	local total = 0

	for index, entry in ipairs(sorted) do
		total = total + makeRow(entry.id, entry.units, index, list)
	end

	emptyLabel.Visible = #sorted == 0
	sellAllButton.Visible = #sorted > 0
	totalLabel.Text = "$" .. tostring(total)

	MarketPanel.RefreshBanner()
end

function MarketPanel.Show()
	if panel then
		MarketPanel.Update(lastPayload)
		panel:Show()
	end
end

return MarketPanel
