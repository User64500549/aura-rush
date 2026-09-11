--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Components = require(script.Parent.Components)
local PresentationPolicy = require(script.Parent.PresentationPolicy)
local StyleOS = require(script.Parent.StyleOS)
local Theme = require(script.Parent.Theme)
local VisualItemTile = require(script.Parent.VisualItemTile)
local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local Config = require(sharedRoot:WaitForChild("Config"))
local Localization = require(sharedRoot:WaitForChild("Localization"))

type AnyMap = { [string]: any }
export type StyleOption = {
	id: string,
	label: string,
	color: Color3?,
	locked: boolean?,
	cost: number?,
}

export type AccessibilitySettings = {
	reducedMotion: boolean,
	lowVfx: boolean,
	noFlashes: boolean,
	largeText: boolean,
	captions: boolean,
	highContrast: boolean,
	haptics: boolean,
	cameraShake: number,
	musicVolume: number,
	sfxVolume: number,
	ambienceVolume: number,
}

type AppFields = {
	ScreenGui: ScreenGui,
	Root: Frame,
	TopBar: Frame,
	ScreenContainer: Frame,
	OverlayContainer: Frame,
	Screens: { [string]: Frame },
	Refs: { [string]: Instance },
	Events: { [string]: BindableEvent },
	Connections: { RBXScriptConnection },
	State: AnyMap,
	Settings: AccessibilitySettings,
	Locale: string,
	ViewportConnection: RBXScriptConnection?,
}

local App = {}
App.__index = App
export type App = typeof(setmetatable({} :: AppFields, App))

local SCREEN_FOR_PHASE: { [string]: string } = {
	Waiting = "Hub",
	Intermission = "Hub",
	BriefChoice = "BriefChoice",
	ThreadRun = "ThreadRun",
	BeatLab = "BeatLab",
	PrismPuzzle = "PrismPuzzle",
	MixLab = "MixLab",
	Finale = "Finale",
	Results = "Results",
	Cleanup = "Hub",
}

local PHASE_LABELS: { [string]: string } = {
	Waiting = "Ждём новый раунд",
	Intermission = "Раунд скоро",
	BriefChoice = "Тема раунда",
	ThreadRun = "Погоня",
	BeatLab = "Бит-челлендж",
	PrismPuzzle = "Цветовой код",
	MixLab = "Гримерка",
	Finale = "Перекраска",
	Results = "Итоги",
	Cleanup = "Готовим новый раунд",
}

local CATEGORY_LABELS: { [string]: string } = {
	palette = "Палитра",
	material = "Фактура",
	aura = "Эффект",
	pose = "Поза",
	accent = "Деталь",
}

local QUEST_LABELS: { [string]: string } = table.freeze({
	complete_round = "Завершить Перекраску",
	collect_threads = "Собрать нити",
	hit_beats = "Попасть в ритм",
	hit_perfects = "Собрать идеальную серию",
	solve_prism = "Собрать Цветовой код",
	finish_style = "Закончить образ",
})

local PRISM_COLORS = {
	Theme.Colors.Cyan,
	Theme.Colors.Magenta,
	Theme.Colors.Gold,
	Theme.Colors.Lime,
}

local PRISM_GLYPHS = { "1", "2", "3", "4" }

local FIRST_SESSION_STARTED = table.freeze({
	PaletteChoice = true,
	Actions = true,
	Bloom = true,
	Complete = true,
})

local function hasEnteredFirstSession(profile: AnyMap): boolean
	local settings = profile.settings
	if type(settings) == "table" and settings.onboardingComplete == true then
		return true
	end
	local miracle = profile.firstMiracle
	return type(miracle) == "table" and FIRST_SESSION_STARTED[miracle.status] == true
end

local function localText(locale: string, key: string, args: AnyMap?): string
	if type(Localization.GetPlayerText) == "function" then
		return Localization.GetPlayerText(locale, key, args)
	end
	return Localization.Get(locale, key, args)
end

