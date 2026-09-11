--!strict

local CollectionService = game:GetService("CollectionService")

local Theme = require(script.Parent.Theme)

type AnyMap = { [string]: any }

export type MountResult = {
	supported: boolean,
	styleSheet: Instance?,
	styleLink: Instance?,
}

local StyleOS = {}

-- These tokens describe component behavior rather than one-off screen values. They are also
-- mirrored onto the optional StyleSheet so Studio's Style Editor can discover them.
StyleOS.Tokens = table.freeze({
	Control = table.freeze({
		MinimumHitTarget = 48,
		CompactHitTarget = 44,
		FocusStroke = 2,
	}),
	Card = table.freeze({
		Inset = Theme.Spacing.L,
		Gap = Theme.Spacing.M,
		AccentWidth = 4,
	}),
	Tile = table.freeze({
		Height = 96,
		CompactHeight = 88,
		PreviewHeight = 44,
	}),
	Motion = table.freeze({
		Fast = 0.12,
		Calm = 0.22,
		HoverTilt = -0.75,
	}),
	Opacity = table.freeze({
		Disabled = 0.44,
		Scrim = 0.3,
	}),
})

StyleOS.Tags = table.freeze({
	Pressable = "AuraRushPressable",
	ItemTile = "AuraRushItemTile",
	TileTitle = "AuraRushTileTitle",
	SupportText = "AuraRushSupportText",
	ResultAction = "AuraRushResultAction",
	CardDetail = "AuraRushCardDetail",
})

local STYLE_RULES = table.freeze({
	{
		selector = ".AuraRushPressable",
		properties = {
			Rotation = 0,
		},
		transitions = {
			Rotation = TweenInfo.new(
				StyleOS.Tokens.Motion.Fast,
				Enum.EasingStyle.Cubic,
				Enum.EasingDirection.Out
			),
		},
	},
	{
		selector = ".AuraRushPressable:Hover",
		properties = {
			Rotation = StyleOS.Tokens.Motion.HoverTilt,
		},
	},
	{
		selector = ".AuraRushPressable:Press",
		properties = {
			Rotation = 0,
		},
	},
	{
		selector = "@ReducedMotionEnabledTrue .AuraRushPressable",
		properties = {
			Rotation = 0,
		},
	},
	{
		selector = "@ViewportDisplaySizeSmall .AuraRushResultAction",
		properties = {
			TextSize = 12,
		},
	},
	{
		selector = "@PreferredTextSizeLarge .AuraRushSupportText",
		properties = {
			TextSize = 16,
		},
	},
	{
		selector = "@PreferredTextSizeLarger .AuraRushSupportText",
		properties = {
			TextSize = 17,
		},
	},
	{
		selector = "@PreferredTextSizeLargest .AuraRushSupportText",
		properties = {
			TextSize = 18,
		},
	},
	{
		selector = "@AuraRushNarrowGrid >> .AuraRushTileTitle",
		properties = {
			TextSize = 12,
			TextWrapped = true,
		},
	},
	{
		selector = "@AuraRushNarrowPanel >> .AuraRushCardDetail",
		properties = {
			TextSize = 14,
		},
	},
})

local function safelyDestroy(instance: Instance?): ()
	if instance then
		pcall(function()
			instance:Destroy()
		end)
	end
end

function StyleOS.tag(instance: Instance, tagName: string): ()
	instance:SetAttribute("AuraRushStyleTag_" .. tagName, true)
	pcall(function()
		CollectionService:AddTag(instance, tagName)
	end)
end

function StyleOS.makePressable(button: TextButton, label: string?, hint: string?): ()
	StyleOS.tag(button, StyleOS.Tags.Pressable)
	button.Active = true
	button.Selectable = true
	if label and label ~= "" then
		button:SetAttribute("AccessibilityLabel", label)
		button:SetAttribute("Tooltip", label)
	end
	if hint and hint ~= "" then
		button:SetAttribute("AccessibilityHint", hint)
	end
end

function StyleOS.attachQuery(parent: Instance, name: string, conditions: AnyMap): Instance?
	local query: Instance? = nil
	local ok = pcall(function()
		local dynamicQuery: any = Instance.new("StyleQuery")
		query = dynamicQuery
		dynamicQuery.Name = name
		dynamicQuery:SetConditions(conditions)
		dynamicQuery.Parent = parent
	end)
	parent:SetAttribute("AuraRushStyleQuery_" .. name, ok)
	if not ok then
		safelyDestroy(query)
		return nil
	end
	return query
end

function StyleOS.mount(screenGui: ScreenGui): MountResult
	local styleSheet: Instance? = nil
	local styleLink: Instance? = nil
	local ok = pcall(function()
		local dynamicSheet: any = Instance.new("StyleSheet")
		styleSheet = dynamicSheet
		dynamicSheet.Name = "AuraRushStyleSheet"
		dynamicSheet:SetAttribute("ColorSignal", Theme.Colors.Lime)
		dynamicSheet:SetAttribute("ColorAction", Theme.Colors.Cyan)
		dynamicSheet:SetAttribute("ColorSurface", Theme.Colors.Surface)
		dynamicSheet:SetAttribute("RadiusCard", Theme.Radius.Medium)
		dynamicSheet:SetAttribute("MotionFast", StyleOS.Tokens.Motion.Fast)

		for index, definition in STYLE_RULES do
			local dynamicRule: any = Instance.new("StyleRule")
			dynamicRule.Name = `AuraRushRule{index}`
			dynamicRule.Selector = definition.selector
			dynamicRule:SetProperties(definition.properties)
			if definition.transitions then
				pcall(function()
					dynamicRule:SetPropertyTransitions(definition.transitions)
				end)
			end
			dynamicRule.Parent = dynamicSheet
		end

		local dynamicLink: any = Instance.new("StyleLink")
		styleLink = dynamicLink
		dynamicLink.Name = "AuraRushStyleLink"
		dynamicSheet.Parent = screenGui
		dynamicLink.StyleSheet = dynamicSheet
		dynamicLink.Parent = screenGui
	end)

	if not ok then
		safelyDestroy(styleLink)
		safelyDestroy(styleSheet)
		styleSheet = nil
		styleLink = nil
	end
	screenGui:SetAttribute("AuraRushStyleSheetSupported", ok)

	return {
		supported = ok,
		styleSheet = styleSheet,
		styleLink = styleLink,
	}
end

return table.freeze(StyleOS)
