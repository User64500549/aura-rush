--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AppModule = require(script.Parent.Parent.UI.App)
local Components = require(script.Parent.Parent.UI.Components)
local StyleOS = require(script.Parent.Parent.UI.StyleOS)
local Theme = require(script.Parent.Parent.UI.Theme)
local RemoteRegistryModule = require(script.Parent.RemoteRegistry)

local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local Localization = require(sharedRoot:WaitForChild("Localization"))

type App = AppModule.App
type RemoteRegistry = RemoteRegistryModule.RemoteRegistry
type AnyMap = { [string]: any }
type ActionDefinition = {
	label: string,
	enabled: boolean,
	variant: Theme.ButtonVariant?,
	callback: () -> (),
}

local MetaPanelController = {}
MetaPanelController.__index = MetaPanelController

export type MetaPanelController = typeof(setmetatable(
	{} :: {
		App: App,
		Remotes: RemoteRegistry,
		Player: Player,
		Button: TextButton,
		Overlay: TextButton,
		Panel: Frame,
		TabBar: Frame,
		TabButtons: { [string]: TextButton },
		Body: ScrollingFrame,
		Connections: { RBXScriptConnection },
		DynamicConnections: { RBXScriptConnection },
		Meta: AnyMap,
		LastSnapshot: AnyMap?,
		PendingInvite: AnyMap?,
		PendingInviteBlock: boolean,
		PendingLookDelete: string,
		PendingPostcardDelete: string,
		PendingReplayDelete: string,
		PendingAtelierLeave: boolean,
		Nominated: boolean,
		ActiveTab: string,
		NextOrder: number,
		Refreshing: boolean,
		Destroyed: boolean,
	},
	MetaPanelController
))

local QUEST_NAMES: { [string]: { en: string, ru: string } } = table.freeze({
	complete_round = { en = "Complete a finale", ru = "Заверши Перекраску" },
	collect_threads = { en = "Collect style threads", ru = "Собери нити стиля" },
	hit_beats = { en = "Catch beat pulses", ru = "Поймай бит-импульсы" },
	hit_perfects = { en = "Land perfect pulses", ru = "Попади идеально в бит" },
	solve_prism = { en = "Solve the color code", ru = "Собери Цветовой код" },
	finish_style = { en = "Finish a look", ru = "Заверши образ" },
})

