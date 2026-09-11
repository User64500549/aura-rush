--!strict

local Theme = {}

Theme.Colors = table.freeze({
	-- Editorial streetwear palette: dark ink, paper-white copy and a few deliberate signals.
	-- The legacy color aliases below stay public so older controllers keep working.
	Background = Color3.fromRGB(12, 13, 18),
	BackgroundSoft = Color3.fromRGB(19, 20, 27),
	Surface = Color3.fromRGB(27, 28, 36),
	SurfaceRaised = Color3.fromRGB(39, 40, 49),
	SurfaceSelected = Color3.fromRGB(214, 255, 73),
	Glass = Color3.fromRGB(245, 242, 234),
	Text = Color3.fromRGB(247, 244, 236),
	TextMuted = Color3.fromRGB(190, 188, 183),
	TextDim = Color3.fromRGB(132, 131, 136),
	Cyan = Color3.fromRGB(92, 174, 255),
	Magenta = Color3.fromRGB(255, 103, 97),
	Violet = Color3.fromRGB(92, 174, 255),
	Lime = Color3.fromRGB(214, 255, 73),
	Orange = Color3.fromRGB(255, 143, 92),
	Gold = Color3.fromRGB(255, 205, 92),
	Success = Color3.fromRGB(116, 225, 151),
	Warning = Color3.fromRGB(255, 195, 84),
	Error = Color3.fromRGB(255, 103, 97),
	Stroke = Color3.fromRGB(83, 84, 95),
	Black = Color3.fromRGB(0, 0, 0),
})

Theme.Semantic = table.freeze({
	Ink = Theme.Colors.Background,
	Paper = Theme.Colors.Text,
	Signal = Theme.Colors.Lime,
	Action = Theme.Colors.Cyan,
	Hot = Theme.Colors.Magenta,
	Chrome = Color3.fromRGB(207, 210, 220),
})

Theme.WorldPalettes = table.freeze({
	Lumenline = table.freeze({
		Base = Color3.fromRGB(25, 35, 58),
		Primary = Color3.fromRGB(77, 234, 255),
		Secondary = Color3.fromRGB(185, 255, 102),
		Accent = Color3.fromRGB(255, 79, 216),
	}),
	Cirrus = table.freeze({
		Base = Color3.fromRGB(47, 43, 82),
		Primary = Color3.fromRGB(255, 209, 102),
		Secondary = Color3.fromRGB(140, 108, 255),
		Accent = Color3.fromRGB(77, 234, 255),
	}),
})

Theme.Fonts = table.freeze({
	Regular = Enum.Font.Gotham,
	Medium = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Display = Enum.Font.GothamBlack,
})

Theme.TextSizes = table.freeze({
	Caption = 13,
	Body = 16,
	Button = 16,
	Subtitle = 22,
	Title = 32,
	Display = 46,
})

Theme.Spacing = table.freeze({
	XS = 4,
	S = 8,
	M = 12,
	L = 18,
	XL = 24,
	XXL = 32,
})

Theme.Radius = table.freeze({
	Small = UDim.new(0, 6),
	Medium = UDim.new(0, 10),
	Large = UDim.new(0, 16),
	Pill = UDim.new(1, 0),
})

export type ButtonVariant = "Primary" | "Secondary" | "Quiet" | "Danger"

