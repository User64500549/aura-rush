--!strict

local Theme = require(script.Parent.Theme)
local StyleOS = require(script.Parent.StyleOS)

export type ItemOption = {
	id: string,
	label: string,
	color: Color3?,
	locked: boolean?,
	cost: number?,
}

local VisualItemTile = {}

local CATEGORY_MARKS: { [string]: string } = table.freeze({
	palette = "●",
	material = "▦",
	aura = "✦",
	pose = "↗",
	accent = "+",
})

local function label(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	font: Enum.Font
): TextLabel
	local result = Instance.new("TextLabel")
	result.Name = name
	result.Text = text
	Theme.styleText(result, size, font)
	result.Parent = parent
	return result
end

function VisualItemTile.create(parent: Instance, name: string, layoutOrder: number): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = name
	tile.LayoutOrder = layoutOrder
	tile.Size = UDim2.fromOffset(130, StyleOS.Tokens.Tile.Height)
	tile.Text = ""
	tile.TextTransparency = 1
	tile.TextStrokeTransparency = 1
	tile.ClipsDescendants = true
	Theme.styleButton(tile, "Secondary")
	StyleOS.makePressable(tile)
	StyleOS.tag(tile, StyleOS.Tags.ItemTile)
	tile.Parent = parent

	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.Position = UDim2.fromOffset(6, 6)
	preview.Size = UDim2.new(1, -12, 0, StyleOS.Tokens.Tile.PreviewHeight)
	preview.BackgroundColor3 = Theme.Colors.Violet
	preview.BorderSizePixel = 0
	preview.ZIndex = tile.ZIndex + 1
	Theme.addCorner(preview, Theme.Radius.Small)
	preview.Parent = tile

	local gradient = Instance.new("UIGradient")
	gradient.Name = "ColorWash"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.Violet),
		ColorSequenceKeypoint.new(1, Theme.Colors.BackgroundSoft),
	})
	gradient.Rotation = 18
	gradient.Parent = preview

	local grain = Instance.new("Frame")
	grain.Name = "Swatch"
	grain.AnchorPoint = Vector2.new(1, 0.5)
	grain.Position = UDim2.new(1, -6, 0.5, 0)
	grain.Size = UDim2.fromOffset(10, 30)
	grain.BackgroundColor3 = Theme.Colors.Text
	grain.BackgroundTransparency = 0.28
	grain.BorderSizePixel = 0
	grain.ZIndex = preview.ZIndex + 1
	Theme.addCorner(grain, Theme.Radius.Pill)
	grain.Parent = preview

	local mark = label(preview, "Mark", "●", 22, Theme.Fonts.Display)
	mark.Position = UDim2.fromOffset(8, 0)
	mark.Size = UDim2.new(1, -28, 1, 0)
	mark.TextColor3 = Theme.Colors.Text
	mark.TextXAlignment = Enum.TextXAlignment.Left
	mark.ZIndex = preview.ZIndex + 1

	local lock = label(preview, "Lock", "", 10, Theme.Fonts.Bold)
	lock.AnchorPoint = Vector2.new(1, 0)
	lock.Position = UDim2.new(1, -5, 0, 4)
	lock.Size = UDim2.fromOffset(48, 18)
	lock.BackgroundColor3 = Theme.Colors.Background
	lock.BackgroundTransparency = 0.16
	lock.TextColor3 = Theme.Colors.Gold
	lock.TextXAlignment = Enum.TextXAlignment.Center
	lock.ZIndex = preview.ZIndex + 2
	lock.Visible = false
	Theme.addCorner(lock, Theme.Radius.Pill)

	local displayName = label(tile, "DisplayName", "", 12, Theme.Fonts.Bold)
	displayName.Position = UDim2.fromOffset(8, 52)
	displayName.Size = UDim2.new(1, -16, 0, 22)
	displayName.TextXAlignment = Enum.TextXAlignment.Left
	displayName.TextTruncate = Enum.TextTruncate.AtEnd
	displayName.ZIndex = tile.ZIndex + 1
	StyleOS.tag(displayName, StyleOS.Tags.TileTitle)

	local status = label(tile, "Status", "", 10, Theme.Fonts.Medium)
	status.Position = UDim2.fromOffset(8, 73)
	status.Size = UDim2.new(1, -16, 0, 16)
	status.TextColor3 = Theme.Colors.TextDim
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.ZIndex = tile.ZIndex + 1

	local selected = label(preview, "Selected", "✓", 13, Theme.Fonts.Bold)
	selected.AnchorPoint = Vector2.new(1, 1)
	selected.Position = UDim2.new(1, -5, 1, -4)
	selected.Size = UDim2.fromOffset(22, 20)
	selected.BackgroundColor3 = Theme.Colors.Lime
	selected.BackgroundTransparency = 0
	selected.TextColor3 = Theme.Colors.Background
	selected.TextXAlignment = Enum.TextXAlignment.Center
	selected.ZIndex = preview.ZIndex + 3
	selected.Visible = false
	Theme.addCorner(selected, Theme.Radius.Pill)

	tile.Visible = false
	return tile
