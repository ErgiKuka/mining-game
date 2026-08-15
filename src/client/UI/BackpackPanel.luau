-- Carried ore and equipped gear.
--
-- Read-only: everything shown here is pushed from the server. Nothing in this
-- file can change what the player owns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OreData = require(ReplicatedStorage.Shared.Data.OreData)
local Theme = require(script.Parent.Theme)
local Panel = require(script.Parent.Panel)

local BackpackPanel = {}

local panel
local list
local footerWeight
local footerValue
local gearName
local gearStats
local emptyLabel

local function makeOreRow(oreId, units, order, parent)
	local ore = OreData.ById[oreId]
	if ore == nil then
		return
	end

	local row = Theme.frame({
		Parent = parent,
		Color = Theme.Color.PanelSunken,
		Size = UDim2.new(1, 0, 0, 52),
		ZIndex = 4,
	})
	row.LayoutOrder = order
	Theme.corner(row, Theme.Size.CornerSmall)

	-- Colour swatch stands in for an icon; ore colours already exist in data.
	local swatch = Theme.frame({
		Parent = row,
		Color = ore.Color,
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(0, 9, 0.5, -17),
		ZIndex = 5,
	})
	Theme.corner(swatch, Theme.Size.CornerSmall)
	Theme.stroke(swatch, Theme.Color.Border)

	Theme.text({
		Parent = row,
		Text = ore.DisplayName,
		Font = Theme.Font.Heading,
		TextSize = 14,
		Size = UDim2.new(0, 150, 0, 18),
		Position = UDim2.new(0, 52, 0, 8),
		ZIndex = 5,
	})

	Theme.text({
		Parent = row,
		Text = string.format("%.1f kg each  -  $%d each", ore.WeightKg, ore.ValuePerUnit),
		TextSize = 12,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(0, 200, 0, 16),
		Position = UDim2.new(0, 52, 0, 27),
		ZIndex = 5,
	})

	Theme.text({
		Parent = row,
		Text = "x" .. tostring(units),
		Font = Theme.Font.Number,
		TextSize = 16,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 60, 0, 18),
		Position = UDim2.new(1, -140, 0, 8),
		ZIndex = 5,
	})

	Theme.text({
		Parent = row,
		Text = string.format("%.1f kg", ore.WeightKg * units),
		TextSize = 12,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 60, 0, 16),
		Position = UDim2.new(1, -140, 0, 27),
		ZIndex = 5,
	})

	Theme.text({
		Parent = row,
		Text = "$" .. tostring(ore.ValuePerUnit * units),
		Font = Theme.Font.Number,
		TextSize = 16,
		Color = Theme.Color.Accent,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 110, 1, 0),
		Position = UDim2.new(1, -122, 0, 0),
		ZIndex = 5,
	})
end

function BackpackPanel.Build(parentGui)
	panel = Panel.new({
		Name = "Backpack",
		Title = "Backpack",
		Parent = parentGui,
		Size = UDim2.new(0, 560, 0, 480),
		Accent = Theme.Color.Accent,
	})

	local body = Theme.frame({
		Parent = panel.content,
		Transparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
	})
	Theme.padding(body, 14)

	-- Equipped gear. Real data only; no placeholder armour slots, because a
	-- slot for a system that does not exist is a drawing, not a feature.
	local gearCard = Theme.frame({
		Parent = body,
		Color = Theme.Color.PanelRaised,
		Size = UDim2.new(1, 0, 0, 62),
		ZIndex = 4,
	})
	Theme.corner(gearCard, Theme.Size.CornerSmall)

	local gearSwatch = Theme.frame({
		Parent = gearCard,
		Color = Theme.Color.AccentDim,
		Size = UDim2.new(0, 40, 0, 40),
		Position = UDim2.new(0, 11, 0.5, -20),
		ZIndex = 5,
	})
	Theme.corner(gearSwatch, Theme.Size.CornerSmall)

	Theme.text({
		Parent = gearSwatch,
		Text = "P",
		Font = Theme.Font.Heading,
		TextSize = 18,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 6,
	})

	Theme.text({
		Parent = gearCard,
		Text = "EQUIPPED",
		TextSize = 10,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(0, 200, 0, 14),
		Position = UDim2.new(0, 62, 0, 12),
		ZIndex = 5,
	})

	gearName = Theme.text({
		Parent = gearCard,
		Text = "-",
		Font = Theme.Font.Heading,
		TextSize = 15,
		Size = UDim2.new(0, 240, 0, 20),
		Position = UDim2.new(0, 62, 0, 26),
		ZIndex = 5,
	})

	gearStats = Theme.text({
		Parent = gearCard,
		Text = "",
		TextSize = 12,
		Color = Theme.Color.TextMuted,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(1, -212, 0, 0),
		ZIndex = 5,
	})

	Theme.text({
		Parent = body,
		Text = "CARRIED ORE",
		TextSize = 11,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 2, 0, 74),
		ZIndex = 4,
	})

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -158)
	scroll.Position = UDim2.new(0, 0, 0, 94)
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
		Text = "Nothing carried. Head down the mine.",
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
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 1, -50),
		ZIndex = 4,
	})
	Theme.corner(footer, Theme.Size.CornerSmall)

	footerWeight = Theme.text({
		Parent = footer,
		Text = "0.0 / 50 kg",
		Font = Theme.Font.Number,
		TextSize = 15,
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		ZIndex = 5,
	})

	footerValue = Theme.text({
		Parent = footer,
		Text = "$0",
		Font = Theme.Font.Number,
		TextSize = 18,
		Color = Theme.Color.Accent,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(1, -214, 0, 0),
		ZIndex = 5,
	})

	return panel
end

function BackpackPanel.Update(payload)
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
		local oreA = OreData.ById[a.id]
		local oreB = OreData.ById[b.id]
		if oreA == nil or oreB == nil then
			return a.id < b.id
		end
		return oreA.ValuePerUnit * a.units > oreB.ValuePerUnit * b.units
	end)

	local totalValue = 0

	for index, entry in ipairs(sorted) do
		makeOreRow(entry.id, entry.units, index, list)

		local ore = OreData.ById[entry.id]
		if ore then
			totalValue = totalValue + ore.ValuePerUnit * entry.units
		end
	end

	emptyLabel.Visible = #sorted == 0

	footerWeight.Text = string.format("%.1f / %d kg", payload.Weight or 0, payload.Capacity or 0)
	footerValue.Text = "$" .. tostring(totalValue)

	gearName.Text = payload.GearName or "-"

	if payload.SwingSeconds then
		gearStats.Text = string.format(
			"%.2fs swing   %d kg capacity",
			payload.SwingSeconds,
			payload.Capacity or 0
		)
	end
end

function BackpackPanel.Toggle()
	if panel then
		panel:Toggle()
	end
end

return BackpackPanel