local function createLabel(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	font: Enum.Font?,
	zIndex: number?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.ZIndex = zIndex or 94
	Theme.styleText(label, size, font)
	label.Parent = parent
	return label
end

local function createButton(
	parent: Instance,
	name: string,
	text: string,
	variant: Theme.ButtonVariant?,
	zIndex: number?
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.TextWrapped = true
	button.ZIndex = zIndex or 95
	Theme.styleButton(button, variant)
	StyleOS.makePressable(button, if text ~= "" then text else nil)
	button.Parent = parent
	return button
end

local function setButtonEnabled(button: TextButton, enabled: boolean): ()
	button.Active = enabled
	button.Selectable = enabled
	button.AutoButtonColor = enabled
	button.TextTransparency = if enabled then 0 else StyleOS.Tokens.Opacity.Disabled
	if not enabled then
		button.BackgroundColor3 = Theme.Colors.Surface
		button.TextColor3 = Theme.Colors.TextMuted
	end
end

local function safeText(value: any, maximumCharacters: number?): string
	local text = if type(value) == "string" then value else tostring(value or "")
	text = string.gsub(text, "[%c]", " ")
	local maximum = maximumCharacters or 80
	local ok, length = pcall(utf8.len, text)
	if ok and type(length) == "number" and length > maximum then
		local offsetOk, byteOffset = pcall(utf8.offset, text, maximum + 1)
		if offsetOk and type(byteOffset) == "number" then
			text = string.sub(text, 1, byteOffset - 1)
		end
	elseif not ok and #text > maximum then
		text = string.sub(text, 1, maximum)
	end
	return text
end

local function localizedIdentifier(
	locale: string,
	namespace: string,
	value: any,
	fallback: string
): string
	if type(value) == "string" and type(Localization.GetIdentifier) == "function" then
		return Localization.GetIdentifier(locale, namespace, value)
	end
	return fallback
end

local function timeUntil(locale: string, endsAt: any): string
	local remaining = math.max(0, math.floor((tonumber(endsAt) or 0) - os.time()))
	if remaining <= 0 then
		return if locale == "ru" then "Скоро сменится" else "Changing soon"
	end
	local days = math.floor(remaining / 86400)
	local hours = math.floor((remaining % 86400) / 3600)
	if days > 0 then
		return if locale == "ru"
			then `До смены: {days} д {hours} ч`
			else `Changes in {days}d {hours}h`
	end
	local minutes = math.max(1, math.floor((remaining % 3600) / 60))
	return if locale == "ru"
		then `До смены: {hours} ч {minutes} мин`
		else `Changes in {hours}h {minutes}m`
end

local function isFlagEnabled(key: string): boolean
	return Players.LocalPlayer:GetAttribute("AuraRushFlag_" .. key) ~= false
end

local function localText(locale: string, key: string): string
	if type(Localization.GetPlayerText) == "function" then
		return Localization.GetPlayerText(locale, key)
	end
	return Localization.Get(locale, key)
end

local function questName(locale: string, item: AnyMap): string
	local definition = QUEST_NAMES[tostring(item.kind or "")]
	if definition then
		return if locale == "ru" then definition.ru else definition.en
	end
	for _, key in { item.titleKey, item.nameKey, item.displayNameKey } do
		if type(key) == "string" and Localization.Has(locale, key) then
			return localText(locale, key)
		end
	end
	return if locale == "ru" then "Задание дня" else "Daily quest"
end

function MetaPanelController.new(app: App, remotes: RemoteRegistry): MetaPanelController
	local player = Players.LocalPlayer
	local button = createButton(app.TopBar, "CreatorHubButton", "Моё", "Quiet", 4)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -390, 0.5, 0)
	button.Size = UDim2.fromOffset(108, 48)
	button.TextSize = Theme.TextSizes.Caption
	StyleOS.makePressable(
		button,
		if app.Locale == "ru" then "Мой стиль" else "My style",
		if app.Locale == "ru"
			then "Образы, задания и друзья"
			else "Looks, quests, and friends"
	)

	local overlay = Instance.new("TextButton")
	overlay.Name = "CreatorHubOverlay"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Active = true
	overlay.Selectable = false
	overlay.Modal = true
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = StyleOS.Tokens.Opacity.Scrim
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 90
	overlay.Parent = app.OverlayContainer
	app:TrackPrimaryOverlay(overlay)

	local panel = Instance.new("Frame")
	panel.Name = "CreatorHubPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.9)
	panel.ZIndex = 91
	Theme.stylePanel(panel, true)
	Theme.addGradient(panel, {
		Theme.Colors.SurfaceRaised,
		Theme.Colors.Surface,
		Theme.Colors.BackgroundSoft,
	}, 0)
	Theme.addAccentBand(panel, Theme.Colors.Lime, 8)
	panel.Parent = overlay
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(300, 320)
	constraint.MaxSize = Vector2.new(920, 720)
	constraint.Parent = panel
	StyleOS.attachQuery(panel, "AuraRushNarrowPanel", {
		MaxSize = Vector2.new(620, math.huge),
	})

	local title = createLabel(
		panel,
		"Title",
		if app.Locale == "ru" then "Мой стиль" else "My style",
		Theme.TextSizes.Title,
		Theme.Fonts.Display,
		93
	)
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -230, 0, 48)
	title.TextColor3 = Theme.Colors.Text

	local subtitle = createLabel(
		panel,
		"Subtitle",
		if app.Locale == "ru"
			then "Образы, задания, друзья и общий район"
			else "Looks, quests, friends, and the shared district",
		Theme.TextSizes.Caption,
		Theme.Fonts.Medium,
		93
	)
	subtitle.Position = UDim2.fromOffset(26, 53)
	subtitle.Size = UDim2.new(1, -230, 0, 24)
	subtitle.TextColor3 = Theme.Colors.TextMuted
	StyleOS.tag(subtitle, StyleOS.Tags.SupportText)

	local refresh = createButton(panel, "Refresh", "Обновить", "Quiet", 94)
	refresh.AnchorPoint = Vector2.new(1, 0)
	refresh.Position = UDim2.new(1, -78, 0, 14)
	refresh.Size = UDim2.fromOffset(92, 48)
	refresh.TextSize = 12

	local close = createButton(panel, "Close", "×", "Quiet", 94)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -18, 0, 14)
	close.Size = UDim2.fromOffset(48, 48)
	close.TextSize = 24
	StyleOS.makePressable(close, if app.Locale == "ru" then "Закрыть" else "Close")

	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.Position = UDim2.fromOffset(18, 86)
	tabBar.Size = UDim2.new(1, -36, 0, 46)
	tabBar.BackgroundTransparency = 1
	tabBar.ZIndex = 93
	tabBar.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, Theme.Spacing.S)
	tabLayout.Parent = tabBar
	local tabButtons: { [string]: TextButton } = {}
	for order, definition in
		{
			{ id = "overview", label = if app.Locale == "ru" then "Обзор" else "Overview" },
			{ id = "looks", label = if app.Locale == "ru" then "Образы" else "Looks" },
			{ id = "quests", label = if app.Locale == "ru" then "Цели" else "Quests" },
			{ id = "team", label = if app.Locale == "ru" then "Команда" else "Team" },
		}
	do
		local tab = createButton(tabBar, `Tab_{definition.id}`, definition.label, "Quiet", 94)
		tab.LayoutOrder = order
		tab.Size = UDim2.new(0.25, -6, 1, 0)
		tab.TextSize = Theme.TextSizes.Caption
		Theme.styleNavTab(tab, definition.id == "overview")
		tabButtons[definition.id] = tab
	end
	local tabOrder = { "overview", "looks", "quests", "team" }
	for index, tabId in tabOrder do
		local tab = tabButtons[tabId]
		tab.NextSelectionLeft = tabButtons[tabOrder[math.max(1, index - 1)]]
		tab.NextSelectionRight = tabButtons[tabOrder[math.min(#tabOrder, index + 1)]]
	end

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(18, 142)
	body.Size = UDim2.new(1, -36, 1, -160)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 5
	body.ScrollBarImageColor3 = Theme.Colors.Cyan
	body.ZIndex = 92
	body.Parent = panel
	local bodyPadding = Instance.new("UIPadding")
	bodyPadding.PaddingRight = UDim.new(0, 8)
	bodyPadding.PaddingBottom = UDim.new(0, 18)
	bodyPadding.Parent = body
	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.Name = "Layout"
	bodyLayout.Padding = UDim.new(0, Theme.Spacing.M)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bodyLayout.Parent = body

	local self: MetaPanelController = setmetatable({
		App = app,
		Remotes = remotes,
		Player = player,
		Button = button,
		Overlay = overlay,
		Panel = panel,
		TabBar = tabBar,
		TabButtons = tabButtons,
		Body = body,
		Connections = {},
		DynamicConnections = {},
		Meta = {},
		LastSnapshot = nil,
		PendingInvite = nil,
		PendingInviteBlock = false,
		PendingLookDelete = "",
		PendingPostcardDelete = "",
		PendingReplayDelete = "",
		PendingAtelierLeave = false,
		Nominated = false,
		ActiveTab = "overview",
		NextOrder = 0,
		Refreshing = false,
		Destroyed = false,
	}, MetaPanelController)

	for tabId, tabButton in tabButtons do
		table.insert(
			self.Connections,
			tabButton.Activated:Connect(function()
				self:_setTab(tabId)
			end)
		)
	end
	self:_bind(button, close, refresh)
	self:_render()
	return self
end

function MetaPanelController._connectDynamic(
	self: MetaPanelController,
	button: TextButton,
	callback: () -> ()
): ()
	table.insert(self.DynamicConnections, button.Activated:Connect(callback))
end

function MetaPanelController._clearDynamic(self: MetaPanelController): ()
	for _, connection in self.DynamicConnections do
		connection:Disconnect()
	end
	table.clear(self.DynamicConnections)
	for _, child in self.Body:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	self.NextOrder = 0
end

function MetaPanelController._nextOrder(self: MetaPanelController): number
	self.NextOrder += 1
	return self.NextOrder
end

function MetaPanelController._setTab(self: MetaPanelController, tabId: string): ()
	if self.TabButtons[tabId] == nil or self.ActiveTab == tabId then
		return
	end
	self.ActiveTab = tabId
	self.PendingLookDelete = ""
	self.PendingPostcardDelete = ""
	self.PendingReplayDelete = ""
	self.PendingAtelierLeave = false
	self.PendingInviteBlock = false
	for id, button in self.TabButtons do
		Theme.styleNavTab(button, id == tabId)
	end
	self.Body.CanvasPosition = Vector2.zero
	self:_render()
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = self.TabButtons[tabId]
	end
end

function MetaPanelController._addSection(self: MetaPanelController, text: string): ()
	local label =
		createLabel(self.Body, "Section", text, Theme.TextSizes.Caption, Theme.Fonts.Bold, 93)
	label.LayoutOrder = self:_nextOrder()
	label.Size = UDim2.new(1, 0, 0, 28)
	Theme.styleSectionLabel(label)
	StyleOS.tag(label, StyleOS.Tags.SupportText)
end

function MetaPanelController._addCard(
	self: MetaPanelController,
	titleText: string,
	detailText: string,
	actions: { ActionDefinition }?
): ()
	local actionList = actions or {}
	local order = self:_nextOrder()
	local accentColors = {
		Theme.Colors.Cyan,
		Theme.Colors.Lime,
		Theme.Colors.Gold,
		Theme.Colors.Magenta,
	}
	local _, _, _, row = Components.createInfoCard(self.Body, {
		layoutOrder = order,
		title = safeText(titleText, 96),
		detail = safeText(detailText, 180),
		hasActions = #actionList > 0,
		zIndex = 93,
		accent = accentColors[((order - 1) % #accentColors) + 1],
	})

	if row then
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, Theme.Spacing.S)
		layout.Parent = row
		for index, action in actionList do
			local actionButton =
				createButton(row, `Action{index}`, action.label, action.variant, 95)
			actionButton.LayoutOrder = index
			actionButton.Size = UDim2.new(1 / #actionList, -Theme.Spacing.S, 1, 0)
			actionButton.TextSize = if #actionList >= 3 then 11 else 13
			setButtonEnabled(actionButton, action.enabled)
			if action.enabled then
				self:_connectDynamic(actionButton, action.callback)
			end
		end
	end
end

function MetaPanelController._fire(
	self: MetaPanelController,
	remoteName: string,
	payload: AnyMap,
	refreshAfter: boolean?
): ()
	local remote = self.Remotes:GetEvent(remoteName)
	if not remote then
		self.App:ShowToast("ConnectionUnavailable", "Warning")
		return
	end
	remote:FireServer(payload)
	if refreshAfter then
		task.delay(0.45, function()
			self:_refresh()
		end)
	end
end

function MetaPanelController._mergeMeta(self: MetaPanelController, payload: AnyMap): ()
	if payload.kind == "AtelierInvite" then
		self.PendingInvite = {
			atelierId = safeText(payload.atelierId, 80),
			fromUserId = tonumber(payload.fromUserId),
			fromDisplayName = safeText(payload.fromDisplayName, 32),
		}
		self.PendingInviteBlock = false
	elseif payload.kind == "AtelierInviteDismissed" then
		self.PendingInvite = nil
		self.PendingInviteBlock = false
	end
	local data = if type(payload.data) == "table" then payload.data else payload
	for _, key in
		{
			"profile",
			"progression",
			"quests",
			"liveOps",
			"communityBloom",
			"season",
			"secretFrames",
			"featureFlags",
			"party",
			"recentPostcards",
		}
	do
		if data[key] ~= nil then
			self.Meta[key] = data[key]
		end
	end
	if type(payload.profile) == "table" then
		self.Meta.profile = payload.profile
	end
	if self.Overlay.Visible then
		self:_render()
	end
end

function MetaPanelController._refresh(self: MetaPanelController): ()
	if self.Destroyed or self.Refreshing then
		return
	end
	local request = self.Remotes:GetFunction("RequestMeta")
	if not request then
		return
	end
	self.Refreshing = true
	task.spawn(function()
		local ok, result = pcall(function()
			return request:InvokeServer({})
		end)
		self.Refreshing = false
		if self.Destroyed then
			return
		end
		if ok and type(result) == "table" then
			self:_mergeMeta(result)
		else
			self.App:ShowToast("ConnectionUnavailable", "Warning")
		end
	end)
end

function MetaPanelController._renderOverview(self: MetaPanelController, profile: AnyMap): ()
	self:_addSection(
		if self.App.Locale == "ru"
			then "Мой прогресс и общий район"
			else "Profile & shared district"
	)
	local progression = if type(self.Meta.progression) == "table"
		then self.Meta.progression
		else if type(profile.progression) == "table" then profile.progression else {}
	local rank = math.max(1, math.floor(tonumber(progression.creativeRank) or 1))
	local glowDust = math.max(0, math.floor(tonumber(profile.glowDust) or 0))
	local atlasXp = 0
	for _, value in if type(profile.auraAtlasXp) == "table" then profile.auraAtlasXp else {} do
		atlasXp += math.max(0, math.floor(tonumber(value) or 0))
	end
	self:_addCard(
		if self.App.Locale == "ru"
			then `Уровень {rank} · {glowDust} Искр`
			else `Creative rank {rank} / {glowDust} Sparks`,
		if self.App.Locale == "ru" then `Опыт стиля: {atlasXp}` else `Style XP: {atlasXp}`,
		nil
	)
	if profile.readOnly == true then
		self:_addCard(
			if self.App.Locale == "ru"
				then "Сохранение на паузе"
				else "READ-ONLY SESSION",
			if self.App.Locale == "ru"
				then "Можно продолжать играть, но прогресс этой сессии не сохранится."
				else "You can keep playing, but this session will not be saved.",
			nil
		)
	end
	local secretFrames = if type(self.Meta.secretFrames) == "table"
		then self.Meta.secretFrames
		else {}
	if secretFrames.enabled == true then
		local found = math.max(0, math.floor(tonumber(secretFrames.foundCount) or 0))
		local total = math.max(0, math.floor(tonumber(secretFrames.total) or 0))
		self:_addCard(
			if self.App.Locale == "ru"
				then `Секретные кадры · {found} из {total}`
				else `Secret Frames · {found} of {total}`,
			if secretFrames.complete == true
				then (if self.App.Locale == "ru"
					then "Коллекция собрана. Все шесть районов оставили свой след."
					else "Collection complete. Every district left its mark.")
				else (if self.App.Locale == "ru"
					then "Обходи ворота районов и ищи небольшие световые рамки."
					else "Explore district gates and look for small glowing frames."),
			nil
		)
	end

	local liveOps = if type(self.Meta.liveOps) == "table" then self.Meta.liveOps else {}
	local community = if type(self.Meta.communityBloom) == "table"
		then self.Meta.communityBloom
		else {}
	local totals = if type(community.totals) == "table" then community.totals else {}
	local contributions = if type(liveOps.contributions) == "table"
		then liveOps.contributions
		else {}
	local claimed = if type(liveOps.claimedMilestones) == "table"
		then liveOps.claimedMilestones
		else {}
	local featuredDistrict = if type(liveOps.featuredDistrict) == "table"
		then liveOps.featuredDistrict
		else nil
	if featuredDistrict then
		local goal = math.max(1, math.floor(tonumber(featuredDistrict.goal) or 1))
		local progress = math.clamp(math.floor(tonumber(featuredDistrict.progress) or 0), 0, goal)
		local districtName = localizedIdentifier(
			self.App.Locale,
			"world",
			featuredDistrict.worldId,
			if self.App.Locale == "ru" then "Новый район" else "New district"
		)
		self:_addCard(
			if self.App.Locale == "ru"
				then `Район недели / {districtName}`
				else `District of the week / {districtName}`,
			`{progress} из {goal} / {timeUntil(self.App.Locale, featuredDistrict.endsAt)}`,
			nil
		)
	end
	if liveOps.enabled == true and isFlagEnabled("LiveOps") then
		for _, event in if type(liveOps.activeEvents) == "table" then liveOps.activeEvents else {} do
			if type(event) == "table" and type(event.id) == "string" then
				local eventName = if type(event.displayNameKey) == "string"
					then localText(self.App.Locale, event.displayNameKey)
					else if self.App.Locale == "ru"
						then "Событие недели"
						else "Weekly event"
				local progress = math.max(
					math.floor(tonumber(totals[event.id]) or 0),
					math.floor(tonumber(contributions[event.id]) or 0)
				)
				for _, milestone in
					if type(event.milestones) == "table" then event.milestones else {}
				do
					if type(milestone) == "table" and type(milestone.id) == "string" then
						local target = math.max(1, math.floor(tonumber(milestone.target) or 1))
						local reward = math.max(0, math.floor(tonumber(milestone.glowDust) or 0))
						local key = event.id .. ":" .. milestone.id
						local isClaimed = claimed[key] == true
						local canClaim = progress >= target
							and not isClaimed
							and profile.readOnly ~= true
						self:_addCard(
							`{eventName} / {if self.App.Locale == "ru"
								then "Этап"
								else "Milestone"}`,
							`{math.min(progress, target)} из {target} / +{reward} Искр`,
							{
								{
									label = if isClaimed
										then (if self.App.Locale == "ru"
											then "Получено"
											else "Claimed")
										else (if self.App.Locale == "ru"
											then "Забрать награду"
											else "CLAIM MILESTONE"),
									enabled = canClaim,
									variant = "Primary",
									callback = function()
										self:_fire("ClaimQuest", {
											eventId = event.id,
											milestoneId = milestone.id,
										}, true)
									end,
								},
							}
						)
					end
				end
			end
		end
	end
end

function MetaPanelController._renderSeason(self: MetaPanelController, profile: AnyMap): ()
	if not isFlagEnabled("SeasonOne") then
		return
	end
	local season = if type(self.Meta.season) == "table" then self.Meta.season else {}
	local xp = math.max(0, math.floor(tonumber(season.xp) or 0))
	local nodes = if type(season.nodes) == "table" then season.nodes else {}
	self:_addSection(if self.App.Locale == "ru" then "REMIX-сезон" else "Remix season")
	self:_addCard(
		if self.App.Locale == "ru" then `Сезон 1 · {xp} XP` else `Season 1 · {xp} XP`,
		if self.App.Locale == "ru"
			then "40 этапов без усилений: только Искры, образы и эффекты."
			else "40 cosmetic-only nodes with Sparks, looks, and effects.",
		nil
	)
	local shown = 0
	for _, node in nodes do
		if type(node) == "table" and node.claimed ~= true and shown < 5 then
			shown += 1
			local target = math.max(1, math.floor(tonumber(node.xpTarget) or 1))
			local position = math.max(1, math.floor(tonumber(node.position) or shown))
			local reward = if self.App.Locale == "ru"
				then safeText(node.rewardLabelRu, 64)
				else "Cosmetic reward"
			self:_addCard(
				`{if self.App.Locale == "ru" then "Этап" else "Node"} {position} / {reward}`,
				`{math.min(xp, target)} из {target} XP`,
				{
					{
						label = if node.canClaim == true
							then (if self.App.Locale == "ru" then "Забрать" else "Claim")
							else (if self.App.Locale == "ru"
								then "Играй дальше"
								else "Keep playing"),
						enabled = node.canClaim == true and profile.readOnly ~= true,
						variant = "Primary",
						callback = function()
							self:_fire("RemixAction", {
								action = "claim_season",
								nodeId = node.id,
							}, true)
						end,
					},
				}
			)
		end
	end
	if #nodes > 0 and shown == 0 then
		self:_addCard(
			if self.App.Locale == "ru" then "Сезон пройден" else "Season complete",
			if self.App.Locale == "ru"
				then "Все бесплатные награды уже в коллекции."
				else "Every free reward is in your collection.",
			nil
		)
	end
end

function MetaPanelController._renderLookbook(self: MetaPanelController, profile: AnyMap): ()
	self:_addSection(if self.App.Locale == "ru" then "Лукбук" else "Lookbook")
	local readOnly = profile.readOnly == true
	self:_addCard(
		if self.App.Locale == "ru" then "Текущий образ" else "Current look",
		if self.App.Locale == "ru"
			then "Сохрани комбинацию пяти категорий для будущих забегов."
			else "Save all five style categories for future runs.",
		{
			{
				label = if self.App.Locale == "ru"
					then "Сохранить в Лукбук"
					else "Save look",
				enabled = not readOnly,
				variant = "Primary",
				callback = function()
					self:_fire("SaveLook", {}, true)
				end,
			},
		}
	)
	local looks = if type(profile.savedLooks) == "table" then profile.savedLooks else {}
	if #looks == 0 then
		self:_addCard(
			if self.App.Locale == "ru"
				then "Здесь пока пусто"
				else "Your Lookbook is empty",
			if self.App.Locale == "ru"
				then "Сохрани первый образ после Гримерки."
				else "Save your first look after Mix Lab.",
			nil
		)
	end
	for index = #looks, 1, -1 do
		local look = looks[index]
		if type(look) == "table" and type(look.id) == "string" then
			local confirming = self.PendingLookDelete == look.id
			local lookName = safeText(look.name, 24)
			self:_addCard(
				if lookName ~= "" then lookName else `Образ {index}`,
				if self.App.Locale == "ru"
					then `Сохранённый образ {index}`
					else `Saved look {index}`,
				{
					{
						label = if self.App.Locale == "ru" then "Надеть" else "Equip",
						enabled = true,
						variant = "Secondary",
						callback = function()
							self:_fire("EquipLook", { lookId = look.id }, true)
						end,
					},
					{
						label = if confirming
							then (if self.App.Locale == "ru"
								then "Да, удалить"
								else "CONFIRM")
							else (if self.App.Locale == "ru"
								then "Удалить"
								else "Delete"),
						enabled = not readOnly,
						variant = "Danger",
						callback = function()
							if self.PendingLookDelete == look.id then
								self.PendingLookDelete = ""
								self:_fire("DeleteLook", { lookId = look.id }, true)
							else
								self.PendingLookDelete = look.id
								self:_render()
							end
						end,
					},
				}
			)
		end
	end
end

function MetaPanelController._renderRemixes(self: MetaPanelController, profile: AnyMap): ()
	self:_addSection(
		if self.App.Locale == "ru" then "Архив ремиксов" else "Remix archive"
	)
	local remixCity = if type(profile.remixCity) == "table" then profile.remixCity else {}
	local saved = if type(remixCity.savedReplays) == "table" then remixCity.savedReplays else {}
	if #saved == 0 then
		self:_addCard(
			if self.App.Locale == "ru" then "Архив пока пуст" else "Archive is empty",
			if self.App.Locale == "ru"
				then "После финала сохрани ремикс — лучшие действия соберутся в короткий повтор."
				else "Save a remix after the finale to keep its best actions.",
			nil
		)
		return
	end
	local rendered = 0
	for index = #saved, 1, -1 do
		local replay = saved[index]
		if type(replay) == "table" and type(replay.id) == "string" and rendered < 8 then
			rendered += 1
			local confirming = self.PendingReplayDelete == replay.id
			local eventCount = if type(replay.events) == "table" then #replay.events else 0
			local worldName = localizedIdentifier(
				self.App.Locale,
				"world",
				replay.worldId,
				if self.App.Locale == "ru" then "Район" else "District"
			)
			self:_addCard(
				if self.App.Locale == "ru"
					then safeText(replay.chemistryNameRu, 64)
					else "Saved remix",
				`{worldName} · {eventCount} {if self.App.Locale == "ru"
					then "кадров"
					else "moments"}`,
				{
					{
						label = if self.App.Locale == "ru" then "Смотреть" else "Play",
						enabled = true,
						variant = "Primary",
						callback = function()
							self:_fire("RemixAction", {
								action = "play_saved",
								replayId = replay.id,
							}, false)
							self:_setVisible(false)
						end,
					},
					{
						label = if confirming
							then (if self.App.Locale == "ru"
								then "Да, удалить"
								else "Confirm")
							else (if self.App.Locale == "ru"
								then "Удалить"
								else "Delete"),
						enabled = profile.readOnly ~= true,
						variant = "Danger",
						callback = function()
							if self.PendingReplayDelete == replay.id then
								self.PendingReplayDelete = ""
								self:_fire("RemixAction", {
									action = "delete_saved",
									replayId = replay.id,
								}, true)
							else
								self.PendingReplayDelete = replay.id
								self:_render()
							end
						end,
					},
				}
			)
		end
	end
end

function MetaPanelController._renderQuests(self: MetaPanelController, profile: AnyMap): ()
	self:_addSection(if self.App.Locale == "ru" then "Задания" else "Creative quests")
	local quests = if type(self.Meta.quests) == "table"
		then self.Meta.quests
		else if type(profile.quests) == "table" then profile.quests else {}
	local daily = if type(quests.daily) == "table" then quests.daily else {}
	local rerollsUsed = math.max(0, math.floor(tonumber(daily.rerollsUsed) or 0))
	for _, item in if type(daily.items) == "table" then daily.items else {} do
		if type(item) == "table" then
			local progress = math.max(0, math.floor(tonumber(item.progress) or 0))
			local target = math.max(1, math.floor(tonumber(item.target) or 1))
			local completed = item.completed == true
			local actions: { ActionDefinition } = {}
			if not completed and type(item.id) == "string" then
				table.insert(actions, {
					label = if rerollsUsed >= 1
						then (if self.App.Locale == "ru"
							then "Замена использована"
							else "REMIX USED")
						else (if self.App.Locale == "ru"
							then "Заменить бесплатно"
							else "FREE REMIX"),
					enabled = rerollsUsed < 1 and profile.readOnly ~= true,
					variant = "Secondary",
					callback = function()
						self:_fire("RerollDaily", { questId = item.id }, true)
					end,
				})
			end
			self:_addCard(
				questName(self.App.Locale, item),
				if completed
					then `{target} из {target} / {if self.App.Locale == "ru"
						then "Готово"
						else "Done"}`
					else `{math.min(progress, target)} из {target} / {math.max(
						0,
						math.floor(tonumber(item.reward) or 0)
					)} Искр`,
				actions
			)
		end
	end
	local weekly = if type(quests.weekly) == "table" then quests.weekly else {}
	for _, item in if type(weekly.items) == "table" then weekly.items else {} do
		if type(item) == "table" then
			local progress = math.max(0, math.floor(tonumber(item.progress) or 0))
			local target = math.max(1, math.floor(tonumber(item.target) or 1))
			self:_addCard(
				`{if self.App.Locale == "ru" then "На неделю" else "Weekly"} / {questName(
					self.App.Locale,
					item
				)}`,
				`{math.min(progress, target)} из {target}`,
				nil
			)
		end
	end
end

function MetaPanelController._collectPostcards(
	self: MetaPanelController,
	profile: AnyMap
): { AnyMap }
	local result: { AnyMap } = {}
	local seen: { [string]: boolean } = {}
	for _, source in
		{
			if type(profile.postcards) == "table" then profile.postcards else {},
			if type(self.Meta.recentPostcards) == "table" then self.Meta.recentPostcards else {},
		}
	do
		for _, postcard in source do
			if
				type(postcard) == "table"
				and type(postcard.id) == "string"
				and not seen[postcard.id]
			then
				seen[postcard.id] = true
				table.insert(result, postcard)
			end
		end
	end
	table.sort(result, function(left, right)
		return (tonumber(left.createdAt) or 0) > (tonumber(right.createdAt) or 0)
	end)
	while #result > 12 do
		table.remove(result)
	end
	return result
end

function MetaPanelController._renderPostcards(self: MetaPanelController, profile: AnyMap): ()
	self:_addSection(if self.App.Locale == "ru" then "Карточки" else "Postcards")
	if not isFlagEnabled("Postcards") then
		self:_addCard(
			if self.App.Locale == "ru"
				then "Раздел обновляется"
				else "POSTCARDS ARE PAUSED",
			if self.App.Locale == "ru"
				then "Карточки скоро снова появятся."
				else "Postcards will be back soon.",
			nil
		)
		return
	end
	local postcards = self:_collectPostcards(profile)
	if #postcards == 0 then
		self:_addCard(
			if self.App.Locale == "ru"
				then "Карточек пока нет"
				else "NO POSTCARDS YET",
			if self.App.Locale == "ru"
				then "Сделай снимок после Перекраски — образ сохранится вместе с ним."
				else "Capture the finale to save its style recipe.",
			nil
		)
	end
	for _, postcard in postcards do
		local ownerUserId = math.floor(tonumber(postcard.ownerUserId) or 0)
		local owned = ownerUserId == self.Player.UserId
		local owner = Players:GetPlayerByUserId(ownerUserId)
		local ownerName = if owned
			then (if self.App.Locale == "ru" then "Ваша карточка" else "Your postcard")
			else if owner
				then safeText(owner.DisplayName, 32)
				else (if self.App.Locale == "ru" then "Игрок Roblox" else "Roblox player")
		local confirming = self.PendingPostcardDelete == postcard.id
		local actions: { ActionDefinition } = {
			{
				label = if self.App.Locale == "ru"
					then "Примерить образ"
					else "REMIX LOOK",
				enabled = true,
				variant = "Secondary",
				callback = function()
					self:_fire("PostcardAction", {
						action = "remix",
						postcardId = postcard.id,
					}, true)
				end,
			},
		}
		if owned then
			table.insert(actions, {
				label = if confirming
					then (if self.App.Locale == "ru" then "Да, удалить" else "Confirm")
					else (if self.App.Locale == "ru" then "Удалить" else "Delete"),
				enabled = profile.readOnly ~= true,
				variant = "Danger",
				callback = function()
					if self.PendingPostcardDelete == postcard.id then
						self.PendingPostcardDelete = ""
						self:_fire("PostcardAction", {
							action = "delete",
							postcardId = postcard.id,
						}, true)
					else
						self.PendingPostcardDelete = postcard.id
						self:_render()
					end
				end,
			})
		else
			for _, reaction in
				{
					{ id = "color_story", ru = "Классный цвет", en = "Great color" },
					{
						id = "kind_collaborator",
						ru = "Сильная команда",
						en = "Great team",
					},
				}
			do
				table.insert(actions, {
					label = if self.App.Locale == "ru" then reaction.ru else reaction.en,
					enabled = true,
					variant = "Quiet",
					callback = function()
						self:_fire("PostcardAction", {
							action = "react",
							postcardId = postcard.id,
							reaction = reaction.id,
						}, false)
					end,
				})
			end
		end
		self:_addCard(
			ownerName,
			`{localizedIdentifier(
				self.App.Locale,
				"world",
				postcard.worldId,
				if self.App.Locale == "ru" then "Район" else "District"
			)} / {if self.App.Locale == "ru" then "Финальный кадр" else "Final shot"}`,
			actions
		)
	end
end

function MetaPanelController._renderAtelier(self: MetaPanelController, profile: AnyMap): ()
	self:_addSection(if self.App.Locale == "ru" then "Команда" else "Team")
	if not isFlagEnabled("Crews") then
		self:_addCard(
			if self.App.Locale == "ru"
				then "Командный раздел обновляется"
				else "Team features are being updated",
			if self.App.Locale == "ru"
				then "Скоро здесь снова можно будет собирать команды."
				else "You will be able to create a team again soon.",
			nil
		)
		return
	end
	if self.PendingInvite then
		local invite = self.PendingInvite
		self:_addCard(
			if self.App.Locale == "ru"
				then "Приглашение в команду"
				else "Team invitation",
			if self.App.Locale == "ru"
				then `От {safeText(invite.fromDisplayName, 32)}`
				else `From {safeText(invite.fromDisplayName, 32)}`,
			{
				{
					label = if self.App.Locale == "ru" then "Принять" else "Accept",
					enabled = profile.readOnly ~= true and invite.atelierId ~= "",
					variant = "Primary",
					callback = function()
						self:_fire("AtelierAction", {
							action = "accept",
							atelierId = invite.atelierId,
						}, true)
						self.PendingInvite = nil
						self.PendingInviteBlock = false
					end,
				},
				{
					label = if self.App.Locale == "ru" then "Отклонить" else "Decline",
					enabled = true,
					variant = "Quiet",
					callback = function()
						self:_fire("AtelierAction", { action = "decline" }, false)
						self.PendingInvite = nil
						self.PendingInviteBlock = false
						self:_render()
					end,
				},
				{
					label = if self.PendingInviteBlock
						then (if self.App.Locale == "ru"
							then "Да, заблокировать"
							else "Confirm block")
						else (if self.App.Locale == "ru"
							then "Заблокировать приглашения"
							else "Block invitations"),
					enabled = true,
					variant = "Danger",
					callback = function()
						if self.PendingInviteBlock then
							self:_fire("AtelierAction", { action = "block_inviter" }, false)
							self.PendingInvite = nil
							self.PendingInviteBlock = false
						else
							self.PendingInviteBlock = true
						end
						self:_render()
					end,
				},
			}
		)
	end
	local atelier = if type(profile.atelier) == "table" then profile.atelier else {}
	local atelierId = if type(atelier.id) == "string" then atelier.id else ""
	if atelierId == "" then
		self:_addCard(
			if self.App.Locale == "ru"
				then "Создай команду"
				else "CREATE A CREATIVE CREW",
			if self.App.Locale == "ru"
				then "Приглашай игроков онлайн и накапливай общий недельный вклад."
				else "Invite online players and build weekly contribution together.",
			{
				{
					label = if self.App.Locale == "ru"
						then "Создать команду"
						else "Create team",
					enabled = profile.readOnly ~= true,
					variant = "Primary",
					callback = function()
						self:_fire("AtelierAction", { action = "create" }, true)
					end,
				},
			}
		)
		return
	end
	local roleNames = {
		owner = if self.App.Locale == "ru" then "Лидер" else "Leader",
		member = if self.App.Locale == "ru" then "Участник" else "Member",
	}
	local role = roleNames[string.lower(safeText(atelier.role, 24))]
		or (if self.App.Locale == "ru" then "Участник" else "Member")
	local contribution = math.max(0, math.floor(tonumber(atelier.weeklyContribution) or 0))
	self:_addCard(
		`{if self.App.Locale == "ru" then "Команда" else "Team"} / {role}`,
		`{if self.App.Locale == "ru" then "Вклад за неделю" else "Weekly contribution"}: {contribution}`,
		{
			{
				label = if self.PendingAtelierLeave
					then (if self.App.Locale == "ru" then "Да, выйти" else "CONFIRM LEAVE")
					else (if self.App.Locale == "ru" then "Выйти" else "Leave"),
				enabled = profile.readOnly ~= true,
				variant = "Danger",
				callback = function()
					if self.PendingAtelierLeave then
						self.PendingAtelierLeave = false
						self:_fire("AtelierAction", { action = "leave" }, true)
					else
						self.PendingAtelierLeave = true
						self:_render()
					end
				end,
			},
		}
	)
	for _, candidate in Players:GetPlayers() do
		if candidate ~= self.Player then
			self:_addCard(
				if self.App.Locale == "ru"
					then "Пригласить в команду"
					else "Invite to team",
				safeText(candidate.DisplayName, 32),
				{
					{
						label = if self.App.Locale == "ru"
							then "Пригласить"
							else "SEND INVITE",
						enabled = true,
						variant = "Secondary",
						callback = function()
							self:_fire("AtelierAction", {
								action = "invite",
								targetUserId = candidate.UserId,
							}, false)
							self.App:ShowToast("InviteSent", "Success")
						end,
					},
				}
			)
		end
	end
end

function MetaPanelController._renderNominations(self: MetaPanelController): ()
	local snapshot = self.LastSnapshot
	if
		self.App:GetPhase() ~= "Results"
		or not snapshot
		or snapshot.isParticipant ~= true
		or self.Nominated
	then
		return
	end
	self:_addSection(
		if self.App.Locale == "ru" then "Кого отметить?" else "POSITIVE NOMINATION"
	)
	local participantIds = if type(snapshot.participantUserIds) == "table"
		then snapshot.participantUserIds
		else {}
	for _, userIdValue in participantIds do
		local userId = math.floor(tonumber(userIdValue) or 0)
		local target = Players:GetPlayerByUserId(userId)
		if target and target ~= self.Player then
			self:_addCard(
				safeText(target.DisplayName, 32),
				if self.App.Locale == "ru"
					then "Отметь игрока, который помог общему финалу."
					else "Celebrate a player who made the shared finale better.",
				{
					{
						label = if self.App.Locale == "ru"
							then "Сделал(а) раунд лучше"
							else "Made the round better",
						enabled = true,
						variant = "Primary",
						callback = function()
							self.Nominated = true
							self:_fire("Nominate", { targetUserId = target.UserId }, false)
							self:_render()
						end,
					},
				}
			)
		end
	end
end

function MetaPanelController._render(self: MetaPanelController): ()
	if self.Destroyed then
		return
	end
	self:_clearDynamic()
	local profile = if type(self.Meta.profile) == "table" then self.Meta.profile else {}
	if self.ActiveTab == "looks" then
		self:_renderLookbook(profile)
		self:_renderPostcards(profile)
		self:_renderRemixes(profile)
	elseif self.ActiveTab == "quests" then
		self:_renderQuests(profile)
	elseif self.ActiveTab == "team" then
		self:_renderAtelier(profile)
	else
		self:_renderOverview(profile)
		self:_renderSeason(profile)
		self:_renderNominations()
	end
end

function MetaPanelController._setVisible(self: MetaPanelController, visible: boolean): ()
	self.Overlay.Visible = visible
	if visible then
		self.PendingLookDelete = ""
		self.PendingPostcardDelete = ""
		self.PendingReplayDelete = ""
		self.PendingAtelierLeave = false
		self.PendingInviteBlock = false
		self:_render()
		self:_refresh()
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = self.TabButtons[self.ActiveTab]
		end
	elseif UserInputService.GamepadEnabled then
		GuiService.SelectedObject = self.Button
	end
end

function MetaPanelController._bind(
	self: MetaPanelController,
	openButton: TextButton,
	closeButton: TextButton,
	refreshButton: TextButton
): ()
	table.insert(
		self.Connections,
		openButton.Activated:Connect(function()
			self:_setVisible(true)
		end)
	)
	for _, dismissButton in { closeButton, self.Overlay } do
		table.insert(
			self.Connections,
			dismissButton.Activated:Connect(function()
				self:_setVisible(false)
			end)
		)
	end
	table.insert(
		self.Connections,
		refreshButton.Activated:Connect(function()
			self:_refresh()
		end)
	)
	table.insert(
		self.Connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or not self.Overlay.Visible then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				self:_setVisible(false)
			end
		end)
	)

	local metaUpdate = self.Remotes:GetEvent("MetaUpdate")
	if metaUpdate then
		table.insert(
			self.Connections,
			metaUpdate.OnClientEvent:Connect(function(payload: any)
				if type(payload) == "table" then
					self:_mergeMeta(payload)
				end
			end)
		)
	end
	local postcardUpdate = self.Remotes:GetEvent("PostcardUpdate")
	if postcardUpdate then
		table.insert(
			self.Connections,
			postcardUpdate.OnClientEvent:Connect(function(_payload: any)
				if self.Overlay.Visible then
					task.delay(0.25, function()
						self:_refresh()
					end)
				end
			end)
		)
	end
	table.insert(
		self.Connections,
		self.App:On("SnapshotApplied", function(snapshot: AnyMap)
			self.LastSnapshot = snapshot
			if type(snapshot.profile) == "table" then
				self.Meta.profile = snapshot.profile
			end
			if self.App:GetPhase() ~= "Results" then
				self.Nominated = false
			end
			if self.Overlay.Visible then
				self:_render()
			end
		end)
	)
	table.insert(
		self.Connections,
		self.App:On("ProfileUpdated", function(profile: AnyMap)
			self.Meta.profile = profile
			if self.Overlay.Visible then
				self:_render()
			end
		end)
	)
	for _, key in { "Postcards", "Crews", "LiveOps" } do
		table.insert(
			self.Connections,
			self.Player:GetAttributeChangedSignal("AuraRushFlag_" .. key):Connect(function()
				if self.Overlay.Visible then
					self:_render()
				end
			end)
		)
	end
	local camera = workspace.CurrentCamera
	if camera then
		local function updateButton(): ()
			local compact = camera.ViewportSize.X < 760 or camera.ViewportSize.Y < 560
			local headerCompact = compact or camera.ViewportSize.X < 1180
			self.Button.Position = UDim2.new(1, if headerCompact then -144 else -390, 0.5, 0)
			self.Button.Size = UDim2.fromOffset(if headerCompact then 48 else 108, 48)
			self.Button.Text = if headerCompact then "Моё" else "Мой стиль"
			self.Panel.Size = if compact
				then UDim2.new(1, -12, 1, -12)
				else UDim2.fromScale(0.9, 0.9)
			local titleLabel = self.Panel:FindFirstChild("Title") :: TextLabel?
			local subtitleLabel = self.Panel:FindFirstChild("Subtitle") :: TextLabel?
			local responsiveRefresh = self.Panel:FindFirstChild("Refresh") :: TextButton?
			if titleLabel and subtitleLabel and responsiveRefresh then
				titleLabel.Size = if compact
					then UDim2.new(1, -174, 0, 48)
					else UDim2.new(1, -230, 0, 48)
				titleLabel.TextSize = if compact
					then Theme.TextSizes.Subtitle
					else Theme.TextSizes.Title
				subtitleLabel.Visible = not compact
				responsiveRefresh.Size = UDim2.fromOffset(if compact then 60 else 92, 48)
				responsiveRefresh.Text = if compact then "↻" else "Обновить"
			end
			for _, tab in self.TabButtons do
				tab.TextSize = if compact then 11 else Theme.TextSizes.Caption
			end
		end
		updateButton()
		table.insert(
			self.Connections,
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateButton)
		)
	end
end

function MetaPanelController.Destroy(self: MetaPanelController): ()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self:_clearDynamic()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self.Button:Destroy()
	self.Overlay:Destroy()
end

return MetaPanelController