end

function VisualItemTile.render(
	tile: TextButton,
	option: ItemOption?,
	selected: boolean,
	category: string,
	locale: string
): ()
	if not option then
		tile.Visible = false
		tile:SetAttribute("OptionId", nil)
		tile:SetAttribute("Locked", nil)
		return
	end

	local locked = option.locked == true
	local preview = tile:FindFirstChild("Preview") :: Frame?
	local displayName = tile:FindFirstChild("DisplayName") :: TextLabel?
	local status = tile:FindFirstChild("Status") :: TextLabel?
	local swatch = if preview then preview:FindFirstChild("Swatch") :: Frame? else nil
	local mark = if preview then preview:FindFirstChild("Mark") :: TextLabel? else nil
	local lock = if preview then preview:FindFirstChild("Lock") :: TextLabel? else nil
	local selectedMark = if preview then preview:FindFirstChild("Selected") :: TextLabel? else nil
	local baseColor = option.color or Theme.Colors.Violet
	local shownColor = if locked then baseColor:Lerp(Theme.Colors.Surface, 0.56) else baseColor

	tile.Visible = true
	tile:SetAttribute("OptionId", option.id)
	tile:SetAttribute("Locked", locked)
	Theme.setButtonSelected(tile, selected)
	tile.TextColor3 = if locked then Theme.Colors.TextDim else Theme.Colors.Text

	local statusText = if locked
		then if option.cost
			then `{math.max(0, math.floor(option.cost))} Искр`
			else (if locale == "ru" then "Скоро" else "Soon")
		else if selected
			then (if locale == "ru" then "Выбрано" else "Selected")
			else (if locale == "ru" then "Примерить" else "Try on")
	local accessibleText = if locked
		then if option.cost
			then if locale == "ru"
				then `{option.label}. Нужно {math.max(0, math.floor(option.cost))} Искр`
				else `{option.label}. Costs {math.max(0, math.floor(option.cost))}`
			else `{option.label}. {statusText}`
		else `{option.label}. {statusText}`
	tile.Text = accessibleText
	tile.TextTransparency = 1
	tile:SetAttribute("AccessibilityLabel", accessibleText)
	tile:SetAttribute("Tooltip", accessibleText)

	if preview then
		preview.BackgroundColor3 = shownColor
		local gradient = preview:FindFirstChild("ColorWash") :: UIGradient?
		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, shownColor:Lerp(Color3.new(1, 1, 1), 0.12)),
				ColorSequenceKeypoint.new(1, shownColor:Lerp(Theme.Colors.Background, 0.54)),
			})
		end
	end
	if swatch then
		swatch.Visible = not locked
		swatch.BackgroundColor3 = shownColor:Lerp(Theme.Colors.Text, 0.46)
	end
	if mark then
		mark.Text = CATEGORY_MARKS[category] or "+"
		mark.TextColor3 = if locked then Theme.Colors.TextMuted else Theme.Colors.Text
	end
	if lock then
		lock.Text = if locale == "ru" then "Закрыто" else "Locked"
		lock.Visible = locked
	end
	if displayName then
		displayName.Text = option.label
		displayName.TextColor3 = if locked then Theme.Colors.TextDim else Theme.Colors.Text
	end
	if status then
		status.Text = statusText
		status.TextColor3 = if selected
			then Theme.Colors.Lime
			else if locked then Theme.Colors.Gold else Theme.Colors.TextDim
	end
	if selectedMark then
		selectedMark.Visible = selected and not locked
	end
end

function VisualItemTile.setCompact(tile: TextButton, compact: boolean): ()
	local displayName = tile:FindFirstChild("DisplayName") :: TextLabel?
	local status = tile:FindFirstChild("Status") :: TextLabel?
	local preview = tile:FindFirstChild("Preview") :: Frame?
	if preview then
		preview.Size =
			UDim2.new(1, -12, 0, if compact then 38 else StyleOS.Tokens.Tile.PreviewHeight)
	end
	if displayName then
		displayName.Position = UDim2.fromOffset(8, if compact then 46 else 52)
		displayName.TextSize = if compact then 11 else 12
	end
	if status then
		status.Position = UDim2.fromOffset(8, if compact then 66 else 73)
		status.TextSize = if compact then 9 else 10
	end
end

return table.freeze(VisualItemTile)