local function createFrame(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function createLabel(
	parent: Instance,
	name: string,
	text: string,
	size: number?,
	font: Enum.Font?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	Theme.styleText(label, size, font)
	label.Parent = parent
	return label
end

local function createButton(
	parent: Instance,
	name: string,
	text: string,
	variant: Theme.ButtonVariant?
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = UDim2.fromOffset(180, 52)
	Theme.styleButton(button, variant)
	StyleOS.makePressable(button, if text ~= "" then text else nil)
	button.Parent = parent
	return button
end

local function addSlidersIcon(button: TextButton)
	button.Text = ""
	for index, knobX in { 7, 19, 13 } do
		local line = Instance.new("Frame")
		line.Name = `Line{index}`
		line.Position = UDim2.fromOffset(11, 13 + (index - 1) * 10)
		line.Size = UDim2.fromOffset(26, 2)
		line.BackgroundColor3 = Theme.Colors.TextMuted
		line.BorderSizePixel = 0
		line.ZIndex = button.ZIndex + 1
		line.Parent = button

		local knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Position = UDim2.fromOffset(knobX, 1)
		knob.Size = UDim2.fromOffset(6, 6)
		knob.BackgroundColor3 = Theme.Colors.Lime
		knob.BorderSizePixel = 0
		Theme.addCorner(knob, Theme.Radius.Pill)
		knob.ZIndex = line.ZIndex + 1
		knob.Parent = line
	end
end

local function addList(parent: GuiObject, padding: number?, horizontal: boolean?): UIListLayout
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, padding or Theme.Spacing.M)
	list.FillDirection = if horizontal
		then Enum.FillDirection.Horizontal
		else Enum.FillDirection.Vertical
	list.HorizontalAlignment = if horizontal
		then Enum.HorizontalAlignment.Left
		else Enum.HorizontalAlignment.Center
	list.VerticalAlignment = if horizontal
		then Enum.VerticalAlignment.Center
		else Enum.VerticalAlignment.Top
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = parent
	return list
end

local function localizedIdentifier(locale: string, namespace: string, value: any): string
	if type(value) ~= "string" or value == "" then
		return ""
	end
	if type(Localization.GetIdentifier) == "function" then
		return Localization.GetIdentifier(locale, namespace, value)
	end
	return ""
end

local function localizedName(locale: string, _value: any, key: any): string
	if type(key) == "string" and Localization.Has(locale, key) then
		return localText(locale, key)
	end
	return ""
end

local function getBriefLabel(locale: string, brief: AnyMap?): (string, string)
	if not brief then
		return "Тема раунда",
			"Место / повод / неожиданный поворот"
	end
	local title = localizedName(
		locale,
		brief.Title or brief.title or brief.AestheticName or brief.aestheticName,
		brief.AestheticNameKey or brief.aestheticNameKey
	)
	if title == "" then
		local worldId = brief.WorldId or brief.worldId
		local occasionId = brief.OccasionId or brief.occasionId
		local aestheticId = brief.AestheticId or brief.aestheticId or brief.Id or brief.id
		local twistId = brief.TwistId or brief.twistId
		if type(Localization.GetBriefTitle) == "function" then
			title = Localization.GetBriefTitle(locale, worldId, occasionId, aestheticId, twistId)
		else
			title = localizedIdentifier(locale, "aesthetic", aestheticId)
		end
	end
	local parts = {
		localizedName(
			locale,
			brief.WorldName or brief.worldName,
			brief.WorldNameKey or brief.worldNameKey
		),
		localizedName(
			locale,
			brief.OccasionName or brief.occasionName,
			brief.OccasionNameKey or brief.occasionNameKey
		),
		localizedName(
			locale,
			brief.TwistName or brief.twistName,
			brief.TwistNameKey or brief.twistNameKey
		),
	}
	if parts[1] == "" then
		parts[1] = localizedIdentifier(locale, "world", brief.WorldId or brief.worldId)
	end
	if parts[2] == "" then
		parts[2] = localizedIdentifier(locale, "occasion", brief.OccasionId or brief.occasionId)
	end
	if parts[3] == "" then
		parts[3] = localizedIdentifier(locale, "twist", brief.TwistId or brief.twistId)
	end
	local visibleParts: { string } = {}
	for _, part in parts do
		if part ~= "" then
			table.insert(visibleParts, part)
		end
	end
	return if title == "" then "Тема раунда" else title, table.concat(visibleParts, " / ")
end

local function formatTime(seconds: number): string
	local safe = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(safe / 60), safe % 60)
end

local function createProgress(parent: Instance, name: string, color: Color3): (Frame, Frame)
	local track = createFrame(parent, name)
	track.BackgroundColor3 = Theme.Colors.Background
	track.BackgroundTransparency = 0.2
	track.ClipsDescendants = true
	track.Size = UDim2.new(1, 0, 0, 12)
	Theme.addCorner(track, Theme.Radius.Pill)

	local fill = createFrame(track, "Fill")
	fill.BackgroundColor3 = color
	fill.BackgroundTransparency = 0
	fill.Size = UDim2.fromScale(0, 1)
	Theme.addCorner(fill, Theme.Radius.Pill)
	return track, fill
end

function App.new(playerGui: PlayerGui): App
	local old = playerGui:FindFirstChild("AuraRushUI")
	if old then
		old:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AuraRushUI"
	screenGui.DisplayOrder = 20
	screenGui.IgnoreGuiInset = false
	screenGui.AutoLocalize = false
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local root = createFrame(screenGui, "AppRoot")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Colors.Background
	root.BackgroundTransparency = 1
	local styleMount = StyleOS.mount(screenGui)
	StyleOS.attachQuery(root, "AuraRushNarrowApp", {
		MaxSize = Vector2.new(760, math.huge),
	})

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "AccessibilityScale"
	uiScale.Scale = 1
	uiScale.Parent = root

	local topBar = createFrame(root, "TopBar")
	topBar.Position = UDim2.fromOffset(16, 10)
	topBar.Size = UDim2.new(1, -32, 0, 52)
	topBar.BackgroundColor3 = Theme.Colors.Surface
	topBar.BackgroundTransparency = 0.12
	Theme.addCorner(topBar, Theme.Radius.Medium)
	Theme.addStroke(topBar, Theme.Colors.Stroke, 0.48)
	Theme.addGradient(topBar, {
		Theme.Colors.SurfaceRaised,
		Theme.Colors.Surface,
		Theme.Colors.BackgroundSoft,
	}, 0)
	Theme.addAccentBand(topBar, Theme.Colors.Lime, 5)

	local screenContainer = createFrame(root, "ScreenStack")
	screenContainer.Position = UDim2.fromOffset(0, 68)
	screenContainer.Size = UDim2.new(1, 0, 1, -68)

	local overlayContainer = createFrame(root, "OverlayStack")
	overlayContainer.Size = UDim2.fromScale(1, 1)
	overlayContainer.ZIndex = 50

	local events: { [string]: BindableEvent } = {}
	for _, eventName in
		{
			"DismissOnboarding",
			"VoteBrief",
			"ChooseRoute",
			"BeatLanePressed",
			"BeatHit",
			"PrismInput",
			"StyleCategory",
			"StyleSelection",
			"StyleUnlock",
			"StyleUndo",
			"StyleRedo",
			"StyleRandomize",
			"SetStyleReady",
			"StylePreviewChanged",
			"PreviewRotate",
			"PreviewReset",
			"CaptureRequested",
			"SaveLook",
			"SaveRemix",
			"PostcardAction",
			"Requeue",
			"ActivateToken",
			"InviteRequested",
			"SettingsChanged",
			"LocalSettingsChanged",
			"PhaseChanged",
			"BeatConfigured",
			"SnapshotApplied",
			"ProfileUpdated",
		}
	do
		local event = Instance.new("BindableEvent")
		event.Name = eventName
		events[eventName] = event
	end

	local player = Players.LocalPlayer
	local self: App = setmetatable({
		ScreenGui = screenGui,
		Root = root,
		TopBar = topBar,
		ScreenContainer = screenContainer,
		OverlayContainer = overlayContainer,
		Screens = {},
		Refs = { AccessibilityScale = uiScale },
		Events = events,
		Connections = {},
		State = {
			Phase = "Loading",
			PendingPhase = "Waiting",
			RoundId = "",
			StateVersion = -1,
			BriefOptions = {},
			RouteChoices = {},
			RouteChoiceActive = false,
			SelectedBrief = nil,
			StyleOptions = {},
			StyleSelected = {},
			ActiveStyleCategory = "palette",
			OnboardingDismissed = player:GetAttribute("AuraRushOnboarded") == true,
			Capturing = false,
			PrismToken = 0,
			ReadOnly = false,
			RoundBundleSaved = false,
		},
		Settings = {
			reducedMotion = false,
			lowVfx = false,
			noFlashes = false,
			largeText = false,
			captions = true,
			highContrast = player:GetAttribute("AuraRushHighContrast") == true,
			haptics = true,
			cameraShake = 0.2,
			musicVolume = 0.7,
			sfxVolume = 0.7,
			ambienceVolume = 0.7,
		},
		-- This is a Russian-first experience. Account/Studio language must not
		-- silently turn only the localized half of the interface into English.
		Locale = Localization.NormalizeLocale(Config.UI.DefaultLocale),
		ViewportConnection = nil,
	}, App)
	if styleMount.styleSheet then
		self.Refs.StyleSheet = styleMount.styleSheet
	end
	if styleMount.styleLink then
		self.Refs.StyleLink = styleMount.styleLink
	end

	self:_buildTopBar()
	self:_buildScreens()
	self:_buildSettings()
	self:_bindPlatformAccessibility()
	self:_bindViewport()
	if self.Settings.highContrast then
		self:_applyHighContrast()
	end
	self:ShowScreen("Loading")

	return self
end

function App._buildTopBar(self: App)
	local logo =
		createLabel(self.TopBar, "Logo", "AURA RUSH", Theme.TextSizes.Subtitle, Theme.Fonts.Display)
	logo.Position = UDim2.fromOffset(18, 0)
	logo.Size = UDim2.fromOffset(156, 52)
	logo.TextColor3 = Theme.Colors.Text
	self.Refs.Logo = logo

	local phase = createLabel(
		self.TopBar,
		"Phase",
		"Ждём новый раунд",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	phase.AnchorPoint = Vector2.new(0, 0.5)
	phase.Position = UDim2.new(0, 176, 0.5, 0)
	phase.Size = UDim2.fromOffset(210, 34)
	phase.TextXAlignment = Enum.TextXAlignment.Center
	phase.BackgroundColor3 = Theme.Colors.BackgroundSoft
	phase.BackgroundTransparency = 0
	Theme.addCorner(phase, Theme.Radius.Pill)
	local phaseDot = Components.createStatusDot(phase, Theme.Colors.TextDim)
	self.Refs.PhaseLabel = phase
	self.Refs.PhaseDot = phaseDot

	local timer =
		createLabel(self.TopBar, "Timer", "0:00", Theme.TextSizes.Subtitle, Theme.Fonts.Bold)
	timer.AnchorPoint = Vector2.new(1, 0.5)
	timer.Position = UDim2.new(1, -64, 0.5, 0)
	timer.Size = UDim2.fromOffset(82, 38)
	timer.TextXAlignment = Enum.TextXAlignment.Center
	timer.BackgroundColor3 = Theme.Colors.Background
	timer.BackgroundTransparency = 0.2
	Theme.addCorner(timer, Theme.Radius.Pill)
	self.Refs.TimerLabel = timer

	local metaHud = createLabel(
		self.TopBar,
		"MetaHud",
		"Уровень 1 · 0 опыта",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	metaHud.AnchorPoint = Vector2.new(1, 0.5)
	metaHud.Position = UDim2.new(1, -158, 0.5, 0)
	metaHud.Size = UDim2.fromOffset(180, 34)
	metaHud.BackgroundColor3 = Theme.Colors.Background
	metaHud.BackgroundTransparency = 0.28
	metaHud.TextColor3 = Theme.Colors.Lime
	metaHud.TextXAlignment = Enum.TextXAlignment.Center
	Theme.addCorner(metaHud, Theme.Radius.Pill)
	self.Refs.MetaHud = metaHud

	local settings = createButton(self.TopBar, "Settings", "", "Quiet")
	settings.AnchorPoint = Vector2.new(1, 0.5)
	settings.Position = UDim2.new(1, -8, 0.5, 0)
	settings.Size = UDim2.fromOffset(48, 48)
	settings:SetAttribute(
		"Tooltip",
		if self.Locale == "ru" then "Настройки" else "Settings"
	)
	StyleOS.makePressable(
		settings,
		if self.Locale == "ru" then "Настройки" else "Settings",
		if self.Locale == "ru"
			then "Звук, эффекты и удобство"
			else "Sound, effects, and accessibility"
	)
	addSlidersIcon(settings)
	table.insert(
		self.Connections,
		settings.Activated:Connect(function()
			self:SetSettingsVisible(true)
		end)
	)
	self.Refs.SettingsButton = settings
end

function App._newScreen(self: App, name: string): Frame
	local screen = createFrame(self.ScreenContainer, name)
	screen.Size = UDim2.fromScale(1, 1)
	screen.Visible = false
	self.Screens[name] = screen
	return screen
end

function App._buildScreens(self: App)
	self:_buildLoading()
	self:_buildOnboarding()
	self:_buildHub()
	self:_buildBriefChoice()
	self:_buildThreadRun()
	self:_buildBeatLab()
	self:_buildPrismPuzzle()
	self:_buildMixLab()
	self:_buildFinale()
	self:_buildResults()
	self:_buildToast()
end

function App._buildLoading(self: App)
	local screen = self:_newScreen("Loading")
	local panel = createFrame(screen, "LoadingCard")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.45)
	panel.Size = UDim2.fromOffset(500, 230)
	Theme.stylePanel(panel, true)
	Theme.addPadding(panel, Theme.Spacing.XL)
	addList(panel, Theme.Spacing.M)

	local mark = createLabel(panel, "Mark", "AR", 40, Theme.Fonts.Display)
	mark.Size = UDim2.new(1, 0, 0, 54)
	mark.TextColor3 = Theme.Colors.Lime
	mark.TextXAlignment = Enum.TextXAlignment.Center

	local title =
		createLabel(panel, "Title", "AURA RUSH", Theme.TextSizes.Title, Theme.Fonts.Display)
	title.Size = UDim2.new(1, 0, 0, 42)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local subtitle =
		createLabel(panel, "Subtitle", "Готовим район...", Theme.TextSizes.Body)
	subtitle.Size = UDim2.new(1, 0, 0, 34)
	subtitle.TextColor3 = Theme.Colors.TextMuted
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.LoadingLabel = subtitle
end

function App._buildOnboarding(self: App)
	local screen = self:_newScreen("Onboarding")
	local panel = createFrame(screen, "Hero")
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 24, 1, -24)
	panel.Size = UDim2.fromOffset(520, 300)
	panel.BackgroundColor3 = Theme.Colors.Surface
	panel.BackgroundTransparency = 0.01
	Theme.addCorner(panel, Theme.Radius.Large)
	Theme.addStroke(panel, Theme.Colors.Stroke, 0.26)
	Theme.addGradient(
		panel,
		{ Theme.Colors.SurfaceRaised, Theme.Colors.Surface, Theme.Colors.BackgroundSoft },
		0
	)
	Theme.addAccentBand(panel, Theme.Colors.Lime, 8)
	panel.ClipsDescendants = true
	self.Refs.OnboardingHero = panel

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.Size = UDim2.fromScale(0.9, 0.86)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = Theme.Colors.Cyan
	content.Parent = panel
	local contentList = addList(content, Theme.Spacing.S)
	contentList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	self.Refs.OnboardingContent = content

	local kicker = createLabel(
		content,
		"Kicker",
		"ЦВЕТ • РИТМ • КОМАНДА",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	kicker.Size = UDim2.new(1, 0, 0, 18)
	kicker.TextColor3 = Theme.Colors.Lime
	kicker.TextXAlignment = Enum.TextXAlignment.Left
	self.Refs.OnboardingKicker = kicker

	local title = createLabel(
		content,
		"Title",
		"Оставь свой цвет",
		Theme.TextSizes.Title,
		Theme.Fonts.Display
	)
	title.Size = UDim2.new(1, 0, 0, 44)
	title.TextXAlignment = Enum.TextXAlignment.Left
	self.Refs.OnboardingTitle = title

	local loop = createLabel(
		content,
		"Loop",
		"МАРШРУТ → РИТМ → ОБЩИЙ ФИНАЛ",
		Theme.TextSizes.Subtitle,
		Theme.Fonts.Bold
	)
	loop.Size = UDim2.new(1, 0, 0, 28)
	loop.TextSize = 16
	loop.TextColor3 = Theme.Colors.Cyan
	loop.TextXAlignment = Enum.TextXAlignment.Left
	self.Refs.OnboardingLoop = loop

	local body = createLabel(
		content,
		"Body",
		"Иди по световой линии, поймай ритм и выбери палитру. Здесь решают действия и команда, а не внешность.",
		Theme.TextSizes.Body
	)
	body.Size = UDim2.new(1, 0, 0, 52)
	body.TextColor3 = Theme.Colors.TextMuted
	body.TextXAlignment = Enum.TextXAlignment.Left
	self.Refs.OnboardingBody = body

	local start = createButton(content, "Start", "Начать забег", "Primary")
	start.Size = UDim2.fromOffset(220, 50)
	table.insert(
		self.Connections,
		start.Activated:Connect(function()
			self:CompleteOnboarding()
			self:_emit("DismissOnboarding")
		end)
	)
	self.Refs.OnboardingStart = start
end

function App._buildHub(self: App)
	local screen = self:_newScreen("Hub")
	local card = createFrame(screen, "PortalCard")
	card.AnchorPoint = Vector2.new(0, 1)
	card.Position = UDim2.new(0, 22, 1, -22)
	card.Size = UDim2.fromOffset(390, 228)
	Theme.stylePanel(card, true)
	Theme.addAccentBand(card, Theme.Colors.Lime, 6)
	Theme.addPadding(card, Theme.Spacing.L)
	addList(card, Theme.Spacing.S)

	local icon = createLabel(card, "PortalIcon", "01", 48, Theme.Fonts.Display)
	icon.Size = UDim2.fromScale(1, 0)
	icon.TextColor3 = Theme.Colors.Lime
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.Visible = false
	self.Refs.HubIcon = icon

	local title = createLabel(
		card,
		"Title",
		"Собираем команду",
		Theme.TextSizes.Title,
		Theme.Fonts.Display
	)
	title.Size = UDim2.new(1, 0, 0, 38)
	title.TextXAlignment = Enum.TextXAlignment.Left
	self.Refs.HubTitle = title

	local brief = createLabel(
		card,
		"Brief",
		"Скоро выберем тему и сразу выйдем на маршрут.",
		Theme.TextSizes.Body
	)
	brief.Size = UDim2.new(1, 0, 0, 42)
	brief.TextColor3 = Theme.Colors.TextMuted
	brief.TextXAlignment = Enum.TextXAlignment.Left
	self.Refs.HubBrief = brief

	local tip = createLabel(
		card,
		"Tip",
		"Двигайся по лаймовой линии — это главный путь.",
		Theme.TextSizes.Caption
	)
	tip.Size = UDim2.new(1, 0, 0, 30)
	tip.TextColor3 = Theme.Colors.Lime
	tip.TextXAlignment = Enum.TextXAlignment.Left
	self.Refs.HubTip = tip

	local actions = createFrame(card, "HubActions")
	actions.Size = UDim2.new(1, 0, 0, 48)
	addList(actions, Theme.Spacing.M, true)
	self.Refs.HubActions = actions

	local invite = createButton(
		actions,
		"Invite",
		if self.Locale == "ru" then "Позвать друзей" else "Invite friends",
		"Secondary"
	)
	invite.Size = UDim2.fromScale(1, 1)
	table.insert(
		self.Connections,
		invite.Activated:Connect(function()
			self:_emit("InviteRequested", "hub")
		end)
	)
	self.Refs.HubInvite = invite

	local glowstorm = createButton(
		actions,
		"Glowstorm",
		localText(self.Locale, "product.server_glowstorm.name"),
		"Primary"
	)
	glowstorm.Size = UDim2.new(0.5, -6, 1, 0)
	glowstorm.Visible = false
	table.insert(
		self.Connections,
		glowstorm.Activated:Connect(function()
			if glowstorm:GetAttribute("CoolingDown") == true then
				return
			end
			glowstorm:SetAttribute("CoolingDown", true)
			glowstorm.Active = false
			glowstorm.AutoButtonColor = false
			self:_emit("ActivateToken", "glowstorm")
			task.delay(2, function()
				if glowstorm.Parent and glowstorm.Visible then
					glowstorm:SetAttribute("CoolingDown", false)
					glowstorm.Active = true
					glowstorm.AutoButtonColor = true
				end
			end)
		end)
	)
	self.Refs.HubGlowstorm = glowstorm
end

function App._buildBriefChoice(self: App)
	local screen = self:_newScreen("BriefChoice")
	local title = createLabel(
		screen,
		"Title",
		"Выберите тему раунда",
		Theme.TextSizes.Title,
		Theme.Fonts.Display
	)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 14)
	title.Size = UDim2.new(0.9, 0, 0, 38)
	title.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.BriefHeader = title

	local subtitle = createLabel(
		screen,
		"Subtitle",
		"Один голос на игрока. Решает команда.",
		Theme.TextSizes.Body
	)
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0, 50)
	subtitle.Size = UDim2.new(0.9, 0, 0, 28)
	subtitle.TextColor3 = Theme.Colors.TextMuted
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.BriefSubtitle = subtitle

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Cards"
	scroll.AnchorPoint = Vector2.new(0.5, 1)
	scroll.Position = UDim2.new(0.5, 0, 1, -16)
	scroll.Size = UDim2.new(0.94, 0, 0, 230)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.Colors.Cyan
	scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	scroll.Parent = screen
	Theme.addPadding(scroll, Theme.Spacing.S)
	local briefList = addList(scroll, Theme.Spacing.M, true)
	briefList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	self.Refs.BriefScroll = scroll
	self.Refs.BriefList = briefList

	for index = 1, 3 do
		local card = createFrame(scroll, `BriefCard{index}`)
		card.Size = UDim2.fromOffset(284, 208)
		card.BackgroundColor3 = Theme.Colors.Surface
		card.BackgroundTransparency = 0.02
		Theme.addCorner(card, Theme.Radius.Medium)
		Theme.addStroke(card, Theme.Colors.Stroke, 0.46)
		Theme.addAccentBand(card, PRISM_COLORS[index], 5)
		Theme.addPadding(card, 14)
		addList(card, 6)
		self.Refs[`BriefCard{index}`] = card

		local number = createLabel(
			card,
			"Number",
			string.format("0%d", index),
			Theme.TextSizes.Caption,
			Theme.Fonts.Bold
		)
		number.Size = UDim2.new(1, 0, 0, 18)
		number.TextColor3 = if index == 1
			then Theme.Colors.Cyan
			elseif index == 2 then Theme.Colors.Magenta
			else Theme.Colors.Gold

		local cardTitle = createLabel(
			card,
			"Title",
			"Тема загружается",
			Theme.TextSizes.Subtitle,
			Theme.Fonts.Display
		)
		cardTitle.Size = UDim2.new(1, 0, 0, 34)
		cardTitle.TextXAlignment = Enum.TextXAlignment.Left
		cardTitle.TextSize = 19
		self.Refs[`BriefTitle{index}`] = cardTitle

		local detail = createLabel(
			card,
			"Detail",
			"Место\nПовод\nПоворот",
			Theme.TextSizes.Body
		)
		detail.Size = UDim2.new(1, 0, 0, 50)
		detail.TextColor3 = Theme.Colors.TextMuted
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextSize = 14
		self.Refs[`BriefDetail{index}`] = detail

		local choose = createButton(card, "Choose", "Выбрать тему", "Primary")
		choose.Size = UDim2.new(1, 0, 0, 48)
		choose:SetAttribute("BriefIndex", index)
		table.insert(
			self.Connections,
			choose.Activated:Connect(function()
				local routeChoiceActive = self.State.RouteChoiceActive == true
				local options = if routeChoiceActive
					then self.State.RouteChoices :: { AnyMap }
					else self.State.BriefOptions :: { AnyMap }
				local selected = options[index]
				local selectionId = if selected then selected.Id or selected.id else nil
				if selected and type(selectionId) == "string" then
					if routeChoiceActive then
						self:_emit("ChooseRoute", selectionId)
					else
						self:_emit("VoteBrief", selectionId)
					end
					for cardIndex = 1, 3 do
						local cardButton = self.Refs[`BriefButton{cardIndex}`] :: TextButton?
						local choiceCard = self.Refs[`BriefCard{cardIndex}`] :: Frame?
						if cardButton then
							cardButton.Text = if cardIndex == index
								then if self.Locale == "ru"
									then if routeChoiceActive
										then "Маршрут выбран"
										else "Голос учтён"
									else if routeChoiceActive
										then "Route chosen"
										else "Vote saved"
								else localText(self.Locale, "button.choose")
						end
						if choiceCard then
							local selectedCard = cardIndex == index
							choiceCard:SetAttribute("Selected", selectedCard)
							choiceCard.BackgroundColor3 = if selectedCard
								then Theme.Colors.SurfaceRaised:Lerp(PRISM_COLORS[index], 0.12)
								else Theme.Colors.Surface
							local cardStroke = choiceCard:FindFirstChildOfClass("UIStroke")
							if cardStroke then
								cardStroke.Color = if selectedCard
									then PRISM_COLORS[index]
									else Theme.Colors.Stroke
								cardStroke.Transparency = if selectedCard then 0.08 else 0.46
								cardStroke.Thickness = if selectedCard then 2 else 1
							end
						end
					end
				end
			end)
		)
		self.Refs[`BriefButton{index}`] = choose
	end
	for index = 1, 3 do
		local current = self.Refs[`BriefButton{index}`] :: TextButton
		current.NextSelectionLeft = self.Refs[`BriefButton{math.max(1, index - 1)}`] :: TextButton
		current.NextSelectionRight = self.Refs[`BriefButton{math.min(3, index + 1)}`] :: TextButton
	end
end

