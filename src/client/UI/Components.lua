--!strict

local Theme = require(script.Parent.Theme)
local StyleOS = require(script.Parent.StyleOS)

export type InfoCardConfig = {
	layoutOrder: number,
	title: string,
	detail: string,
	hasActions: boolean,
	zIndex: number?,
	accent: Color3?,
}

local Components = {}

local function label(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	font: Enum.Font,
	zIndex: number
): TextLabel
	local result = Instance.new("TextLabel")
	result.Name = name
	result.Text = text
	result.ZIndex = zIndex
	Theme.styleText(result, size, font)
	result.Parent = parent
	return result
end

function Components.createInfoCard(
	parent: Instance,
	config: InfoCardConfig
): (Frame, TextLabel, TextLabel, Frame?)
	local zIndex = config.zIndex or 93
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.LayoutOrder = config.layoutOrder
	card.Size = UDim2.new(1, 0, 0, if config.hasActions then 136 else 82)
	card.ZIndex = zIndex
	Theme.styleCard(card)
	card.Parent = parent

	local accent = Instance.new("Frame")
	accent.Name = "Signal"
	accent.Position = UDim2.fromOffset(8, 12)
	accent.Size = UDim2.new(0, StyleOS.Tokens.Card.AccentWidth, 1, -24)
	accent.BackgroundColor3 = config.accent or Theme.Colors.Cyan
	accent.BorderSizePixel = 0
	accent.ZIndex = zIndex + 1
	Theme.addCorner(accent, Theme.Radius.Pill)
	accent.Parent = card

	local title =
		label(card, "CardTitle", config.title, Theme.TextSizes.Body, Theme.Fonts.Bold, zIndex + 1)
	title.Position = UDim2.fromOffset(22, 9)
	title.Size = UDim2.new(1, -38, 0, 28)

	local detail = label(
		card,
		"CardDetail",
		config.detail,
		Theme.TextSizes.Caption,
		Theme.Fonts.Regular,
		zIndex + 1
	)
	detail.Position = UDim2.fromOffset(22, 38)
	detail.Size = UDim2.new(1, -38, 0, if config.hasActions then 34 else 36)
	detail.TextColor3 = Theme.Colors.TextMuted
	StyleOS.tag(detail, StyleOS.Tags.CardDetail)

	local actionRow: Frame? = nil
	if config.hasActions then
		local row = Instance.new("Frame")
		row.Name = "Actions"
		row.Position = UDim2.fromOffset(14, 80)
		row.Size = UDim2.new(1, -28, 0, 48)
		row.BackgroundTransparency = 1
		row.ZIndex = zIndex + 1
		row.Parent = card
		actionRow = row
	end

	return card, title, detail, actionRow
end

function Components.createResultMetric(
	parent: Instance,
	name: string,
	index: number,
	titleText: string,
	detailText: string,
	accentColor: Color3
): TextLabel
	local metric = label(
		parent,
		name,
		`0{index}  {titleText}\n{detailText}`,
		Theme.TextSizes.Body,
		Theme.Fonts.Bold,
		1
	)
	metric.Size = UDim2.new(0.333, -8, 1, 0)
	metric.BackgroundColor3 = Theme.Colors.SurfaceRaised
	metric.BackgroundTransparency = 0.04
	metric.TextColor3 = Theme.Colors.TextMuted
	metric.TextXAlignment = Enum.TextXAlignment.Center
	Theme.addCorner(metric, Theme.Radius.Medium)
	Theme.addStroke(metric, accentColor, 0.64)

	local signal = Instance.new("Frame")
	signal.Name = "Signal"
	signal.AnchorPoint = Vector2.new(0.5, 1)
	signal.Position = UDim2.new(0.5, 0, 1, -8)
	signal.Size = UDim2.new(0.42, 0, 0, 3)
	signal.BackgroundColor3 = accentColor
	signal.BorderSizePixel = 0
	Theme.addCorner(signal, Theme.Radius.Pill)
	signal.Parent = metric

	return metric
end

function Components.createStatusDot(parent: GuiObject, color: Color3): Frame
	local dot = Instance.new("Frame")
	dot.Name = "StatusDot"
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.new(0, 11, 0.5, 0)
	dot.Size = UDim2.fromOffset(7, 7)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = parent.ZIndex + 1
	Theme.addCorner(dot, Theme.Radius.Pill)
	dot.Parent = parent
	return dot
end

return table.freeze(Components)
