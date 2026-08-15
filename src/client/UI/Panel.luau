-- Reusable modal panel: dimmed backdrop, title bar, close button, content area.
--
-- Only one panel is open at a time. The manager enforces that rather than each
-- panel tracking the others, so adding a new panel never touches existing ones.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Panel = {}
Panel.__index = Panel

local openPanel = nil

local TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Panel.new(config)
	local self = setmetatable({}, Panel)

	self.gui = Instance.new("ScreenGui")
	self.gui.Name = config.Name .. "Panel"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 10
	self.gui.Enabled = false
	self.gui.Parent = config.Parent

	local backdrop = Theme.frame({
		Parent = self.gui,
		Color = Theme.Color.Backdrop,
		Transparency = 0.45,
		Size = UDim2.new(1, 0, 1, 0),
	})

	-- Clicking outside closes. Cheaper than a dedicated close affordance on
	-- mobile and matches what players expect.
	local dismiss = Instance.new("TextButton")
	dismiss.Size = UDim2.new(1, 0, 1, 0)
	dismiss.BackgroundTransparency = 1
	dismiss.Text = ""
	dismiss.Parent = backdrop
	dismiss.Activated:Connect(function()
		self:Hide()
	end)

	local window = Theme.frame({
		Parent = self.gui,
		Color = Theme.Color.Panel,
		Size = config.Size or UDim2.new(0, 520, 0, 420),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
	})
	Theme.corner(window, Theme.Size.Corner)
	Theme.stroke(window, Theme.Color.Border)
	self.window = window

	local header = Theme.frame({
		Parent = window,
		Color = Theme.Color.PanelRaised,
		Size = UDim2.new(1, 0, 0, 48),
		ZIndex = 3,
	})
	Theme.corner(header, Theme.Size.Corner)

	-- Square off the bottom of the rounded header so it meets the body.
	Theme.frame({
		Parent = header,
		Color = Theme.Color.PanelRaised,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		ZIndex = 3,
	})

	Theme.text({
		Parent = header,
		Text = config.Title or config.Name,
		Font = Theme.Font.Heading,
		TextSize = 17,
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		ZIndex = 4,
	})

	local accent = Theme.frame({
		Parent = header,
		Color = config.Accent or Theme.Color.Accent,
		Size = UDim2.new(0, 4, 0, 20),
		Position = UDim2.new(0, 6, 0.5, -10),
		ZIndex = 4,
	})
	Theme.corner(accent, 2)

	local close = Theme.button({
		Parent = header,
		Text = "X",
		Color = Theme.Color.PanelSunken,
		TextColor = Theme.Color.TextMuted,
		Size = UDim2.new(0, 30, 0, 30),
		Position = UDim2.new(1, -40, 0.5, -15),
		ZIndex = 4,
	})
	close.Activated:Connect(function()
		self:Hide()
	end)

	self.content = Theme.frame({
		Parent = window,
		Color = Theme.Color.Panel,
		Transparency = 1,
		Size = UDim2.new(1, 0, 1, -48),
		Position = UDim2.new(0, 0, 0, 48),
		ZIndex = 3,
	})

	return self
end

function Panel:Show()
	if openPanel ~= nil and openPanel ~= self then
		openPanel:Hide()
	end

	openPanel = self
	self.gui.Enabled = true

	self.window.Size = UDim2.new(
		self.window.Size.X.Scale, self.window.Size.X.Offset,
		self.window.Size.Y.Scale, self.window.Size.Y.Offset
	)

	local target = self.window.Size
	self.window.Size = UDim2.new(target.X.Scale, target.X.Offset * 0.94, target.Y.Scale, target.Y.Offset * 0.94)
	TweenService:Create(self.window, TWEEN, { Size = target }):Play()

	if self.onShow then
		self.onShow()
	end
end

function Panel:Hide()
	self.gui.Enabled = false

	if openPanel == self then
		openPanel = nil
	end
end

function Panel:Toggle()
	if self.gui.Enabled then
		self:Hide()
	else
		self:Show()
	end
end

function Panel:IsOpen()
	return self.gui.Enabled
end

function Panel.CloseAll()
	if openPanel then
		openPanel:Hide()
	end
end

return Panel
