-- Design tokens. Every piece of UI reads from here so the game has one look
-- instead of five. Change a colour once, it changes everywhere.

local Theme = {}

Theme.Color = {
	Backdrop = Color3.fromRGB(8, 9, 12),
	Panel = Color3.fromRGB(24, 26, 33),
	PanelRaised = Color3.fromRGB(33, 36, 45),
	PanelSunken = Color3.fromRGB(17, 19, 24),
	Border = Color3.fromRGB(52, 57, 70),

	TextPrimary = Color3.fromRGB(236, 238, 243),
	TextMuted = Color3.fromRGB(138, 145, 163),
	TextDim = Color3.fromRGB(96, 102, 118),

	Accent = Color3.fromRGB(232, 177, 76),
	AccentDim = Color3.fromRGB(140, 105, 44),
	Success = Color3.fromRGB(95, 191, 125),
	Danger = Color3.fromRGB(214, 88, 78),
	Info = Color3.fromRGB(96, 148, 196),
}

Theme.Font = {
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
	Number = Enum.Font.GothamBold,
}

Theme.Size = {
	Corner = 10,
	CornerSmall = 6,
	Pad = 12,
	ButtonHeight = 46,
}

-- Helpers so panels stay declarative instead of ten lines per element.

function Theme.corner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.Size.Corner)
	corner.Parent = instance
	return corner
end

function Theme.stroke(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Color.Border
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

function Theme.padding(instance, amount)
	local pad = Instance.new("UIPadding")
	local value = UDim.new(0, amount or Theme.Size.Pad)
	pad.PaddingTop = value
	pad.PaddingBottom = value
	pad.PaddingLeft = value
	pad.PaddingRight = value
	pad.Parent = instance
	return pad
end

function Theme.text(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = props.Font or Theme.Font.Body
	label.TextSize = props.TextSize or 14
	label.TextColor3 = props.Color or Theme.Color.TextPrimary
	label.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	label.Text = props.Text or ""
	label.Size = props.Size or UDim2.new(1, 0, 1, 0)
	label.Position = props.Position or UDim2.new(0, 0, 0, 0)
	label.ZIndex = props.ZIndex or 1
	label.Parent = props.Parent
	return label
end

function Theme.frame(props)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = props.Color or Theme.Color.Panel
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.Size or UDim2.new(1, 0, 1, 0)
	frame.Position = props.Position or UDim2.new(0, 0, 0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	frame.ZIndex = props.ZIndex or 1
	frame.Parent = props.Parent
	return frame
end

function Theme.button(props)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = props.Color or Theme.Color.PanelRaised
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = props.Font or Theme.Font.Heading
	button.TextSize = props.TextSize or 14
	button.TextColor3 = props.TextColor or Theme.Color.TextPrimary
	button.Text = props.Text or ""
	button.Size = props.Size or UDim2.new(1, 0, 0, Theme.Size.ButtonHeight)
	button.Position = props.Position or UDim2.new(0, 0, 0, 0)
	button.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	button.ZIndex = props.ZIndex or 1
	button.Parent = props.Parent

	Theme.corner(button, props.CornerRadius or Theme.Size.CornerSmall)

	-- Hover feedback. The base colour is captured in a closure rather than
	-- stored on the Instance: Roblox Instances reject arbitrary fields, and
	-- assigning one throws at runtime.
	local base = button.BackgroundColor3

	button.MouseEnter:Connect(function()
		if button.Active then
			button.BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.12)
		end
	end)

	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = base
	end)

	return button
end

return Theme