function Theme.addCorner(parent: GuiObject, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Radius.Medium
	corner.Parent = parent
	return corner
end

function Theme.addStroke(parent: GuiObject, color: Color3?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or Theme.Colors.Stroke
	stroke.Transparency = if transparency == nil then 0.48 else transparency
	stroke.Thickness = 1
	stroke.Parent = parent
	return stroke
end

function Theme.addPadding(parent: GuiObject, amount: number?): UIPadding
	local value = amount or Theme.Spacing.L
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, value)
	padding.PaddingBottom = UDim.new(0, value)
	padding.PaddingLeft = UDim.new(0, value)
	padding.PaddingRight = UDim.new(0, value)
	padding.Parent = parent
	return padding
end

function Theme.addGradient(parent: GuiObject, colors: { Color3 }, rotation: number?): UIGradient
	local keypoints = table.create(#colors)
	local denominator = math.max(#colors - 1, 1)
	for index, color in colors do
		keypoints[index] = ColorSequenceKeypoint.new((index - 1) / denominator, color)
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(keypoints)
	gradient.Rotation = rotation or 0
	gradient.Parent = parent
	return gradient
end

function Theme.stylePanel(panel: GuiObject, elevated: boolean?)
	panel.BackgroundColor3 = if elevated then Theme.Colors.SurfaceRaised else Theme.Colors.Surface
	panel.BackgroundTransparency = if elevated then 0.02 else 0.06
	panel.BorderSizePixel = 0
	Theme.addCorner(panel, Theme.Radius.Large)
	Theme.addStroke(panel, nil, if elevated then 0.38 else 0.58)
end

function Theme.addAccentBand(parent: GuiObject, color: Color3?, width: number?): UIStroke
	-- A decorative Frame becomes a full-height UIListLayout item and pushes
	-- titles, objectives and buttons out of the card. A border has no layout box.
	local stroke = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Name = "AccentBand"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or Theme.Colors.Lime
	stroke.Thickness = math.clamp((width or 6) * 0.25, 1, 2)
	stroke.Transparency = 0.28
	stroke.Parent = parent
	return stroke
end

function Theme.styleText(label: TextLabel, size: number?, weight: Enum.Font?)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = weight or Theme.Fonts.Regular
	label.TextColor3 = Theme.Colors.Text
	label.TextSize = size or Theme.TextSizes.Body
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
end

function Theme.styleButton(button: TextButton, variant: ButtonVariant?)
	local chosen = variant or "Primary"
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Font = Theme.Fonts.Bold
	button.TextSize = Theme.TextSizes.Button
	button.TextWrapped = true
	button.TextColor3 = if chosen == "Primary" then Theme.Colors.Background else Theme.Colors.Text
	button.Selectable = true
	button.Active = true

	if chosen == "Primary" then
		button.BackgroundColor3 = Theme.Colors.Lime
	elseif chosen == "Danger" then
		button.BackgroundColor3 = Theme.Colors.Error
	elseif chosen == "Quiet" then
		button.BackgroundColor3 = Theme.Colors.BackgroundSoft
	else
		button.BackgroundColor3 = Theme.Colors.SurfaceRaised
	end

	Theme.addCorner(button, Theme.Radius.Medium)
	Theme.addStroke(
		button,
		if chosen == "Primary" then Theme.Colors.Lime else nil,
		if chosen == "Primary" then 0.05 else 0.58
	)
end

function Theme.setButtonSelected(button: TextButton, selected: boolean)
	button.BackgroundColor3 = if selected
		then Theme.Colors.SurfaceSelected
		else Theme.Colors.SurfaceRaised
	button.TextColor3 = if selected then Theme.Colors.Background else Theme.Colors.Text
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if selected then Theme.Colors.Lime else Theme.Colors.Stroke
		stroke.Transparency = if selected then 0 else 0.58
	end
end

function Theme.styleSectionLabel(label: TextLabel, accent: Color3?)
	label.Font = Theme.Fonts.Bold
	label.TextSize = Theme.TextSizes.Caption
	label.TextColor3 = accent or Theme.Colors.Lime
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Bottom
	label.TextWrapped = false
end

function Theme.styleCard(card: GuiObject, selected: boolean?)
	card.BackgroundColor3 = if selected then Theme.Colors.SurfaceRaised else Theme.Colors.Surface
	card.BackgroundTransparency = 0.02
	card.BorderSizePixel = 0
	Theme.addCorner(card, Theme.Radius.Medium)
	Theme.addStroke(
		card,
		if selected then Theme.Colors.Lime else Theme.Colors.Stroke,
		if selected then 0.08 else 0.54
	)
end

function Theme.styleNavTab(button: TextButton, selected: boolean)
	button.Font = Theme.Fonts.Bold
	button.TextSize = Theme.TextSizes.Caption
	button.TextXAlignment = Enum.TextXAlignment.Center
	button.BackgroundColor3 = if selected then Theme.Colors.Text else Theme.Colors.BackgroundSoft
	button.TextColor3 = if selected then Theme.Colors.Background else Theme.Colors.TextMuted
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if selected then Theme.Colors.Text else Theme.Colors.Stroke
		stroke.Transparency = if selected then 0.08 else 0.66
	end
end

function Theme.toneColor(tone: string): Color3
	if tone == "Success" then
		return Theme.Colors.Success
	elseif tone == "Warning" then
		return Theme.Colors.Warning
	elseif tone == "Error" then
		return Theme.Colors.Error
	end
	return Theme.Colors.Cyan
end

return table.freeze(Theme)