function App._buildChallengeShell(
	self: App,
	name: string,
	kickerText: string,
	titleText: string,
	description: string
): (Frame, Frame)
	local screen = self:_newScreen(name)
	local card = createFrame(screen, "ChallengeCard")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.44)
	card.Size = UDim2.fromOffset(620, 330)
	Theme.stylePanel(card, true)
	Theme.addAccentBand(card, Theme.Colors.Cyan, 6)
	Theme.addPadding(card, Theme.Spacing.XL)
	addList(card, Theme.Spacing.M)
	local responsiveScale = Instance.new("UIScale")
	responsiveScale.Name = "ResponsiveScale"
	responsiveScale.Parent = card

	local kicker =
		createLabel(card, "Kicker", kickerText, Theme.TextSizes.Caption, Theme.Fonts.Bold)
	kicker.Size = UDim2.new(1, 0, 0, 22)
	kicker.TextColor3 = Theme.Colors.Cyan
	kicker.TextXAlignment = Enum.TextXAlignment.Center

	local title = createLabel(card, "Title", titleText, Theme.TextSizes.Title, Theme.Fonts.Display)
	title.Size = UDim2.new(1, 0, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local body = createLabel(card, "Description", description, Theme.TextSizes.Body)
	body.Size = UDim2.new(1, 0, 0, 54)
	body.TextColor3 = Theme.Colors.TextMuted
	body.TextXAlignment = Enum.TextXAlignment.Center

	return screen, card
end

function App._buildThreadRun(self: App)
	local _, card = self:_buildChallengeShell(
		"ThreadRun",
		"Этап 1 из 3",
		"Погоня",
		"Доберись до финиша и собери свои нити. Их никто не отнимет."
	)
	local _, fill = createProgress(card, "ThreadProgress", Theme.Colors.Lime)
	self.Refs.ThreadProgressFill = fill

	local stats =
		createLabel(card, "Stats", "Нити: 0 из 8", Theme.TextSizes.Subtitle, Theme.Fonts.Bold)
	stats.Size = UDim2.new(1, 0, 0, 48)
	stats.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.ThreadStats = stats

	local hint = createLabel(
		card,
		"Hint",
		"Не получается прыжок? Рядом есть простой маршрут.",
		Theme.TextSizes.Caption
	)
	hint.Size = UDim2.new(1, 0, 0, 30)
	hint.TextColor3 = Theme.Colors.Gold
	hint.TextXAlignment = Enum.TextXAlignment.Center
	-- This stage is played in the world; its HUD should not cover the route.
	local padding = card:FindFirstChildOfClass("UIPadding")
	if padding then
		padding.PaddingTop = UDim.new(0, 14)
		padding.PaddingBottom = UDim.new(0, 14)
		padding.PaddingLeft = UDim.new(0, 16)
		padding.PaddingRight = UDim.new(0, 16)
	end
	local list = card:FindFirstChildOfClass("UIListLayout")
	if list then
		list.Padding = UDim.new(0, 6)
	end
	for _, child in card:GetChildren() do
		if child:IsA("TextLabel") then
			child.TextXAlignment = Enum.TextXAlignment.Left
			child.Size = UDim2.new(
				1,
				0,
				0,
				if child.Name == "Description" then 38 else if child.Name == "Hint" then 28 else 24
			)
			child.TextSize = if child.Name == "Title"
				then 22
				else if child.Name == "Stats" then 16 else 13
		end
	end
end

function App._buildBeatLab(self: App)
	local _, card = self:_buildChallengeShell(
		"BeatLab",
		"Этап 2 из 3",
		"Бит-челлендж",
		"Нажимай нужную кнопку в ритм. Цвет всегда дублируется номером."
	)
	card.Size = UDim2.fromOffset(680, 390)

	local status = createLabel(
		card,
		"Status",
		"Серия: 0     Счёт: 0",
		Theme.TextSizes.Subtitle,
		Theme.Fonts.Bold
	)
	status.Size = UDim2.new(1, 0, 0, 38)
	status.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.BeatStatus = status

	local lanes = createFrame(card, "Lanes")
	lanes.Size = UDim2.new(1, 0, 0, 86)
	addList(lanes, Theme.Spacing.M, true)
	self.Refs.BeatLanes = lanes

	local keys = { "A", "S", "K", "L" }
	for index = 1, 4 do
		local lane = createButton(lanes, `Lane{index}`, `{index} / {keys[index]}`, "Secondary")
		lane.Size = UDim2.new(0.25, -10, 1, 0)
		lane.BackgroundColor3 = PRISM_COLORS[index]:Lerp(Theme.Colors.Background, 0.62)
		lane.TextColor3 = Theme.Colors.Text
		lane:SetAttribute("Lane", index)
		table.insert(
			self.Connections,
			lane.Activated:Connect(function()
				self:_emit("BeatLanePressed", index)
				self:PulseBeatLane(index)
			end)
		)
		self.Refs[`BeatLane{index}`] = lane
	end
	for index = 1, 4 do
		local current = self.Refs[`BeatLane{index}`] :: TextButton
		current.NextSelectionLeft = self.Refs[`BeatLane{math.max(1, index - 1)}`] :: TextButton
		current.NextSelectionRight = self.Refs[`BeatLane{math.min(4, index + 1)}`] :: TextButton
	end
end

function App._buildPrismPuzzle(self: App)
	local _, card = self:_buildChallengeShell(
		"PrismPuzzle",
		"Этап 3 из 3",
		"Цветовой код",
		"Запомни номера и повтори их по порядку."
	)
	card.Size = UDim2.fromOffset(680, 410)

	local sequenceFrame = createFrame(card, "Sequence")
	sequenceFrame.Size = UDim2.new(1, 0, 0, 58)
	addList(sequenceFrame, Theme.Spacing.M, true)
	for index = 1, 5 do
		local slot = createLabel(sequenceFrame, `Slot{index}`, ".", 24, Theme.Fonts.Display)
		slot.Size = UDim2.new(0.2, -10, 1, 0)
		slot.BackgroundColor3 = Theme.Colors.Background
		slot.BackgroundTransparency = 0.2
		slot.TextXAlignment = Enum.TextXAlignment.Center
		Theme.addCorner(slot, Theme.Radius.Medium)
		self.Refs[`PrismSlot{index}`] = slot
	end

	local inputs = createFrame(card, "Inputs")
	inputs.Size = UDim2.new(1, 0, 0, 78)
	addList(inputs, Theme.Spacing.M, true)
	for index = 1, 4 do
		local button = createButton(inputs, `Prism{index}`, tostring(index), "Secondary")
		button.Size = UDim2.new(0.25, -10, 1, 0)
		button.BackgroundColor3 = PRISM_COLORS[index]:Lerp(Theme.Colors.Background, 0.5)
		button.TextSize = 22
		table.insert(
			self.Connections,
			button.Activated:Connect(function()
				self:_emit("PrismInput", index)
			end)
		)
		self.Refs[`PrismButton{index}`] = button
	end
	for index = 1, 4 do
		local current = self.Refs[`PrismButton{index}`] :: TextButton
		current.NextSelectionLeft = self.Refs[`PrismButton{math.max(1, index - 1)}`] :: TextButton
		current.NextSelectionRight = self.Refs[`PrismButton{math.min(4, index + 1)}`] :: TextButton
	end

	local attempts = createLabel(
		card,
		"Attempts",
		"Попытка: 0 из 5",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	attempts.Size = UDim2.new(1, 0, 0, 30)
	attempts.TextColor3 = Theme.Colors.Gold
	attempts.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.PrismAttempts = attempts
end

function App._buildMixLab(self: App)
	local screen = self:_newScreen("MixLab")

	local preview = createFrame(screen, "Preview")
	preview.Position = UDim2.fromOffset(24, 18)
	preview.Size = UDim2.new(0.39, -30, 1, -42)
	preview.BackgroundColor3 = Theme.Colors.BackgroundSoft
	preview.BackgroundTransparency = 0
	Theme.addCorner(preview, Theme.Radius.Large)
	Theme.addStroke(preview, Theme.Colors.Stroke, 0.4)
	Theme.addGradient(
		preview,
		{ Theme.Colors.BackgroundSoft, Theme.Colors.Surface, Theme.Colors.Background },
		90
	)
	Theme.addAccentBand(preview, Theme.Colors.Magenta, 6)
	self.Refs.MixPreview = preview

	local previewLabel = createLabel(
		preview,
		"PreviewLabel",
		"Образ меняется сразу",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	previewLabel.Position = UDim2.fromOffset(18, 16)
	previewLabel.Size = UDim2.new(1, -36, 0, 24)
	previewLabel.TextColor3 = Theme.Colors.Cyan
	previewLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.MixPreviewLabel = previewLabel

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "AvatarViewport"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.49)
	viewport.Size = UDim2.new(1, -24, 1, -116)
	viewport.BackgroundColor3 = Theme.Colors.Background
	viewport.BackgroundTransparency = 0.46
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(130, 136, 184)
	viewport.LightColor = Color3.fromRGB(245, 248, 255)
	viewport.LightDirection = Vector3.new(-1, -0.7, -0.45)
	viewport.Active = true
	viewport.Selectable = false
	viewport.Parent = preview
	Theme.addCorner(viewport, Theme.Radius.Large)
	Theme.addStroke(viewport, Theme.Colors.Cyan, 0.74)

	local worldModel = Instance.new("WorldModel")
	worldModel.Name = "PreviewWorld"
	worldModel.Parent = viewport

	local previewCamera = Instance.new("Camera")
	previewCamera.Name = "PreviewCamera"
	previewCamera.FieldOfView = 36
	previewCamera.Parent = viewport
	viewport.CurrentCamera = previewCamera

	local fallback = createLabel(
		viewport,
		"Fallback",
		localText(self.Locale, "instruction.mix"),
		Theme.TextSizes.Body,
		Theme.Fonts.Bold
	)
	fallback.AnchorPoint = Vector2.new(0.5, 0.5)
	fallback.Position = UDim2.fromScale(0.5, 0.5)
	fallback.Size = UDim2.new(0.82, 0, 0, 72)
	fallback.TextColor3 = Theme.Colors.TextMuted
	fallback.TextXAlignment = Enum.TextXAlignment.Center

	local rotateLeft = createButton(preview, "RotateLeft", "-45", "Quiet")
	rotateLeft.AnchorPoint = Vector2.new(0, 1)
	rotateLeft.Position = UDim2.new(0, 14, 1, -14)
	rotateLeft.Size = UDim2.fromOffset(48, 48)
	rotateLeft.TextSize = 28
	StyleOS.makePressable(
		rotateLeft,
		if self.Locale == "ru" then "Повернуть влево" else "Rotate left"
	)
	table.insert(
		self.Connections,
		rotateLeft.Activated:Connect(function()
			self:_emit("PreviewRotate", -1)
		end)
	)

	local rotateRight = createButton(preview, "RotateRight", "+45", "Quiet")
	rotateRight.AnchorPoint = Vector2.new(1, 1)
	rotateRight.Position = UDim2.new(1, -14, 1, -14)
	rotateRight.Size = UDim2.fromOffset(48, 48)
	rotateRight.TextSize = 28
	StyleOS.makePressable(
		rotateRight,
		if self.Locale == "ru" then "Повернуть вправо" else "Rotate right"
	)
	table.insert(
		self.Connections,
		rotateRight.Activated:Connect(function()
			self:_emit("PreviewRotate", 1)
		end)
	)

	self.Refs.MixViewport = viewport
	self.Refs.MixWorldModel = worldModel
	self.Refs.MixPreviewCamera = previewCamera
	self.Refs.MixPreviewFallback = fallback
	self.Refs.MixRotateLeft = rotateLeft
	self.Refs.MixRotateRight = rotateRight

	local selected = createLabel(
		preview,
		"Selected",
		"Палитра · базовый цвет",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	selected.AnchorPoint = Vector2.new(0.5, 1)
	selected.Position = UDim2.new(0.5, 0, 1, -18)
	selected.Size = UDim2.new(0.9, 0, 0, 44)
	selected.TextColor3 = Theme.Colors.Lime
	selected.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.StyleSelectedLabel = selected

	local lab = createFrame(screen, "Lab")
	lab.Position = UDim2.new(0.39, 12, 0, 18)
	lab.Size = UDim2.new(0.61, -36, 1, -42)
	Theme.stylePanel(lab, true)
	Theme.addPadding(lab, Theme.Spacing.L)
	self.Refs.MixPanel = lab

	local header =
		createLabel(lab, "Header", "Гримерка", Theme.TextSizes.Title, Theme.Fonts.Display)
	header.Size = UDim2.new(1, 0, 0, 42)

	local tabs = createFrame(lab, "Tabs")
	tabs.Position = UDim2.fromOffset(0, 48)
	tabs.Size = UDim2.new(1, 0, 0, 50)
	addList(tabs, Theme.Spacing.S, true)
	for order, category in { "palette", "material", "aura", "pose", "accent" } do
		local tab = createButton(
			tabs,
			`Tab_{category}`,
			CATEGORY_LABELS[category] or localText(self.Locale, `style.category.{category}`),
			"Quiet"
		)
		tab.LayoutOrder = order
		tab.Size = UDim2.new(0.2, -7, 0, 50)
		tab.TextSize = 11
		table.insert(
			self.Connections,
			tab.Activated:Connect(function()
				self:SetActiveStyleCategory(category)
				self:_emit("StyleCategory", category)
			end)
		)
		self.Refs[`StyleTab_{category}`] = tab
	end

	local itemScroll = Instance.new("ScrollingFrame")
	itemScroll.Name = "Items"
	itemScroll.Position = UDim2.fromOffset(0, 108)
	itemScroll.Size = UDim2.new(1, 0, 1, -182)
	itemScroll.BackgroundTransparency = 1
	itemScroll.BorderSizePixel = 0
	itemScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	itemScroll.CanvasSize = UDim2.new()
	itemScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	itemScroll.ScrollBarThickness = 4
	itemScroll.ScrollBarImageColor3 = Theme.Colors.Cyan
	itemScroll.Parent = lab
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.CellSize = UDim2.new(0.25, -8, 0, StyleOS.Tokens.Tile.Height)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = itemScroll
	StyleOS.attachQuery(itemScroll, "AuraRushNarrowGrid", {
		MaxSize = Vector2.new(520, math.huge),
	})
	self.Refs.StyleItemScroll = itemScroll
	self.Refs.StyleGrid = grid

	for index = 1, 20 do
		local item = VisualItemTile.create(itemScroll, `StyleItem{index}`, index)
		table.insert(
			self.Connections,
			item.Activated:Connect(function()
				local optionId = item:GetAttribute("OptionId")
				if type(optionId) == "string" then
					if item:GetAttribute("Locked") == true then
						self:_emit("StyleUnlock", self.State.ActiveStyleCategory, optionId)
					else
						self:_emit("StyleSelection", self.State.ActiveStyleCategory, optionId)
					end
				end
			end)
		)
		self.Refs[`StyleItem{index}`] = item
	end

	local actions = createFrame(lab, "Actions")
	actions.AnchorPoint = Vector2.new(0, 1)
	actions.Position = UDim2.fromScale(0, 1)
	actions.Size = UDim2.new(1, 0, 0, 58)
	addList(actions, Theme.Spacing.S, true)

	local undo = createButton(actions, "Undo", "Назад", "Quiet")
	undo.Size = UDim2.fromOffset(78, 52)
	table.insert(
		self.Connections,
		undo.Activated:Connect(function()
			self:_emit("StyleUndo")
		end)
	)

	local redo = createButton(actions, "Redo", "Вперёд", "Quiet")
	redo.Size = UDim2.fromOffset(86, 52)
	table.insert(
		self.Connections,
		redo.Activated:Connect(function()
			self:_emit("StyleRedo")
		end)
	)

	local randomize =
		createButton(actions, "Randomize", localText(self.Locale, "button.randomize"), "Secondary")
	randomize.Size = UDim2.fromOffset(132, 52)
	table.insert(
		self.Connections,
		randomize.Activated:Connect(function()
			self:_emit("StyleRandomize")
		end)
	)

	local ready = createButton(actions, "Ready", localText(self.Locale, "button.ready"), "Primary")
	ready.Size = UDim2.new(1, -322, 0, 52)
	table.insert(
		self.Connections,
		ready.Activated:Connect(function()
			local nextReady = ready:GetAttribute("Ready") ~= true
			ready:SetAttribute("Ready", nextReady)
			ready.Text = if nextReady
				then "Готово, жду команду"
				else localText(self.Locale, "button.ready")
			self:_emit("SetStyleReady", nextReady)
		end)
	)
	self.Refs.StyleReadyButton = ready
	local firstTab = self.Refs.StyleTab_palette :: TextButton
	firstTab.NextSelectionLeft = rotateRight
	rotateRight.NextSelectionRight = firstTab
	rotateRight.NextSelectionLeft = rotateLeft
	rotateLeft.NextSelectionRight = rotateRight
	ready.NextSelectionUp = self.Refs.StyleItem1 :: TextButton
end

function App._buildFinale(self: App)
	local screen = self:_newScreen("Finale")
	local overlay = createFrame(screen, "FinaleCard")
	overlay.AnchorPoint = Vector2.new(0.5, 1)
	overlay.Position = UDim2.new(0.5, 0, 1, -28)
	overlay.Size = UDim2.fromOffset(620, 150)
	Theme.stylePanel(overlay, true)
	Theme.addPadding(overlay, Theme.Spacing.L)
	addList(overlay, Theme.Spacing.M)

	local title = createLabel(
		overlay,
		"Title",
		"Перекрашиваем район",
		Theme.TextSizes.Title,
		Theme.Fonts.Display
	)
	title.Size = UDim2.new(1, 0, 0, 46)
	title.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.FinaleTitle = title

	local _, fill = createProgress(overlay, "BloomProgress", Theme.Colors.Magenta)
	self.Refs.BloomProgressFill = fill

	local caption = createLabel(
		overlay,
		"Caption",
		"Ваши образы меняют свет, маршрут и музыку",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	caption.Size = UDim2.new(1, 0, 0, 28)
	caption.TextColor3 = Theme.Colors.Cyan
	caption.TextXAlignment = Enum.TextXAlignment.Center
end

function App._buildResults(self: App)
	local screen = self:_newScreen("Results")
	local panel = Instance.new("ScrollingFrame")
	panel.Name = "ResultsCard"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(720, 560)
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.new()
	panel.ScrollingDirection = Enum.ScrollingDirection.Y
	panel.ScrollBarThickness = 4
	panel.ScrollBarImageColor3 = Theme.Colors.Cyan
	panel.Parent = screen
	Theme.stylePanel(panel, true)
	Theme.addAccentBand(panel, Theme.Colors.Lime, 6)
	Theme.addPadding(panel, Theme.Spacing.XL)
	addList(panel, Theme.Spacing.S)
	self.Refs.ResultsCard = panel

	local eyebrow = createLabel(
		panel,
		"Eyebrow",
		if self.Locale == "ru" then "Раунд завершён" else "Round complete",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	eyebrow.Size = UDim2.new(1, 0, 0, 22)
	eyebrow.TextColor3 = Theme.Colors.Lime
	eyebrow.TextXAlignment = Enum.TextXAlignment.Center
	StyleOS.tag(eyebrow, StyleOS.Tags.SupportText)

	local title = createLabel(
		panel,
		"Title",
		if self.Locale == "ru"
			then "Ваш финальный образ готов"
			else "Your final look is ready",
		Theme.TextSizes.Title,
		Theme.Fonts.Display
	)
	title.Size = UDim2.new(1, 0, 0, 44)
	title.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.ResultsTitle = title

	local brief =
		createLabel(panel, "Brief", "Тема раунда", Theme.TextSizes.Body, Theme.Fonts.Bold)
	brief.Size = UDim2.new(1, 0, 0, 42)
	brief.TextColor3 = Theme.Colors.Cyan
	brief.TextXAlignment = Enum.TextXAlignment.Center
	self.Refs.ResultsBrief = brief

	local medals = createFrame(panel, "Medals")
	medals.Size = UDim2.new(1, 0, 0, 112)
	addList(medals, Theme.Spacing.M, true)
	self.Refs.ResultsMedals = medals
	for index, definition in
		{
			{
				ruTitle = "Погоня",
				ruDetail = "нити стиля",
				enTitle = "Run",
				enDetail = "style threads",
				color = Theme.Colors.Lime,
			},
			{
				ruTitle = "Бит",
				ruDetail = "чувство ритма",
				enTitle = "Beat",
				enDetail = "sense of rhythm",
				color = Theme.Colors.Cyan,
			},
			{
				ruTitle = "Код",
				ruDetail = "цвет и память",
				enTitle = "Code",
				enDetail = "color and memory",
				color = Theme.Colors.Gold,
			},
		}
	do
		local medal = Components.createResultMetric(
			medals,
			`Medal{index}`,
			index,
			if self.Locale == "ru" then definition.ruTitle else definition.enTitle,
			if self.Locale == "ru" then definition.ruDetail else definition.enDetail,
			definition.color
		)
		self.Refs[`ResultMedal{index}`] = medal
	end

	local summary = createFrame(panel, "Summary")
	summary.Size = UDim2.new(1, 0, 0, 66)
	local summaryLayout = addList(summary, Theme.Spacing.S, true)
	summaryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	self.Refs.ResultsSummary = summary

	local reward = createLabel(
		summary,
		"Reward",
		if self.Locale == "ru" then "Награда за раунд" else "Round reward",
		Theme.TextSizes.Body,
		Theme.Fonts.Bold
	)
	reward.Size = UDim2.new(0.5, -4, 1, 0)
	reward.BackgroundColor3 = Theme.Colors.BackgroundSoft
	reward.BackgroundTransparency = 0.08
	reward.TextColor3 = Theme.Colors.Lime
	reward.TextXAlignment = Enum.TextXAlignment.Center
	Theme.addCorner(reward, Theme.Radius.Medium)
	Theme.addStroke(reward, Theme.Colors.Lime, 0.68)
	self.Refs.ResultsReward = reward

	local metaSummary = createLabel(
		summary,
		"MetaSummary",
		if self.Locale == "ru" then "Уровень 1 · 0 опыта" else "Level 1 · 0 XP",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	metaSummary.Size = UDim2.new(0.5, -4, 1, 0)
	metaSummary.BackgroundColor3 = Theme.Colors.BackgroundSoft
	metaSummary.BackgroundTransparency = 0.08
	metaSummary.TextColor3 = Theme.Colors.Cyan
	metaSummary.TextXAlignment = Enum.TextXAlignment.Center
	Theme.addCorner(metaSummary, Theme.Radius.Medium)
	Theme.addStroke(metaSummary, Theme.Colors.Cyan, 0.72)
	self.Refs.ResultsMeta = metaSummary

	local routeSummary =
		createLabel(panel, "RouteSummary", "", Theme.TextSizes.Caption, Theme.Fonts.Bold)
	routeSummary.Size = UDim2.new(1, 0, 0, 30)
	routeSummary.TextColor3 = Theme.Colors.Cyan
	routeSummary.TextXAlignment = Enum.TextXAlignment.Center
	routeSummary.Visible = false
	self.Refs.ResultsRoute = routeSummary

	local saveLook = createButton(
		panel,
		"SaveLook",
		if self.Locale == "ru"
			then "Сохранить образ и клип"
			else "Save look and remix",
		"Secondary"
	)
	saveLook.Size = UDim2.new(1, 0, 0, 52)
	table.insert(
		self.Connections,
		saveLook.Activated:Connect(function()
			if self.State.RoundBundleSaved == true or self.State.ReadOnly == true then
				return
			end
			self:SetRoundBundleSaved(true)
			self:_emit("SaveLook")
			self:_emit("SaveRemix")
		end)
	)
	self.Refs.ResultsSaveLook = saveLook

	local actions = createFrame(panel, "Actions")
	actions.Size = UDim2.new(1, 0, 0, 58)
	addList(actions, Theme.Spacing.M, true)
	self.Refs.ResultsActions = actions

	local capture = createButton(
		actions,
		"Capture",
		if self.Locale == "ru"
			then "Сохранить кадр"
			else localText(self.Locale, "button.capture"),
		"Secondary"
	)
	capture.Size = UDim2.new(0.27, -6, 1, 0)
	capture.LayoutOrder = 2
	StyleOS.tag(capture, StyleOS.Tags.ResultAction)
	table.insert(
		self.Connections,
		capture.Activated:Connect(function()
			self:_emit("CaptureRequested")
		end)
	)
	self.Refs.ResultsCapture = capture

	local invite = createButton(
		actions,
		"Invite",
		if self.Locale == "ru" then "Позвать" else "Invite",
		"Secondary"
	)
	invite.Size = UDim2.new(0.27, -6, 1, 0)
	invite.LayoutOrder = 3
	StyleOS.tag(invite, StyleOS.Tags.ResultAction)
	table.insert(
		self.Connections,
		invite.Activated:Connect(function()
			self:_emit("InviteRequested", "results")
		end)
	)
	self.Refs.ResultsInvite = invite

	local waitNext =
		createButton(actions, "Next", localText(self.Locale, "button.play_again"), "Primary")
	waitNext.Size = UDim2.new(0.46, -6, 1, 0)
	waitNext.LayoutOrder = 1
	StyleOS.tag(waitNext, StyleOS.Tags.ResultAction)
	table.insert(
		self.Connections,
		waitNext.Activated:Connect(function()
			if self.State.RequeueRequested == true then
				return
			end
			self:SetRequeueRequested(true)
			self:_emit("Requeue")
		end)
	)
	self.Refs.ResultsNext = waitNext
end

function App._buildToast(self: App)
	local readOnlyBanner = createLabel(
		self.TopBar,
		"ReadOnlyBanner",
		"Без сохранения",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	readOnlyBanner.AnchorPoint = Vector2.new(0, 0.5)
	readOnlyBanner.Position = UDim2.new(0, 204, 0.5, 0)
	readOnlyBanner.Size = UDim2.new(1, -408, 0, 32)
	readOnlyBanner:SetAttribute(
		"Tooltip",
		"В этом запуске прогресс не сохранится"
	)
	readOnlyBanner.BackgroundColor3 = Theme.Colors.Surface
	readOnlyBanner.BackgroundTransparency = 0.02
	readOnlyBanner.TextColor3 = Theme.Colors.Warning
	readOnlyBanner.TextXAlignment = Enum.TextXAlignment.Center
	readOnlyBanner.Visible = false
	readOnlyBanner.ZIndex = 75
	Theme.addCorner(readOnlyBanner, Theme.Radius.Pill)
	Theme.addStroke(readOnlyBanner, Theme.Colors.Warning, 0.4)
	local bannerConstraint = Instance.new("UISizeConstraint")
	bannerConstraint.MaxSize = Vector2.new(680, 34)
	bannerConstraint.Parent = readOnlyBanner
	self.Refs.ReadOnlyBanner = readOnlyBanner

	local routeRibbon = createLabel(
		self.OverlayContainer,
		"RouteRibbon",
		"",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	routeRibbon.AnchorPoint = Vector2.new(0.5, 0)
	routeRibbon.Position = UDim2.new(0.5, 0, 0, 76)
	routeRibbon.Size = UDim2.new(0.72, 0, 0, 34)
	routeRibbon.BackgroundColor3 = Theme.Colors.SurfaceRaised
	routeRibbon.BackgroundTransparency = 0.08
	routeRibbon.TextColor3 = Theme.Colors.Cyan
	routeRibbon.TextXAlignment = Enum.TextXAlignment.Center
	routeRibbon.Visible = false
	routeRibbon.ZIndex = 74
	Theme.addCorner(routeRibbon, Theme.Radius.Pill)
	Theme.addStroke(routeRibbon, Theme.Colors.Cyan, 0.3)
	local routeConstraint = Instance.new("UISizeConstraint")
	routeConstraint.MaxSize = Vector2.new(760, 34)
	routeConstraint.MinSize = Vector2.new(220, 34)
	routeConstraint.Parent = routeRibbon
	self.Refs.RouteRibbon = routeRibbon

	local toast = createFrame(self.OverlayContainer, "Toast")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, -90)
	toast.Size = UDim2.fromOffset(440, 62)
	toast.BackgroundColor3 = Theme.Colors.SurfaceRaised
	toast.BackgroundTransparency = 0.02
	toast.ZIndex = 80
	toast.Visible = false
	Theme.addCorner(toast, Theme.Radius.Large)
	local stroke = Theme.addStroke(toast, Theme.Colors.Cyan, 0.18)
	stroke.Name = "ToneStroke"

	local text = createLabel(toast, "Text", "", Theme.TextSizes.Body, Theme.Fonts.Bold)
	text.Position = UDim2.fromOffset(18, 0)
	text.Size = UDim2.new(1, -36, 1, 0)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.ZIndex = 81
	self.Refs.Toast = toast
	self.Refs.ToastText = text

	local caption = createLabel(
		self.OverlayContainer,
		"AudioCaption",
		"",
		Theme.TextSizes.Body,
		Theme.Fonts.Bold
	)
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -24)
	caption.Size = UDim2.new(0.88, 0, 0, 48)
	caption.BackgroundColor3 = Theme.Colors.Background
	caption.BackgroundTransparency = 0.12
	caption.TextColor3 = Theme.Colors.Text
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.Visible = false
	caption.ZIndex = 82
	Theme.addCorner(caption, Theme.Radius.Pill)
	Theme.addStroke(caption, Theme.Colors.Cyan, 0.28)
	local captionConstraint = Instance.new("UISizeConstraint")
	captionConstraint.MaxSize = Vector2.new(720, 56)
	captionConstraint.MinSize = Vector2.new(220, 48)
	captionConstraint.Parent = caption
	self.Refs.AudioCaption = caption
end

function App._buildSettings(self: App)
	local russian = self.Locale == "ru"
	local blocker = Instance.new("TextButton")
	blocker.Name = "SettingsOverlay"
	blocker.Text = ""
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundColor3 = Theme.Colors.Black
	blocker.BackgroundTransparency = 0.32
	blocker.BorderSizePixel = 0
	blocker.AutoButtonColor = false
	blocker.Visible = false
	blocker.ZIndex = 60
	blocker.Parent = self.OverlayContainer
	self.Refs.SettingsOverlay = blocker
	self:TrackPrimaryOverlay(blocker)

	local panel = createFrame(blocker, "Panel")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -18, 0, 18)
	panel.Size = UDim2.fromOffset(440, 540)
	panel.BackgroundColor3 = Theme.Colors.Surface
	panel.BackgroundTransparency = 0
	panel.ZIndex = 61
	Theme.addCorner(panel, Theme.Radius.Large)
	Theme.addStroke(panel, Theme.Colors.Cyan, 0.42)
	Theme.addPadding(panel, Theme.Spacing.L)

	local title = createLabel(
		panel,
		"Title",
		if russian
			then "Настройки и доступность"
			else "Settings & accessibility",
		Theme.TextSizes.Title,
		Theme.Fonts.Display
	)
	title.Size = UDim2.new(1, -56, 0, 46)
	title.ZIndex = 62

	local close = createButton(panel, "Close", "X", "Quiet")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(48, 48)
	close.ZIndex = 63
	table.insert(
		self.Connections,
		close.Activated:Connect(function()
			self:SetSettingsVisible(false)
		end)
	)

	local rows = Instance.new("ScrollingFrame")
	rows.Name = "Rows"
	rows.Position = UDim2.fromOffset(0, 62)
	rows.Size = UDim2.new(1, 0, 1, -70)
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.CanvasSize = UDim2.new()
	rows.ScrollingDirection = Enum.ScrollingDirection.Y
	rows.ScrollBarThickness = 4
	rows.ScrollBarImageColor3 = Theme.Colors.Cyan
	rows.ZIndex = 62
	rows.Parent = panel
	addList(rows, Theme.Spacing.M)

	local definitions = {
		{
			key = "reducedMotion",
			label = if russian then "Меньше движения" else "Reduced motion",
			description = if russian
				then "Статичная камера и короткие переходы"
				else "Static camera and shorter transitions",
		},
		{
			key = "lowVfx",
			label = if russian then "Меньше эффектов" else "Low VFX",
			description = if russian
				then "Уменьшает частицы и свечение"
				else "Reduces particles and bloom",
		},
		{
			key = "noFlashes",
			label = if russian then "Без вспышек" else "No flashes",
			description = if russian
				then "Убирает резкие изменения света"
				else "Removes abrupt lighting changes",
		},
		{
			key = "largeText",
			label = if russian then "Крупный интерфейс" else "Large interface",
			description = if russian
				then "Увеличивает текст и элементы"
				else "Increases text and controls",
		},
		{
			key = "captions",
			label = if russian then "Подписи ритма" else "Rhythm captions",
			description = if russian
				then "Дублирует звук символами"
				else "Duplicates sound with symbols",
		},
		{
			key = "haptics",
			label = if russian then "Вибрация" else "Haptics",
			description = if russian
				then "Тактильный отклик на поддерживаемых устройствах"
				else "Tactile feedback on supported devices",
		},
		{
			key = "highContrast",
			label = if russian then "Высокий контраст" else "High contrast",
			description = if russian
				then "Усиливает контуры и читаемость"
				else "Stronger outlines and readability",
		},
	}

	for index, definition in definitions do
		local row = createFrame(rows, `Setting{index}`)
		row.Size = UDim2.new(1, 0, 0, 68)
		row.BackgroundColor3 = Theme.Colors.SurfaceRaised
		row.BackgroundTransparency = 0.16
		row.ZIndex = 62
		Theme.addCorner(row, Theme.Radius.Medium)

		local label =
			createLabel(row, "Label", definition.label, Theme.TextSizes.Body, Theme.Fonts.Bold)
		label.Position = UDim2.fromOffset(14, 7)
		label.Size = UDim2.new(1, -110, 0, 26)
		label.ZIndex = 63

		local description =
			createLabel(row, "Description", definition.description, Theme.TextSizes.Caption)
		description.Position = UDim2.fromOffset(14, 31)
		description.Size = UDim2.new(1, -110, 0, 28)
		description.TextColor3 = Theme.Colors.TextMuted
		description.ZIndex = 63

		local toggle = createButton(row, "Toggle", "Выкл", "Quiet")
		toggle.AnchorPoint = Vector2.new(1, 0.5)
		toggle.Position = UDim2.new(1, -10, 0.5, 0)
		toggle.Size = UDim2.fromOffset(82, 48)
		toggle.ZIndex = 64
		toggle:SetAttribute("SettingKey", definition.key)
		table.insert(
			self.Connections,
			toggle.Activated:Connect(function()
				local key = definition.key :: string
				local current = self.Settings[key :: any]
				if type(current) == "boolean" then
					self:SetSetting(key, not current)
				end
			end)
		)
		self.Refs[`Setting_{definition.key}`] = toggle
	end

	for _, definition in
		{
			{ key = "musicVolume", label = if russian then "Музыка" else "Music" },
			{ key = "sfxVolume", label = if russian then "Эффекты" else "Effects" },
			{
				key = "ambienceVolume",
				label = if russian then "Атмосфера" else "Ambience",
			},
		}
	do
		local row = createFrame(rows, `Setting_{definition.key}`)
		row.Size = UDim2.new(1, 0, 0, 68)
		row.BackgroundColor3 = Theme.Colors.SurfaceRaised
		row.BackgroundTransparency = 0.16
		row.ZIndex = 62
		Theme.addCorner(row, Theme.Radius.Medium)

		local label =
			createLabel(row, "Label", definition.label, Theme.TextSizes.Body, Theme.Fonts.Bold)
		label.Position = UDim2.fromOffset(14, 0)
		label.Size = UDim2.new(1, -220, 1, 0)
		label.ZIndex = 63

		local decrease = createButton(row, "Decrease", "−", "Quiet")
		decrease.AnchorPoint = Vector2.new(1, 0.5)
		decrease.Position = UDim2.new(1, -126, 0.5, 0)
		decrease.Size = UDim2.fromOffset(48, 48)
		decrease.ZIndex = 64

		local value = createLabel(row, "Value", "70%", Theme.TextSizes.Caption, Theme.Fonts.Bold)
		value.AnchorPoint = Vector2.new(1, 0.5)
		value.Position = UDim2.new(1, -62, 0.5, 0)
		value.Size = UDim2.fromOffset(58, 48)
		value.TextXAlignment = Enum.TextXAlignment.Center
		value.ZIndex = 63

		local increase = createButton(row, "Increase", "+", "Quiet")
		increase.AnchorPoint = Vector2.new(1, 0.5)
		increase.Position = UDim2.new(1, -8, 0.5, 0)
		increase.Size = UDim2.fromOffset(48, 48)
		increase.ZIndex = 64

		local settingKey = definition.key :: string
		table.insert(
			self.Connections,
			decrease.Activated:Connect(function()
				local current = self.Settings[settingKey :: any]
				if type(current) == "number" then
					self:SetSetting(settingKey, math.max(0, current - 0.1))
				end
			end)
		)
		table.insert(
			self.Connections,
			increase.Activated:Connect(function()
				local current = self.Settings[settingKey :: any]
				if type(current) == "number" then
					self:SetSetting(settingKey, math.min(1, current + 0.1))
				end
			end)
		)
		self.Refs[`Setting_{settingKey}_Value`] = value
	end

	table.insert(
		self.Connections,
		blocker.Activated:Connect(function()
			self:SetSettingsVisible(false)
		end)
	)
	self:_refreshSettingButtons()
end

local function readGuiPreference(propertyName: string): any
	local service: any = GuiService
	local ok, value = pcall(function()
		return service[propertyName]
	end)
	return if ok then value else nil
end

function App._isReducedMotionEnabled(self: App): boolean
	return self.Settings.reducedMotion or self.State.PlatformReducedMotion == true
end

function App._isLargeTextEnabled(self: App): boolean
	return self.Settings.largeText or self.State.PlatformLargeText == true
end

function App._applyPreferredTransparency(self: App)
	local preference = math.clamp(tonumber(self.State.PlatformTransparency) or 0, 0, 1)
	for _, instance in self.ScreenGui:GetDescendants() do
		if
			instance:IsA("Frame")
			or instance:IsA("ScrollingFrame")
			or instance:IsA("TextButton")
			or instance:IsA("TextLabel")
		then
			local base = instance:GetAttribute("AuraRushBaseBackgroundTransparency")
			local lastApplied = instance:GetAttribute("AuraRushAppliedBackgroundTransparency")
			if
				type(base) ~= "number"
				or (
					type(lastApplied) == "number"
					and math.abs(instance.BackgroundTransparency - lastApplied) > 0.001
				)
			then
				base = instance.BackgroundTransparency
				instance:SetAttribute("AuraRushBaseBackgroundTransparency", base)
			end
			-- Keep cards readable while respecting the platform preference.
			local applied = math.clamp(base + (1 - base) * preference * 0.3, 0, 1)
			instance.BackgroundTransparency = applied
			instance:SetAttribute("AuraRushAppliedBackgroundTransparency", applied)
		end
	end
end

function App._syncPlatformAccessibility(self: App)
	self.State.PlatformReducedMotion = readGuiPreference("ReducedMotionEnabled") == true
	local preferredText = readGuiPreference("PreferredTextSize")
	local preferredTextName = string.lower(tostring(preferredText or ""))
	self.State.PlatformLargeText = string.find(preferredTextName, "large", 1, true) ~= nil
	self.State.PlatformTransparency = tonumber(readGuiPreference("PreferredTransparency")) or 0

	local accessibilityScale = self.Refs.AccessibilityScale :: UIScale
	accessibilityScale.Scale = if self:_isLargeTextEnabled() then 1.08 else 1
	self:_applyPreferredTransparency()
	self:_refreshSettingButtons()
	self:_emit("LocalSettingsChanged", self:GetSettings())
end

function App._bindPlatformAccessibility(self: App)
	self:_syncPlatformAccessibility()
	local service: any = GuiService
	for _, propertyName in { "ReducedMotionEnabled", "PreferredTextSize", "PreferredTransparency" } do
		local ok, signal = pcall(function()
			return service:GetPropertyChangedSignal(propertyName)
		end)
		if ok and signal then
			table.insert(
				self.Connections,
				signal:Connect(function()
					self:_syncPlatformAccessibility()
				end)
			)
		end
	end
	task.defer(function()
		if self.ScreenGui.Parent then
			self:_syncPlatformAccessibility()
		end
	end)
end

function App._bindViewport(self: App)
	local function bindCamera(): ()
		if self.ViewportConnection then
			self.ViewportConnection:Disconnect()
			self.ViewportConnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			self.ViewportConnection = camera
				:GetPropertyChangedSignal("ViewportSize")
				:Connect(function()
					self:_updateResponsive(camera.ViewportSize)
				end)
			self:_updateResponsive(camera.ViewportSize)
		else
			self:_updateResponsive(Vector2.new(1280, 720))
		end
	end
	bindCamera()
	table.insert(
		self.Connections,
		workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	)
end

function App._updateResponsive(self: App, viewport: Vector2)
	local compact = viewport.X < 760 or viewport.Y < 560
	local phone = viewport.X < 520
	local headerCompact = compact or viewport.X < 1180
	local logo = self.Refs.Logo :: TextLabel
	local phase = self.Refs.PhaseLabel :: TextLabel
	local timer = self.Refs.TimerLabel :: TextLabel
	local metaHud = self.Refs.MetaHud :: TextLabel
	logo.Visible = not headerCompact
	metaHud.Visible = not headerCompact
	phase.Visible = not phone
	phase.AnchorPoint = Vector2.new(0, 0.5)
	phase.Position = UDim2.new(0, if headerCompact then 12 else 176, 0.5, 0)
	phase.Size = UDim2.fromOffset(if phone then 132 else if headerCompact then 180 else 250, 36)
	phase.TextSize = if phone then 11 else Theme.TextSizes.Caption
	timer.Position = UDim2.new(1, -58, 0.5, 0)
	timer.Size = UDim2.fromOffset(if compact then 70 else 82, 38)
	local readOnlyBanner = self.Refs.ReadOnlyBanner :: TextLabel
	local bannerLeft = if phone then 12 else if headerCompact then 204 else 442
	local bannerRight = if headerCompact then 204 else 508
	readOnlyBanner.Position = UDim2.new(0, bannerLeft, 0.5, 0)
	readOnlyBanner.Size = UDim2.new(1, -bannerLeft - bannerRight, 0, 32)
	readOnlyBanner.TextSize = if headerCompact then 11 else 12

	local loadingCard = self.Screens.Loading:FindFirstChild("LoadingCard") :: Frame?
	if loadingCard then
		loadingCard.Size = if compact then UDim2.new(0.9, 0, 0, 220) else UDim2.fromOffset(500, 230)
	end

	local portalCard = self.Screens.Hub:FindFirstChild("PortalCard") :: Frame?
	if portalCard then
		portalCard.AnchorPoint = if compact then Vector2.new(0.5, 1) else Vector2.new(0, 1)
		portalCard.Position = if compact
			then UDim2.new(0.5, 0, 1, -12)
			else UDim2.new(0, 22, 1, -22)
		portalCard.Size = if compact
			then UDim2.new(0.94, 0, 0, math.max(204, math.min(224, viewport.Y - 96)))
			else UDim2.fromOffset(390, 228)
	end
	local hubIcon = self.Refs.HubIcon :: TextLabel
	local hubTip = self.Refs.HubTip :: TextLabel
	hubIcon.Visible = not compact
	hubTip.Visible = not compact

	local onboardingHero = self.Refs.OnboardingHero :: Frame
	local onboardingContent = self.Refs.OnboardingContent :: ScrollingFrame
	onboardingHero.AnchorPoint = if compact then Vector2.new(0.5, 1) else Vector2.new(0, 1)
	onboardingHero.Position = if compact
		then UDim2.new(0.5, 0, 1, -12)
		else UDim2.new(0, 24, 1, -24)
	onboardingHero.Size = if compact
		then UDim2.new(0.94, 0, 0, math.min(246, viewport.Y - 96))
		else UDim2.fromOffset(520, 300)
	onboardingContent.Size = if compact
		then UDim2.fromScale(0.9, 0.88)
		else UDim2.fromScale(0.9, 0.86)
	local onboardingTitle = self.Refs.OnboardingTitle :: TextLabel
	local onboardingLoop = self.Refs.OnboardingLoop :: TextLabel
	onboardingTitle.TextSize = if compact then Theme.TextSizes.Subtitle else Theme.TextSizes.Title
	onboardingLoop.Visible = not compact or viewport.Y >= 720

	local briefScreen = self.Screens.BriefChoice
	local briefTitle = briefScreen:FindFirstChild("Title") :: TextLabel?
	local briefSubtitle = briefScreen:FindFirstChild("Subtitle") :: TextLabel?
	local briefScroll = self.Refs.BriefScroll :: ScrollingFrame
	local briefList = self.Refs.BriefList :: UIListLayout
	if briefTitle then
		briefTitle.Visible = true
		briefTitle.TextSize = if compact then Theme.TextSizes.Subtitle else Theme.TextSizes.Title
	end
	if briefSubtitle then
		briefSubtitle.Visible = not compact
	end
	briefScroll.AnchorPoint = Vector2.new(0.5, 1)
	briefScroll.Position = UDim2.new(0.5, 0, 1, if compact then -8 else -16)
	briefScroll.Size = if compact then UDim2.new(0.98, 0, 0, 214) else UDim2.new(0.94, 0, 0, 230)
	briefScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	briefScroll.ScrollingDirection = Enum.ScrollingDirection.X
	briefList.HorizontalAlignment = if viewport.X >= 940
		then Enum.HorizontalAlignment.Center
		else Enum.HorizontalAlignment.Left
	for index = 1, 3 do
		local card = self.Refs[`BriefCard{index}`] :: Frame
		card.Size = UDim2.fromOffset(if compact then 250 else 284, if compact then 196 else 208)
	end

	local challengeSizes = {
		ThreadRun = Vector2.new(360, 234),
		BeatLab = Vector2.new(680, 390),
		PrismPuzzle = Vector2.new(680, 410),
	}
	for name, baseSize in challengeSizes do
		local challengeCard = self.Screens[name]:FindFirstChild("ChallengeCard") :: Frame?
		if challengeCard then
			challengeCard.Size = UDim2.fromOffset(baseSize.X, baseSize.Y)
			if name == "ThreadRun" then
				challengeCard.AnchorPoint = if phone then Vector2.new(0.5, 0) else Vector2.new(0, 1)
				challengeCard.Position = if phone
					then UDim2.new(0.5, 0, 0, 48)
					else UDim2.new(0, 18, 1, -18)
			else
				challengeCard.Position = if compact
					then UDim2.fromScale(0.5, 0.5)
					else UDim2.fromScale(0.5, 0.44)
			end
			local responsiveScale = challengeCard:FindFirstChild("ResponsiveScale") :: UIScale?
			if responsiveScale then
				responsiveScale.Scale = if compact
					then math.clamp(
						math.min((viewport.X - 24) / baseSize.X, (viewport.Y - 98) / baseSize.Y),
						0.5,
						1
					)
					else 1
			end
		end
	end

	local preview = self.Refs.MixPreview :: Frame
	local previewViewport = self.Refs.MixViewport :: ViewportFrame
	local previewLabel = self.Refs.MixPreviewLabel :: TextLabel
	local selectedStyleLabel = self.Refs.StyleSelectedLabel :: TextLabel
	local mixPanel = self.Refs.MixPanel :: Frame
	local styleGrid = self.Refs.StyleGrid :: UIGridLayout
	local mixActions = mixPanel:FindFirstChild("Actions") :: Frame?
	local undo = if mixActions then mixActions:FindFirstChild("Undo") :: TextButton? else nil
	local redo = if mixActions then mixActions:FindFirstChild("Redo") :: TextButton? else nil
	local randomize = if mixActions
		then mixActions:FindFirstChild("Randomize") :: TextButton?
		else nil
	local ready = self.Refs.StyleReadyButton :: TextButton
	for category in CATEGORY_LABELS do
		local tab = self.Refs[`StyleTab_{category}`] :: TextButton
		tab.TextSize = if compact then 10 else 11
		tab.TextWrapped = compact
	end
	for index = 1, 20 do
		VisualItemTile.setCompact(self.Refs[`StyleItem{index}`] :: TextButton, compact)
	end
	if compact then
		preview.Visible = true
		previewViewport.Position = UDim2.fromScale(0.5, 0.5)
		previewViewport.Size = UDim2.new(1, -8, 1, -8)
		previewLabel.Visible = false
		selectedStyleLabel.Visible = false
		if viewport.Y > viewport.X then
			preview.Position = UDim2.fromOffset(8, 4)
			preview.Size = UDim2.new(1, -16, 0.34, -8)
			mixPanel.Position = UDim2.new(0, 8, 0.34, 2)
			mixPanel.Size = UDim2.new(1, -16, 0.66, -6)
			styleGrid.CellSize = UDim2.new(0.5, -6, 0, StyleOS.Tokens.Tile.CompactHeight)
		else
			preview.Position = UDim2.fromOffset(8, 4)
			preview.Size = UDim2.new(0.32, -10, 1, -8)
			mixPanel.Position = UDim2.new(0.32, 4, 0, 4)
			mixPanel.Size = UDim2.new(0.68, -12, 1, -8)
			styleGrid.CellSize = UDim2.new(0.33, -8, 0, StyleOS.Tokens.Tile.CompactHeight)
		end
		if undo and redo and randomize then
			undo.Size = UDim2.fromOffset(48, 52)
			redo.Size = UDim2.fromOffset(54, 52)
			randomize.Size = UDim2.fromOffset(86, 52)
			ready.Size = UDim2.new(1, -212, 0, 52)
			undo.TextSize = 11
			redo.TextSize = 11
			randomize.TextSize = 11
			ready.TextSize = 12
			ready.TextWrapped = true
		end
	else
		preview.Visible = true
		previewViewport.Position = UDim2.fromScale(0.5, 0.49)
		previewViewport.Size = UDim2.new(1, -24, 1, -116)
		previewLabel.Visible = true
		selectedStyleLabel.Visible = true
		preview.Position = UDim2.fromOffset(24, 18)
		preview.Size = UDim2.new(0.39, -30, 1, -42)
		mixPanel.Position = UDim2.new(0.39, 12, 0, 18)
		mixPanel.Size = UDim2.new(0.61, -36, 1, -42)
		styleGrid.CellSize = UDim2.new(0.25, -8, 0, StyleOS.Tokens.Tile.Height)
		if undo and redo and randomize then
			undo.Size = UDim2.fromOffset(78, 52)
			redo.Size = UDim2.fromOffset(86, 52)
			randomize.Size = UDim2.fromOffset(132, 52)
			ready.Size = UDim2.new(1, -322, 0, 52)
			undo.TextSize = Theme.TextSizes.Button
			redo.TextSize = Theme.TextSizes.Button
			randomize.TextSize = Theme.TextSizes.Button
			ready.TextSize = Theme.TextSizes.Button
			ready.TextWrapped = false
		end
	end

	local resultsCard = self.Refs.ResultsCard :: ScrollingFrame
	resultsCard.Position = UDim2.fromScale(0.5, 0.5)
	resultsCard.Size = if compact then UDim2.new(0.96, 0, 1, -18) else UDim2.fromOffset(720, 560)
	local resultsTitle = self.Refs.ResultsTitle :: TextLabel
	resultsTitle.TextSize = if phone then Theme.TextSizes.Subtitle else Theme.TextSizes.Title
	local resultsMedals = self.Refs.ResultsMedals :: Frame
	for _, child in resultsMedals:GetChildren() do
		if child:IsA("TextLabel") then
			child.TextSize = if phone then 11 else Theme.TextSizes.Body
		end
	end
	local resultsSummary = self.Refs.ResultsSummary :: Frame
	local summaryLayout = resultsSummary:FindFirstChildOfClass("UIListLayout")
	local resultsReward = self.Refs.ResultsReward :: TextLabel
	local resultsMeta = self.Refs.ResultsMeta :: TextLabel
	if summaryLayout then
		summaryLayout.FillDirection = if phone
			then Enum.FillDirection.Vertical
			else Enum.FillDirection.Horizontal
	end
	resultsSummary.Size = UDim2.new(1, 0, 0, if phone then 132 else 66)
	resultsReward.Size = if phone then UDim2.new(1, 0, 0, 62) else UDim2.new(0.5, -4, 1, 0)
	resultsMeta.Size = if phone then UDim2.new(1, 0, 0, 62) else UDim2.new(0.5, -4, 1, 0)
	local resultsActions = self.Refs.ResultsActions :: Frame
	local resultsActionsLayout = resultsActions:FindFirstChildOfClass("UIListLayout")
	local resultsCapture = self.Refs.ResultsCapture :: TextButton
	local resultsInvite = self.Refs.ResultsInvite :: TextButton
	local resultsNext = self.Refs.ResultsNext :: TextButton
	if resultsActionsLayout then
		resultsActionsLayout.FillDirection = if phone
			then Enum.FillDirection.Vertical
			else Enum.FillDirection.Horizontal
	end
	resultsActions.Size = UDim2.new(1, 0, 0, if phone then 180 else 58)
	if phone then
		for _, button in { resultsCapture, resultsInvite, resultsNext } do
			button.Size = UDim2.new(1, 0, 0, 52)
			button.TextSize = 12
		end
	else
		resultsCapture.Size = UDim2.new(0.27, -6, 1, 0)
		resultsInvite.Size = UDim2.new(0.27, -6, 1, 0)
		resultsNext.Size = UDim2.new(0.46, -6, 1, 0)
		for _, button in { resultsCapture, resultsInvite, resultsNext } do
			button.TextSize = Theme.TextSizes.Button
		end
	end

	local settingsOverlay = self.Refs.SettingsOverlay :: TextButton
	local settingsPanel = settingsOverlay:FindFirstChild("Panel") :: Frame?
	if settingsPanel then
		settingsPanel.Size = if compact
			then UDim2.new(1, -24, 1, -24)
			else UDim2.fromOffset(440, 540)
		settingsPanel.Position = if compact
			then UDim2.new(1, -12, 0, 12)
			else UDim2.new(1, -18, 0, 18)
	end
end

function App.On(self: App, eventName: string, callback: (...any) -> ()): RBXScriptConnection
	local event = self.Events[eventName]
	assert(event ~= nil, `Unknown UI event: {eventName}`)
	local connection = event.Event:Connect(callback)
	table.insert(self.Connections, connection)
	return connection
end

function App._emit(self: App, eventName: string, ...: any)
	local event = self.Events[eventName]
	if event then
		event:Fire(...)
	end
end

function App._refreshPresentation(self: App)
	local modalOpen = false
	for _, child in self.OverlayContainer:GetChildren() do
		if
			child:IsA("GuiObject")
			and child:GetAttribute("PrimaryOverlay") == true
			and child.Visible
		then
			modalOpen = true
			break
		end
	end
	local screenName = tostring(self.State.ScreenName or "Loading")
	local policy = PresentationPolicy.Resolve(screenName, modalOpen, self.State.Capturing == true)
	self.TopBar.Visible = policy.topBarVisible
	self.ScreenContainer.Visible = policy.screenVisible
	self.ScreenGui:SetAttribute("SuppressSecondaryHud", policy.suppressSecondaryHud)
	local banner = self.Refs.ReadOnlyBanner
	if banner and banner:IsA("TextLabel") then
		banner.Visible = self.State.ReadOnly == true and policy.readOnlyVisible
	end
	local routeRibbon = self.Refs.RouteRibbon
	if routeRibbon and routeRibbon:IsA("TextLabel") then
		routeRibbon.Visible = policy.routeRibbonVisible and routeRibbon.Text ~= ""
	end
end

function App.TrackPrimaryOverlay(self: App, overlay: GuiObject)
	overlay:SetAttribute("PrimaryOverlay", true)
	table.insert(
		self.Connections,
		overlay:GetPropertyChangedSignal("Visible"):Connect(function()
			self:_refreshPresentation()
		end)
	)
	self:_refreshPresentation()
end

function App.ShowScreen(self: App, screenName: string)
	self.State.ScreenName = screenName
	for name, screen in self.Screens do
		screen.Visible = name == screenName
	end
	self:_refreshPresentation()

	if UserInputService.GamepadEnabled then
		local preferred: GuiObject? = nil
		if screenName == "Onboarding" then
			preferred = self.Refs.OnboardingStart :: GuiObject
		elseif screenName == "Hub" then
			preferred = self.Refs.HubInvite :: GuiObject
		elseif screenName == "BriefChoice" then
			preferred = self.Refs.BriefButton1 :: GuiObject
		elseif screenName == "BeatLab" then
			preferred = self.Refs.BeatLane1 :: GuiObject
		elseif screenName == "PrismPuzzle" then
			preferred = self.Refs.PrismButton1 :: GuiObject
		elseif screenName == "MixLab" then
			preferred = self.Refs.StyleTab_palette :: GuiObject
		elseif screenName == "Results" then
			preferred = self.Refs.ResultsNext :: GuiObject
		end
		GuiService.SelectedObject = preferred
	end
end

function App.ShowPhase(self: App, phase: string)
	local previousPhase = self.State.Phase
	self.State.PendingPhase = phase
	if self.State.OnboardingDismissed ~= true then
		self:ShowScreen("Onboarding")
		return
	end

	local activeRoundPhase = phase ~= "Waiting" and phase ~= "Intermission" and phase ~= "Cleanup"
	local spectating = self.State.IsParticipant == false and activeRoundPhase
	local screenName = if spectating then "Hub" else (SCREEN_FOR_PHASE[phase] or "Hub")
	self.State.Phase = phase
	if phase == "Results" and previousPhase ~= "Results" then
		self:SetRoundBundleSaved(false)
	end
	if phase == "MixLab" and previousPhase ~= "MixLab" then
		self:SetStyleReady(false)
	end
	local phaseLabel = self.Refs.PhaseLabel :: TextLabel
	local localizedPhase = if Localization.Has(self.Locale, `round.state.{phase}`)
		then localText(self.Locale, `round.state.{phase}`)
		else PHASE_LABELS[phase] or (if self.Locale == "ru" then "Раунд" else "Round")
	phaseLabel.Text = if spectating
		then `Следующий раунд / {localizedPhase}`
		else localizedPhase
	local phaseDot = self.Refs.PhaseDot :: Frame
	phaseDot.BackgroundColor3 = if phase == "Waiting" or phase == "Intermission"
		then Theme.Colors.TextDim
		else if phase == "Finale" or phase == "Results"
			then Theme.Colors.Lime
			else Theme.Colors.Cyan
	local hubTitle = self.Refs.HubTitle :: TextLabel
	if spectating then
		hubTitle.Text = "Вы в следующем раунде"
	else
		hubTitle.Text = "Собираем команду"
	end
	self:ShowScreen(screenName)
	self:_emit("PhaseChanged", phase)
end

function App.GetPhase(self: App): string
	return self.State.Phase
end

function App.GetRoundId(self: App): string
	return self.State.RoundId
end

function App.CompleteOnboarding(self: App)
	self.State.OnboardingDismissed = true
	Players.LocalPlayer:SetAttribute("AuraRushOnboarded", true)
	self:ShowPhase(self.State.PendingPhase)
end

function App.CreatePostcard(self: App)
	self:_emit("PostcardAction", "create")
end

function App.SetLoadingStatus(self: App, text: string)
	local label = self.Refs.LoadingLabel :: TextLabel
	local clean = string.gsub(text, "Vibe Contract", "тему раунда")
	clean = string.gsub(clean, "портал", "район")
	clean = string.gsub(clean, "Портал", "Район")
	clean = string.gsub(clean, "…", "...")
	label.Text = clean
end

function App.SetTimer(self: App, seconds: number)
	local timer = self.Refs.TimerLabel :: TextLabel
	timer.Text = formatTime(seconds)
	timer.TextColor3 = if seconds <= 5 then Theme.Colors.Error else Theme.Colors.Text
end

function App.ApplySnapshot(self: App, snapshot: AnyMap)
	local phase = if type(snapshot.state) == "string" then snapshot.state else "Waiting"
	self.State.RoundId = if type(snapshot.roundId) == "string" then snapshot.roundId else ""
	self.State.StateVersion = if type(snapshot.stateVersion) == "number"
		then snapshot.stateVersion
		else -1
	self.State.IsParticipant = snapshot.isParticipant ~= false
	if type(snapshot.profile) == "table" then
		self:SetReadOnly(snapshot.profile.readOnly == true)
		if hasEnteredFirstSession(snapshot.profile) then
			self.State.OnboardingDismissed = true
			Players.LocalPlayer:SetAttribute("AuraRushOnboarded", true)
		end
		if type(snapshot.profile.settings) == "table" then
			for _, key in
				{
					"reducedMotion",
					"lowVfx",
					"noFlashes",
					"largeText",
					"captions",
					"highContrast",
					"haptics",
					"cameraShake",
					"musicVolume",
					"sfxVolume",
					"ambienceVolume",
				}
			do
				local value = snapshot.profile.settings[key]
				if type(value) == "boolean" or type(value) == "number" then
					self:SetSetting(key, value, false)
				end
			end
		end
		self:ApplyMetaUpdate({ profile = snapshot.profile })
	end

	local briefChoices = snapshot.briefChoices or snapshot.briefOptions
	if type(briefChoices) == "table" then
		self:SetBriefChoices(briefChoices)
	end
	local currentAct = if type(snapshot.currentAct) == "table" then snapshot.currentAct else nil
	local isRouteChoice = currentAct ~= nil
		and (currentAct.id == "route_choice" or currentAct.semantic == "branch_vote")
	if isRouteChoice and type(snapshot.routeChoices) == "table" then
		self:SetRouteChoices(snapshot.routeChoices)
	end
	local selectedBrief = snapshot.brief or snapshot.selectedBrief
	if type(selectedBrief) == "table" then
		self:SetSelectedBrief(selectedBrief)
	end
	if type(snapshot.progress) == "table" then
		self:ApplyProgress(snapshot.progress)
	end
	if type(snapshot.result) == "table" then
		self:ApplyResult(snapshot.result)
	end
	local meta = snapshot.meta or snapshot.metaProgress or snapshot.progression
	if type(meta) == "table" then
		self:ApplyMetaUpdate(meta)
	end
	local run = snapshot.run or snapshot.route or snapshot.runState or snapshot.runPlan
	if type(run) == "table" then
		local runView = table.clone(run)
		runView.currentAct = snapshot.currentAct or runView.currentAct
		runView.modifier = snapshot.modifier or runView.modifier
		self:ApplyRunUpdate(runView)
	end
	self:SetRequeueRequested(snapshot.requeueRequested == true)

	self:ShowPhase(phase)
	self:_emit("SnapshotApplied", snapshot)
end

function App.ApplyResult(self: App, result: AnyMap)
	local reward = tonumber(result.reward or result.glowDust or result.totalReward)
	local rewardLabel = self.Refs.ResultsReward :: TextLabel
	if reward then
		rewardLabel.Text = if self.Locale == "ru"
			then `+{math.max(0, math.floor(reward))} Искр за раунд`
			else `+{math.max(0, math.floor(reward))} Sparks`
	else
		rewardLabel.Text = if self.Locale == "ru"
			then "Награда уже у вас"
			else "Reward received"
	end
	if type(result.progress) == "table" then
		self:ApplyProgress(result.progress)
	end
end

function App.SetBriefChoices(self: App, options: { AnyMap })
	self.State.RouteChoiceActive = false
	self.State.RouteChoices = {}
	self.State.BriefOptions = options
	local header = self.Refs.BriefHeader :: TextLabel
	local subtitle = self.Refs.BriefSubtitle :: TextLabel
	header.Text = if self.Locale == "ru"
		then "Выбери тему раунда"
		else "Choose a theme"
	subtitle.Text = if self.Locale == "ru"
		then "Один голос на игрока. Решает команда."
		else "Three fair choices. The team's vote wins."
	for index = 1, 3 do
		local brief = options[index]
		local title, detail = getBriefLabel(self.Locale, brief)
		local titleLabel = self.Refs[`BriefTitle{index}`] :: TextLabel
		local detailLabel = self.Refs[`BriefDetail{index}`] :: TextLabel
		local button = self.Refs[`BriefButton{index}`] :: TextButton
		local card = self.Refs[`BriefCard{index}`] :: Frame
		card.Visible = type(brief) == "table"
		local lastChoice = math.clamp(#options, 1, 3)
		button.NextSelectionLeft =
			self.Refs[`BriefButton{math.clamp(index - 1, 1, lastChoice)}`] :: TextButton
		button.NextSelectionRight =
			self.Refs[`BriefButton{math.clamp(index + 1, 1, lastChoice)}`] :: TextButton
		card:SetAttribute("Selected", false)
		card.BackgroundColor3 = Theme.Colors.Surface
		local cardStroke = card:FindFirstChildOfClass("UIStroke")
		if cardStroke then
			cardStroke.Color = Theme.Colors.Stroke
			cardStroke.Transparency = 0.46
			cardStroke.Thickness = 1
		end
		titleLabel.Text = title
		detailLabel.Text = string.gsub(detail, " / ", "\n")
		button.Active = brief ~= nil
		button.Selectable = brief ~= nil
		button.AutoButtonColor = brief ~= nil
		button.Text = if brief
			then (if self.Locale == "ru"
				then "Выбрать тему"
				else localText(self.Locale, "button.choose"))
			else "-"
		button.BackgroundTransparency = if brief then 0 else 0.6
	end
end

function App.SetRouteChoices(self: App, options: { AnyMap })
	self.State.RouteChoiceActive = true
	self.State.RouteChoices = table.clone(options)
	local header = self.Refs.BriefHeader :: TextLabel
	local subtitle = self.Refs.BriefSubtitle :: TextLabel
	header.Text = if self.Locale == "ru" then "Выбери маршрут" else "Choose a route"
	subtitle.Text = if self.Locale == "ru"
		then "Маршрут меняет испытания и финальную Перекраску."
		else "Your route changes the challenges and finale."
	for index = 1, 3 do
		local route = options[index]
		local titleLabel = self.Refs[`BriefTitle{index}`] :: TextLabel
		local detailLabel = self.Refs[`BriefDetail{index}`] :: TextLabel
		local button = self.Refs[`BriefButton{index}`] :: TextButton
		local card = self.Refs[`BriefCard{index}`] :: Frame
		card.Visible = type(route) == "table"
		local lastChoice = math.clamp(#options, 1, 3)
		button.NextSelectionLeft =
			self.Refs[`BriefButton{math.clamp(index - 1, 1, lastChoice)}`] :: TextButton
		button.NextSelectionRight =
			self.Refs[`BriefButton{math.clamp(index + 1, 1, lastChoice)}`] :: TextButton
		card:SetAttribute("Selected", false)
		card.BackgroundColor3 = Theme.Colors.Surface
		local cardStroke = card:FindFirstChildOfClass("UIStroke")
		if cardStroke then
			cardStroke.Color = Theme.Colors.Stroke
			cardStroke.Transparency = 0.46
			cardStroke.Thickness = 1
		end
		if type(route) == "table" then
			local routeId = route.id or route.routeId
			local routeTitle = localizedName(
				self.Locale,
				route.title or route.name,
				route.titleKey or route.nameKey
			)
			if routeTitle == "" then
				routeTitle = localizedIdentifier(self.Locale, "route", routeId)
			end
			if routeTitle == "" then
				routeTitle = if self.Locale == "ru"
					then `Маршрут {index}`
					else `Route {index}`
			end
			local detailParts: { string } = {}
			local descriptionKey = route.descriptionKey
			if
				type(descriptionKey) == "string" and Localization.Has(self.Locale, descriptionKey)
			then
				table.insert(detailParts, localText(self.Locale, descriptionKey))
			elseif type(routeId) == "string" then
				table.insert(
					detailParts,
					localizedIdentifier(self.Locale, "route_description", routeId)
				)
			end
			titleLabel.Text = routeTitle
			detailLabel.Text = if #detailParts > 0
				then table.concat(detailParts, "\n")
				else (if self.Locale == "ru"
					then "Свой темп и финал"
					else "A distinct pace and finale")
			button.Active = true
			button.Selectable = true
			button.AutoButtonColor = true
			button.Text = if self.Locale == "ru"
				then "Выбрать маршрут"
				else localText(self.Locale, "button.choose")
			button.BackgroundTransparency = 0
		else
			titleLabel.Text = "-"
			detailLabel.Text = ""
			button.Active = false
			button.Selectable = false
			button.AutoButtonColor = false
			button.Text = "-"
			button.BackgroundTransparency = 0.6
		end
	end
end

function App.SetRequeueRequested(self: App, requested: boolean)
	self.State.RequeueRequested = requested
	local button = self.Refs.ResultsNext :: TextButton
	button.Active = not requested
	button.Selectable = not requested
	button.AutoButtonColor = not requested
	button.TextColor3 = if requested then Theme.Colors.Success else Theme.Colors.Text
	button.Text = if requested
		then if self.Locale == "ru" then "Вы в очереди" else "Queued"
		else localText(self.Locale, "button.play_again")
end

function App.SetRoundBundleSaved(self: App, saved: boolean)
	self.State.RoundBundleSaved = saved
	local button = self.Refs.ResultsSaveLook :: TextButton
	local available = not saved and self.State.ReadOnly ~= true
	button.Active = available
	button.Selectable = available
	button.AutoButtonColor = available
	button.TextColor3 = if self.State.ReadOnly == true
		then Theme.Colors.TextMuted
		elseif saved then Theme.Colors.Success
		else Theme.Colors.Text
	button.Text = if self.State.ReadOnly == true
		then if self.Locale == "ru"
			then "Сохранение сейчас недоступно"
			else "Saving unavailable"
		elseif saved then if self.Locale == "ru"
			then "Сохранение запущено"
			else "Saving started"
		else if self.Locale == "ru"
			then "Сохранить образ и клип"
			else "Save look and remix"
end

function App.SetSelectedBrief(self: App, brief: AnyMap)
	self.State.SelectedBrief = brief
	local title, detail = getBriefLabel(self.Locale, brief)
	local combined = if detail == "" then title else `{title} / {detail}`
	local hubBrief = self.Refs.HubBrief :: TextLabel
	local resultsBrief = self.Refs.ResultsBrief :: TextLabel
	hubBrief.Text = combined
	resultsBrief.Text = combined
end

function App.ApplyProgress(self: App, progress: AnyMap)
	local threadProgressFill = self.Refs.ThreadProgressFill :: Frame
	local threadStats = self.Refs.ThreadStats :: TextLabel
	local beatStatus = self.Refs.BeatStatus :: TextLabel
	local prismAttempts = self.Refs.PrismAttempts :: TextLabel
	local resultMedal1 = self.Refs.ResultMedal1 :: TextLabel
	local resultMedal2 = self.Refs.ResultMedal2 :: TextLabel
	local resultMedal3 = self.Refs.ResultMedal3 :: TextLabel
	local threads = tonumber(
		progress.threadCollectibles or progress.collectibles or progress.threads
	) or 0
	local threadRatio = math.clamp(threads / 8, 0, 1)
	threadProgressFill.Size = UDim2.fromScale(threadRatio, 1)
	threadStats.Text = `Нити: {threads} из 8`

	local combo = tonumber(progress.beatCombo or progress.combo) or 0
	local score = tonumber(progress.beatScore or progress.score or progress.beatHits) or 0
	beatStatus.Text = `Серия: {combo}     Счёт: {score}`

	local attempts = tonumber(progress.prismAttempts or progress.attempts) or 0
	local prismSteps = tonumber(progress.prismSteps)
	local solved = progress.prismSolved == true
		or progress.solved == true
		or progress.prismComplete == true
	prismAttempts.Text = if solved
		then "Код собран"
		else if prismSteps
			then `Шаги: {prismSteps} из 5`
			else `Попытка: {attempts} из 5`
	prismAttempts.TextColor3 = if solved then Theme.Colors.Success else Theme.Colors.Gold

	local readyButton = self.Refs.StyleReadyButton :: TextButton
	if type(progress.styleReady) == "boolean" then
		readyButton:SetAttribute("Ready", progress.styleReady)
		readyButton.Text = if progress.styleReady
			then "Готово, жду команду"
			else localText(self.Locale, "button.ready")
	end

	resultMedal1.TextColor3 = if threads > 0 then Theme.Colors.Success else Theme.Colors.TextMuted
	resultMedal2.TextColor3 = if score > 0 then Theme.Colors.Success else Theme.Colors.TextMuted
	resultMedal3.TextColor3 = if solved then Theme.Colors.Success else Theme.Colors.TextMuted
	resultMedal1.Text = if self.Locale == "ru"
		then `01  Погоня\n{math.floor(threads)} из 8 нитей`
		else `01  Run\n{math.floor(threads)} of 8 threads`
	resultMedal2.Text = if self.Locale == "ru"
		then `02  Бит\n{math.floor(score)} очков`
		else `02  Beat\n{math.floor(score)} points`
	resultMedal3.Text = if self.Locale == "ru"
		then `03  Код\n{if solved then "собран" else "в процессе"}`
		else `03  Code\n{if solved then "complete" else "in progress"}`
end

function App.ApplyProgressEvent(self: App, payload: AnyMap)
	local kind = payload.kind
	local data = if type(payload.data) == "table" then payload.data else payload
	if kind == "BeatSetup" then
		self:ConfigureBeat(
			tonumber(data.startTime) or 0,
			tonumber(data.interval) or 0.75,
			tonumber(data.count) or 12,
			if type(data.lanes) == "table" then data.lanes else nil
		)
		local mechanic = if type(data.mechanic) == "table" then data.mechanic else {}
		local mechanicIds = if type(mechanic.ids) == "table" then mechanic.ids else {}
		if table.find(mechanicIds, "duet_lock") then
			local beatStatus = self.Refs.BeatStatus :: TextLabel
			beatStatus.Text = "ДУЭТ • попадайте в один бит вместе"
		end
	elseif kind == "PrismSetup" and type(data.sequence) == "table" then
		self:SetPrismSequence(data.sequence)
		local prismAttempts = self.Refs.PrismAttempts :: TextLabel
		if data.inputTransform == "rotate" then
			prismAttempts.Text =
				"Сдвигай каждый следующий цвет на один шаг дальше"
		elseif data.inputTransform == "complement" then
			prismAttempts.Text = "Выбирай противоположный цвет"
		end
	elseif kind == "Thread" then
		local value = math.max(tonumber(data.value) or 0, 0)
		local target = math.max(tonumber(data.target) or 1, 1)
		local threadProgressFill = self.Refs.ThreadProgressFill :: Frame
		local threadStats = self.Refs.ThreadStats :: TextLabel
		threadProgressFill.Size = UDim2.fromScale(math.clamp(value / target, 0, 1), 1)
		threadStats.Text = if data.rejected == "signal_gate"
			then `Нужен сигнал {tonumber(data.expectedSignalLane) or 1} • смени сторону`
			elseif
				data.rejected == "sequence"
			then "Иди по номерам — следующий сигнал впереди"
			else `Собрано: {value} из {target}     Награда ваша`
	elseif kind == "Beat" then
		local value = math.max(tonumber(data.value) or 0, 0)
		local target = math.max(tonumber(data.target) or 1, 1)
		local qualityNames = {
			perfect = "Идеально",
			good = "Точно",
			miss = "Мимо",
		}
		local qualityId = if type(data.quality) == "string" then string.lower(data.quality) else ""
		local quality = qualityNames[qualityId] or ""
		local beatStatus = self.Refs.BeatStatus :: TextLabel
		beatStatus.Text = `Ритм: {value} из {target}`
			.. (if quality ~= "" then `     {quality}` else "")
	elseif kind == "Prism" then
		local value = math.max(tonumber(data.value) or 0, 0)
		local target = math.max(tonumber(data.target) or 1, 1)
		local complete = data.complete == true
		local prismAttempts = self.Refs.PrismAttempts :: TextLabel
		local attempts = math.max(tonumber(data.attempts) or 0, 0)
		local maxAttempts = math.max(tonumber(data.maxAttempts) or 5, 1)
		prismAttempts.Text = if complete
			then "Код собран"
			else `Шаги: {value} из {target}     Попытка: {attempts} из {maxAttempts}`
		prismAttempts.TextColor3 = if complete then Theme.Colors.Success else Theme.Colors.Gold
		if data.reset == true then
			self:ShowToast("PrismRetry", "Info")
		end
	elseif kind == "Profile" then
		local profile = payload.profile or data
		if type(profile) == "table" then
			self:SetReadOnly(profile.readOnly == true)
			if hasEnteredFirstSession(profile) then
				self.State.OnboardingDismissed = true
				Players.LocalPlayer:SetAttribute("AuraRushOnboarded", true)
			end
			if type(profile.settings) == "table" then
				for _, settingKey in
					{
						"reducedMotion",
						"lowVfx",
						"noFlashes",
						"largeText",
						"captions",
						"highContrast",
						"haptics",
						"cameraShake",
						"musicVolume",
						"sfxVolume",
						"ambienceVolume",
					}
				do
					local settingValue = profile.settings[settingKey]
					if type(settingValue) == "boolean" or type(settingValue) == "number" then
						self:SetSetting(settingKey, settingValue, false)
					end
				end
			end
			self:_emit("ProfileUpdated", profile)
		end
	elseif kind == "Result" then
		local result = payload.result or data
		if type(result) == "table" then
			self:ApplyResult(result)
		end
		if type(payload.profile) == "table" then
			self:_emit("ProfileUpdated", payload.profile)
		end
	elseif kind == "MetaUpdate" or kind == "Meta" or kind == "Progression" then
		self:ApplyMetaUpdate(data)
	elseif kind == "RunUpdate" or kind == "Run" or kind == "Route" then
		self:ApplyRunUpdate(data)
	elseif type(payload.progress) == "table" then
		self:ApplyProgress(payload.progress)
	else
		self:ApplyProgress(data)
	end
end

function App.ConfigureBeat(
	self: App,
	startTime: number,
	interval: number,
	count: number,
	lanes: { number }?
)
	self.State.BeatSetup = {
		startTime = startTime,
		interval = math.max(interval, 0.1),
		count = math.max(count, 1),
		lanes = if lanes then table.clone(lanes) else {},
	}
	self:_emit("BeatConfigured", startTime, interval, count, lanes or {})
end

function App.SetReadOnly(self: App, readOnly: boolean)
	self.State.ReadOnly = readOnly
	self:_refreshPresentation()
	self:SetRoundBundleSaved(self.State.RoundBundleSaved == true)
end

function App.SetBeatTarget(self: App, beatIndex: number, scheduledLane: number?)
	local activeLane = math.clamp(math.floor(scheduledLane or (((beatIndex - 1) % 4) + 1)), 1, 4)
	for lane = 1, 4 do
		local button = self.Refs[`BeatLane{lane}`] :: TextButton
		local target = activeLane == lane
		button.BackgroundColor3 = if target
			then PRISM_COLORS[lane]:Lerp(Theme.Colors.Text, 0.12)
			else PRISM_COLORS[lane]:Lerp(Theme.Colors.Background, 0.62)
		button.TextColor3 = if target then Theme.Colors.Background else Theme.Colors.Text
	end
end

function App.SetBeatCountIn(self: App, count: number)
	local beatStatus = self.Refs.BeatStatus :: TextLabel
	beatStatus.Text = `Старт через {math.max(1, math.floor(count))}`
end

function App.PulseBeatLane(self: App, lane: number)
	local button = self.Refs[`BeatLane{lane}`] :: TextButton?
	if not button then
		return
	end
	local original = button.Size
	if self:_isReducedMotionEnabled() then
		button.TextColor3 = Theme.Colors.Gold
		task.delay(0.1, function()
			if button.Parent then
				button.TextColor3 = Theme.Colors.Text
			end
		end)
	else
		button.Size = UDim2.new(original.X.Scale, original.X.Offset, original.Y.Scale, -4)
		TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = original })
			:Play()
	end
end

function App.SetPrismSequence(self: App, sequence: { number })
	self.State.PrismToken += 1
	local token = self.State.PrismToken
	for index = 1, 5 do
		local slot = self.Refs[`PrismSlot{index}`] :: TextLabel
		slot.Text = "."
		slot.TextColor3 = Theme.Colors.TextDim
	end

	task.spawn(function()
		for sequenceIndex, colorIndex in sequence do
			if token ~= self.State.PrismToken then
				return
			end
			local slot = if sequenceIndex <= 5
				then self.Refs[`PrismSlot{sequenceIndex}`] :: TextLabel?
				else nil
			local validIndex = math.clamp(math.floor(tonumber(colorIndex) or 1), 1, 4)
			if slot then
				slot.Text = PRISM_GLYPHS[validIndex]
				slot.TextColor3 = PRISM_COLORS[validIndex]
			end
			if not self:_isReducedMotionEnabled() then
				task.wait(0.36)
			end
		end
		task.wait(if self:_isReducedMotionEnabled() then 2.2 else 1.15)
		if token ~= self.State.PrismToken then
			return
		end
		for index = 1, 5 do
			local slot = self.Refs[`PrismSlot{index}`] :: TextLabel
			slot.Text = tostring(index)
			slot.TextColor3 = Theme.Colors.TextDim
		end
	end)
end

function App.SetStyleOptions(self: App, category: string, options: { StyleOption })
	self.State.StyleOptions[category] = options
	if category == self.State.ActiveStyleCategory then
		self:_renderStyleOptions()
	end
end

function App.SetActiveStyleCategory(self: App, category: string)
	if CATEGORY_LABELS[category] == nil then
		return
	end
	self.State.ActiveStyleCategory = category
	for categoryId in CATEGORY_LABELS do
		local tab = self.Refs[`StyleTab_{categoryId}`] :: TextButton
		Theme.setButtonSelected(tab, categoryId == category)
	end
	self:_renderStyleOptions()
end

function App._renderStyleOptions(self: App)
	local category = self.State.ActiveStyleCategory :: string
	local options = self.State.StyleOptions[category] :: { StyleOption }?
	local selectedId = self.State.StyleSelected[category]
	for index = 1, 20 do
		local button = self.Refs[`StyleItem{index}`] :: TextButton
		local option = if options then options[index] else nil
		VisualItemTile.render(
			button,
			option,
			option ~= nil and option.id == selectedId,
			category,
			self.Locale
		)
		if option then
			button.NextSelectionUp = self.Refs[`StyleTab_{category}`] :: TextButton
			button.NextSelectionDown = self.Refs.StyleReadyButton :: TextButton
		end
	end
end

function App.SetSelectedStyle(self: App, category: string, itemId: string, label: string?)
	self.State.StyleSelected[category] = itemId
	if category == self.State.ActiveStyleCategory then
		self:_renderStyleOptions()
	end
	local shown = label
		or (if self.Locale == "ru" then "Выбранный вариант" else "Selected option")
	local selectedLabel = self.Refs.StyleSelectedLabel :: TextLabel
	selectedLabel.Text = `{CATEGORY_LABELS[category] or localText(
		self.Locale,
		`style.category.{category}`
	)} · {shown}`

	local selectedColor: Color3? = nil
	local options = self.State.StyleOptions[category] :: { StyleOption }?
	for _, option in options or {} do
		if option.id == itemId then
			selectedColor = option.color
			break
		end
	end
	if category == "palette" and selectedColor then
		local viewport = self.Refs.MixViewport :: ViewportFrame
		viewport.Ambient = selectedColor:Lerp(Color3.fromRGB(226, 230, 255), 0.58)
		viewport.LightColor = selectedColor:Lerp(Color3.new(1, 1, 1), 0.78)
	end
	self:_emit(
		"StylePreviewChanged",
		table.clone(self.State.StyleSelected),
		category,
		selectedColor
	)
end

function App.SetStyleReady(self: App, ready: boolean)
	local button = self.Refs.StyleReadyButton :: TextButton
	button:SetAttribute("Ready", ready)
	button.Text = if ready
		then "Готово, жду команду"
		else localText(self.Locale, "button.ready")
end

function App.BeginBloom(self: App, payload: AnyMap)
	local duration = math.max(tonumber(payload.duration) or 10, 0.5)
	local startsAt = tonumber(payload.startsAt or payload.startTime) or workspace:GetServerTimeNow()
	local fill = self.Refs.BloomProgressFill :: Frame
	fill.Size = UDim2.fromScale(0, 1)
	self:ShowPhase("Finale")

	local delaySeconds = math.max(0, startsAt - workspace:GetServerTimeNow())
	task.delay(delaySeconds, function()
		if self.State.Phase ~= "Finale" then
			return
		end
		if self:_isReducedMotionEnabled() then
			fill.Size = UDim2.fromScale(1, 1)
		else
			TweenService:Create(
				fill,
				TweenInfo.new(duration, Enum.EasingStyle.Linear),
				{ Size = UDim2.fromScale(1, 1) }
			):Play()
		end
	end)
end

function App.ShowToast(self: App, key: string, tone: string?, args: AnyMap?)
	local russian = self.Locale == "ru"
	local localizationKeys: { [string]: string } = {
		StyleUpdated = "toast.style_equipped",
		StyleReady = "toast.style_ready",
		CaptureUnavailable = "toast.capture_unavailable",
		StoreReadOnly = "toast.data_read_only",
		style_rejected = "toast.invalid_style",
		look_saved = "toast.look_saved",
		look_deleted = "toast.look_deleted",
		look_equipped = "toast.look_equipped",
		quest_rerolled = "toast.quest_rerolled",
		milestone_claimed = "toast.milestone_claimed",
		first_miracle_complete = "toast.first_miracle_complete",
		postcard_created = "toast.postcard_created",
		secret_frame_found = "toast.secret_frame_found",
		secret_frame_repeat = "toast.secret_frame_repeat",
		secret_frame_collection_complete = "toast.secret_frame_collection_complete",
	}
	local translations: { [string]: string } = {
		StyleUpdated = "Стиль обновлён",
		StyleReady = "Образ готов к финалу",
		VoteAccepted = "Голос учтён",
		InviteSent = "Приглашение отправлено",
		PrismSolved = "Цветовой код собран",
		PrismRetry = "Повторите последовательность",
		CaptureReady = "Карточка готова к сохранению",
		CaptureUnavailable = "Снимок сейчас недоступен",
		ConnectionUnavailable = "Связь прервалась. Попробуйте ещё раз",
		DistrictPreview = "{name} • {hint}",
		style_rejected = "Этот вариант пока нельзя выбрать: {detail}",
		vote_saved = "Голос учтён",
		positive_nomination = "Позитивная номинация от {from}",
		StoreNotConfigured = "Эта покупка пока недоступна",
		StoreReadOnly = "Покупки отключены: прогресс этой сессии не сохраняется",
		StorePromptFailed = "Roblox не смог открыть окно покупки",
		StoreNotPublished = "Покупки появятся после запуска игры",
		server_glowstorm = "{from} запустил(а) Светошум!",
		route_saved = if russian then "Маршрут выбран" else "Route selected",
		requeue_saved = if russian
			then "Ты в очереди на следующий забег"
			else "Queued for the next run",
		look_saved = if russian
			then "Образ сохранён в Лукбук"
			else "Look saved to your Lookbook",
		look_deleted = if russian then "Образ удалён" else "Look deleted",
		look_equipped = if russian then "Образ надет" else "Look equipped",
		quest_rerolled = if russian
			then "Творческая задача обновлена"
			else "Creative quest remixed",
		milestone_claimed = if russian
			then "Награда за этап получена"
			else "Milestone reward claimed",
		postcard_created = if russian
			then "Карточка сохранена"
			else "Postcard saved",
	}
	local plainKey = string.gsub(key, "^Toast%.", "")
	local localizationKey = localizationKeys[plainKey]
	local text = if localizationKey and Localization.Has(self.Locale, localizationKey)
		then localText(self.Locale, localizationKey, args)
		else if Localization.Has(self.Locale, plainKey)
			then localText(self.Locale, plainKey, args)
			else translations[plainKey] or (if russian then "Готово" else "Done")
	if args then
		for argName, value in args do
			text = string.gsub(text, `{argName}`, function()
				local shown = tostring(value)
				if argName == "detail" then
					return if russian
						then "вариант пока закрыт"
						else "option unavailable"
				end
				return shown
			end)
		end
	end

	local toast = self.Refs.Toast :: Frame
	local label = self.Refs.ToastText :: TextLabel
	local stroke = toast:FindFirstChild("ToneStroke") :: UIStroke?
	toast.Visible = true
	label.Text = text
	if stroke then
		stroke.Color = Theme.toneColor(tone or "Info")
	end

	self.State.ToastToken = (self.State.ToastToken or 0) + 1
	local token = self.State.ToastToken
	local target = UDim2.new(0.5, 0, 0, 18)
	if self:_isReducedMotionEnabled() then
		toast.Position = target
	else
		TweenService
			:Create(toast, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Position = target })
			:Play()
	end
	task.delay(3.5, function()
		if self.State.ToastToken ~= token or not toast.Parent then
			return
		end
		if self:_isReducedMotionEnabled() then
			toast.Position = UDim2.new(0.5, 0, 0, -90)
			toast.Visible = false
		else
			TweenService:Create(
				toast,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad),
				{ Position = UDim2.new(0.5, 0, 0, -90) }
			):Play()
			task.delay(0.2, function()
				if self.State.ToastToken == token and toast.Parent then
					toast.Visible = false
				end
			end)
		end
	end)
end

function App.ShowCaption(self: App, text: string, duration: number?, tone: string?)
	if not self.Settings.captions or text == "" then
		return
	end
	local caption = self.Refs.AudioCaption :: TextLabel
	caption.Text = text
	caption.TextColor3 = Theme.toneColor(tone or "Info")
	caption.Visible = true
	self.State.CaptionToken = (self.State.CaptionToken or 0) + 1
	local token = self.State.CaptionToken
	task.delay(math.clamp(duration or 1.35, 0.35, 8), function()
		if self.State.CaptionToken == token and caption.Parent then
			caption.Visible = false
		end
	end)
end

function App._applyHighContrast(self: App)
	local enabled = self.Settings.highContrast
	for _, instance in self.ScreenGui:GetDescendants() do
		if instance:IsA("UIStroke") then
			local baseTransparency = instance:GetAttribute("AuraRushBaseTransparency")
			local baseThickness = instance:GetAttribute("AuraRushBaseThickness")
			if type(baseTransparency) ~= "number" then
				baseTransparency = instance.Transparency
				instance:SetAttribute("AuraRushBaseTransparency", baseTransparency)
			end
			if type(baseThickness) ~= "number" then
				baseThickness = instance.Thickness
				instance:SetAttribute("AuraRushBaseThickness", baseThickness)
			end
			instance.Transparency = if enabled
				then math.min(baseTransparency, 0.18)
				else baseTransparency
			instance.Thickness = if enabled then math.max(baseThickness, 2) else baseThickness
		elseif instance:IsA("TextLabel") or instance:IsA("TextButton") then
			local baseColor = instance:GetAttribute("AuraRushBaseTextColor")
			if typeof(baseColor) ~= "Color3" then
				baseColor = instance.TextColor3
				instance:SetAttribute("AuraRushBaseTextColor", baseColor)
			end
			if
				enabled
				and (baseColor == Theme.Colors.TextMuted or baseColor == Theme.Colors.TextDim)
			then
				instance.TextColor3 = Theme.Colors.Text
			else
				instance.TextColor3 = baseColor
			end
		end
	end
	self.ScreenGui:SetAttribute("HighContrast", enabled)
end

function App.SetSettingsVisible(self: App, visible: boolean)
	local settingsOverlay = self.Refs.SettingsOverlay :: TextButton
	settingsOverlay.Visible = visible
	if visible and UserInputService.GamepadEnabled then
		GuiService.SelectedObject = self.Refs.Setting_reducedMotion :: GuiObject
	elseif not visible and UserInputService.GamepadEnabled then
		GuiService.SelectedObject = self.Refs.SettingsButton :: GuiObject
	end
end

function App.SetSetting(self: App, key: string, value: boolean | number, notifyServer: boolean?)
	if self.Settings[key :: any] == nil then
		return
	end
	if type(value) == "number" then
		value = math.clamp(value, 0, 1)
	end
	self.Settings[key :: any] = value :: any
	if key == "largeText" then
		local accessibilityScale = self.Refs.AccessibilityScale :: UIScale
		accessibilityScale.Scale = if self:_isLargeTextEnabled() then 1.08 else 1
	elseif key == "highContrast" then
		Players.LocalPlayer:SetAttribute("AuraRushHighContrast", value == true)
		self:_applyHighContrast()
	elseif key == "captions" and value == false then
		local caption = self.Refs.AudioCaption :: TextLabel
		caption.Visible = false
	end
	self:_refreshSettingButtons()
	self:_emit("LocalSettingsChanged", self:GetSettings())
	if notifyServer ~= false then
		self:_emit("SettingsChanged", self:GetSettings())
	end
end

function App._refreshSettingButtons(self: App)
	for _, key in
		{
			"reducedMotion",
			"lowVfx",
			"noFlashes",
			"largeText",
			"captions",
			"highContrast",
			"haptics",
		}
	do
		local button = self.Refs[`Setting_{key}`] :: TextButton?
		if button then
			local on = if key == "reducedMotion"
				then self:_isReducedMotionEnabled()
				else if key == "largeText"
					then self:_isLargeTextEnabled()
					else self.Settings[key :: any] == true
			button.Text = if self.Locale == "ru"
				then if on then "Вкл" else "Выкл"
				else if on then "ON" else "OFF"
			Theme.setButtonSelected(button, on)
		end
	end
	for _, key in { "musicVolume", "sfxVolume", "ambienceVolume" } do
		local valueLabel = self.Refs[`Setting_{key}_Value`] :: TextLabel?
		local value = self.Settings[key :: any]
		if valueLabel and type(value) == "number" then
			valueLabel.Text = `{math.floor(math.clamp(value, 0, 1) * 100 + 0.5)}%`
		end
	end
end

function App._setGlowstormTokenCount(self: App, count: number)
	local safeCount = math.max(0, math.floor(count))
	self.State.GlowstormTokenCount = safeCount
	local invite = self.Refs.HubInvite :: TextButton
	local glowstorm = self.Refs.HubGlowstorm :: TextButton
	local available = safeCount > 0
	invite.Size = if available then UDim2.new(0.5, -6, 1, 0) else UDim2.fromScale(1, 1)
	glowstorm.Visible = available
	glowstorm.TextWrapped = true
	glowstorm.Text = `{localText(self.Locale, "product.server_glowstorm.name")} x{safeCount}`
	if not available then
		glowstorm:SetAttribute("CoolingDown", false)
		glowstorm.Active = false
		glowstorm.AutoButtonColor = false
	elseif glowstorm:GetAttribute("CoolingDown") ~= true then
		glowstorm.Active = true
		glowstorm.AutoButtonColor = true
	end
end

function App.ApplyMetaUpdate(self: App, payload: AnyMap)
	local data = if type(payload.data) == "table" then payload.data else payload
	local profile = if type(data.profile) == "table" then data.profile else data
	local dataMeta = if type(data.meta) == "table" then data.meta else nil
	local profileMeta = if type(profile.meta) == "table" then profile.meta else nil
	local activationTokens = data.activationTokens
		or profile.activationTokens
		or (if dataMeta then dataMeta.activationTokens else nil)
		or (if profileMeta then profileMeta.activationTokens else nil)
	if type(activationTokens) == "table" then
		self:_setGlowstormTokenCount(tonumber(activationTokens.glowstorm) or 0)
	end
	local progression = if type(data.progression) == "table"
		then data.progression
		else if type(profile.progression) == "table" then profile.progression else data
	local hasProgression = progression.creativeRank ~= nil
		or data.creativeRank ~= nil
		or data.auraAtlasXp ~= nil
		or profile.auraAtlasXp ~= nil
		or data.quests ~= nil
		or profile.quests ~= nil
	if not hasProgression then
		return
	end
	local rank = math.max(
		1,
		math.floor(tonumber(progression.creativeRank or data.creativeRank or data.rank) or 1)
	)
	local atlasValue = data.atlasXp or data.atlasXP or data.auraAtlasXp or profile.auraAtlasXp
	local atlasXp = 0
	if type(atlasValue) == "table" then
		for _, value in atlasValue do
			atlasXp += math.max(0, tonumber(value) or 0)
		end
	else
		atlasXp = math.max(0, tonumber(atlasValue or data.xp) or 0)
	end
	atlasXp = math.floor(atlasXp)
	local quest = ""
	local quests = if type(data.quests) == "table" then data.quests else profile.quests
	if quest == "" and type(quests) == "table" then
		local daily = quests.daily
		local items = if type(daily) == "table" and type(daily.items) == "table"
			then daily.items
			else nil
		for _, item in items or {} do
			if type(item) == "table" and item.completed ~= true then
				quest = QUEST_LABELS[tostring(item.kind or "")] or ""
				break
			end
		end
	end
	self.State.Meta = table.clone(payload)
	local concise = if self.Locale == "ru"
		then `Уровень {rank} · {atlasXp} опыта`
		else `Level {rank} · {atlasXp} XP`
	local metaHud = self.Refs.MetaHud :: TextLabel
	local resultsMeta = self.Refs.ResultsMeta :: TextLabel
	metaHud.Text = concise
	resultsMeta.Text = if quest ~= "" then `{concise} · {quest}` else concise
end

function App.ApplyRunUpdate(self: App, payload: AnyMap)
	local data = if type(payload.data) == "table" then payload.data else payload
	local route = ""
	local routeTitleKey = data.routeTitleKey or data.routeNameKey
	if type(routeTitleKey) == "string" and Localization.Has(self.Locale, routeTitleKey) then
		route = localText(self.Locale, routeTitleKey)
	else
		route = localizedIdentifier(self.Locale, "route", data.selectedRouteId or data.routeId)
	end
	local currentAct = if type(data.currentAct) == "table" then data.currentAct else nil
	local branch = ""
	local branchTitleKey = data.branchTitleKey or (if currentAct then currentAct.titleKey else nil)
	if type(branchTitleKey) == "string" and Localization.Has(self.Locale, branchTitleKey) then
		branch = localText(self.Locale, branchTitleKey)
	elseif currentAct and type(currentAct.id) == "string" and currentAct.id ~= "" then
		branch = localizedIdentifier(self.Locale, "act", currentAct.id)
	end
	local modifierData = if type(data.modifier) == "table" then data.modifier else nil
	local modifier = ""
	local modifierTitleKey = data.modifierTitleKey
		or (if modifierData then modifierData.titleKey else nil)
	if type(modifierTitleKey) == "string" and Localization.Has(self.Locale, modifierTitleKey) then
		modifier = localText(self.Locale, modifierTitleKey)
	else
		modifier = localizedIdentifier(
			self.Locale,
			"modifier",
			(if modifierData then modifierData.id else data.modifierId)
		)
	end
	local parts: { string } = {}
	for _, value in { route, branch, modifier } do
		if value ~= "" then
			if not string.find(value, "[%._:]") then
				table.insert(parts, value)
			end
		end
	end
	local text = table.concat(parts, " · ")
	self.State.Run = table.clone(payload)
	local routeRibbon = self.Refs.RouteRibbon :: TextLabel
	local resultsRoute = self.Refs.ResultsRoute :: TextLabel
	routeRibbon.Text = text
	resultsRoute.Text = text
	resultsRoute.Visible = text ~= ""
	self:_refreshPresentation()
end

function App.GetSettings(self: App): AccessibilitySettings
	local effective = table.clone(self.Settings)
	effective.reducedMotion = self:_isReducedMotionEnabled()
	effective.largeText = self:_isLargeTextEnabled()
	return effective
end

function App.SetCaptureMode(self: App, capturing: boolean)
	self.State.Capturing = capturing
	self.Root.Visible = not capturing
	self:_refreshPresentation()
end

function App.Destroy(self: App)
	if self.ViewportConnection then
		self.ViewportConnection:Disconnect()
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	for _, event in self.Events do
		event:Destroy()
	end
	self.ScreenGui:Destroy()
end

return App
