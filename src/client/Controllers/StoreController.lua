--!strict

local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AppModule = require(script.Parent.Parent.UI.App)
local Theme = require(script.Parent.Parent.UI.Theme)

local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local Config = require(sharedRoot:WaitForChild("Config"))
local Localization = require(sharedRoot:WaitForChild("Localization"))
local ProductCatalog = require(sharedRoot:WaitForChild("ProductCatalog"))

type App = AppModule.App
type AnyMap = { [string]: any }
type OfferKind = "product" | "pass" | "subscription"
type OfferView = {
	kind: OfferKind,
	definition: AnyMap,
	card: Frame,
	nameLabel: TextLabel,
	descriptionLabel: TextLabel,
	button: TextButton,
	ready: boolean,
	generation: number,
}

local StoreController = {}
StoreController.__index = StoreController

export type StoreController = typeof(setmetatable(
	{} :: {
		App: App,
		Player: Player,
		Locale: string,
		Button: TextButton,
		Overlay: TextButton,
		Panel: Frame,
		Scroll: ScrollingFrame,
		BalanceLabel: TextLabel,
		Offers: { OfferView },
		Connections: { RBXScriptConnection },
		LastPromptAt: number,
		Destroyed: boolean,
	},
	StoreController
))

local function createLabel(
	parent: Instance,
	name: string,
	text: string,
	textSize: number,
	font: Enum.Font?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	Theme.styleText(label, textSize, font)
	label.ZIndex = 83
	label.Parent = parent
	return label
end

local function localText(locale: string, key: string): string
	if type(Localization.GetPlayerText) == "function" then
		return Localization.GetPlayerText(locale, key)
	end
	return Localization.Get(locale, key)
end

local function configured(kind: OfferKind, definition: AnyMap): boolean
	if kind == "subscription" then
		return type(definition.id) == "string" and #definition.id > 0
	end
	return type(definition.id) == "number" and definition.id > 0
end

local function flagEnabled(key: string): boolean
	local remoteValue = Players.LocalPlayer:GetAttribute("AuraRushFlag_" .. key)
	if type(remoteValue) == "boolean" then
		return remoteValue
	end
	return Config.FeatureFlags[key] == true
end

local function featureEnabled(kind: OfferKind): boolean
	if kind == "subscription" then
		return flagEnabled("Purchases") and flagEnabled("Subscriptions")
	elseif kind == "pass" then
		return flagEnabled("Purchases") and flagEnabled("Passes")
	end
	return flagEnabled("Purchases")
end

local function setButtonEnabled(button: TextButton, enabled: boolean): ()
	button.Active = enabled
	button.Selectable = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then Theme.Colors.Lime else Theme.Colors.Surface
	button.TextColor3 = if enabled then Theme.Colors.Background else Theme.Colors.TextDim
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if enabled then Theme.Colors.Lime else Theme.Colors.Stroke
		stroke.Transparency = if enabled then 0.04 else 0.7
	end
end

function StoreController.new(app: App): StoreController
	local player = Players.LocalPlayer
	assert(player ~= nil, "StoreController is client-only")

	local button = Instance.new("TextButton")
	button.Name = "PrismShopButton"
	button.Text = "Магазин"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -510, 0.5, 0)
	button.Size = UDim2.fromOffset(100, 48)
	button.ZIndex = 4
	Theme.styleButton(button, "Quiet")
	button.Parent = app.TopBar

	local overlay = Instance.new("TextButton")
	overlay.Name = "PrismShopOverlay"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Active = true
	overlay.Selectable = false
	overlay.Modal = true
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0.24
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 80
	overlay.Parent = app.OverlayContainer
	app:TrackPrimaryOverlay(overlay)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.86, 0.88)
	panel.ZIndex = 81
	Theme.stylePanel(panel, true)
	Theme.addGradient(panel, {
		Theme.Colors.SurfaceRaised,
		Theme.Colors.Surface,
		Theme.Colors.BackgroundSoft,
	}, 0)
	Theme.addAccentBand(panel, Theme.Colors.Magenta, 8)
	panel.Parent = overlay

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(300, 300)
	sizeConstraint.MaxSize = Vector2.new(860, 700)
	sizeConstraint.Parent = panel

	local title = createLabel(
		panel,
		"Title",
		localText(app.Locale, "shop.title"),
		Theme.TextSizes.Title,
		Theme.Fonts.Display
	)
	title.Position = UDim2.fromOffset(22, 14)
	title.Size = UDim2.new(1, -150, 0, 42)
	title.TextColor3 = Theme.Colors.Text

	local balance =
		createLabel(panel, "Balance", "0 Искр", Theme.TextSizes.Caption, Theme.Fonts.Bold)
	balance.Position = UDim2.fromOffset(24, 54)
	balance.Size = UDim2.new(1, -150, 0, 24)
	balance.TextColor3 = Theme.Colors.Gold

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "X"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 14)
	close.Size = UDim2.fromOffset(48, 48)
	close.TextSize = 28
	close.ZIndex = 84
	Theme.styleButton(close, "Quiet")
	close.Parent = panel

	local promise = createLabel(
		panel,
		"Promise",
		if app.Locale == "ru"
			then "Только косметика. Без случайных наград и усилений."
			else "Cosmetics only. No random rewards or power boosts.",
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	promise.Position = UDim2.fromOffset(22, 82)
	promise.Size = UDim2.new(1, -44, 0, 30)
	promise.TextColor3 = Theme.Colors.Lime

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Offers"
	scroll.Position = UDim2.fromOffset(14, 116)
	scroll.Size = UDim2.new(1, -28, 1, -130)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Theme.Colors.Cyan
	scroll.ZIndex = 82
	scroll.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = scroll

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = scroll

	local self: StoreController = setmetatable({
		App = app,
		Player = player,
		Locale = app.Locale,
		Button = button,
		Overlay = overlay,
		Panel = panel,
		Scroll = scroll,
		BalanceLabel = balance,
		Offers = {},
		Connections = {},
		LastPromptAt = 0,
		Destroyed = false,
	}, StoreController)

	self:_buildOffers()
	self:_refreshAvailability()
	self:_bind(button, close)
	local camera = workspace.CurrentCamera
	self:_updateResponsive(if camera then camera.ViewportSize else Vector2.new(1280, 720))
	return self
end

function StoreController._addSection(self: StoreController, text: string, order: number): ()
	local label = createLabel(
		self.Scroll,
		"Section" .. tostring(order),
		text,
		Theme.TextSizes.Caption,
		Theme.Fonts.Bold
	)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, 30)
	Theme.styleSectionLabel(label, Theme.Colors.Lime)
end

function StoreController._addOffer(
	self: StoreController,
	kind: OfferKind,
	definition: AnyMap,
	order: number
): ()
	local card = Instance.new("Frame")
	card.Name = "Offer_" .. tostring(definition.key)
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, 116)
	card.ZIndex = 82
	Theme.styleCard(card)
	Theme.addAccentBand(
		card,
		if kind == "product"
			then Theme.Colors.Magenta
			else if kind == "pass" then Theme.Colors.Cyan else Theme.Colors.Lime,
		4
	)
	card.Parent = self.Scroll

	local nameLabel = createLabel(
		card,
		"Name",
		localText(self.Locale, tostring(definition.displayNameKey)),
		Theme.TextSizes.Subtitle,
		Theme.Fonts.Bold
	)
	nameLabel.Position = UDim2.fromOffset(18, 10)
	nameLabel.Size = UDim2.new(1, -220, 0, 28)

	local description = createLabel(
		card,
		"Description",
		localText(self.Locale, tostring(definition.descriptionKey)),
		Theme.TextSizes.Caption,
		Theme.Fonts.Regular
	)
	description.Position = UDim2.fromOffset(18, 42)
	description.Size = UDim2.new(1, -220, 0, 58)
	description.TextColor3 = Theme.Colors.TextMuted
	description.TextYAlignment = Enum.TextYAlignment.Top

	local purchase = Instance.new("TextButton")
	purchase.Name = "Purchase"
	purchase.Text = localText(self.Locale, "shop.price_loading")
	purchase.AnchorPoint = Vector2.new(1, 0.5)
	purchase.Position = UDim2.new(1, -18, 0.5, 0)
	purchase.Size = UDim2.fromOffset(172, 54)
	purchase.ZIndex = 84
	Theme.styleButton(purchase, "Primary")
	purchase.Parent = card

	local offer: OfferView = {
		kind = kind,
		definition = definition,
		card = card,
		nameLabel = nameLabel,
		descriptionLabel = description,
		button = purchase,
		ready = false,
		generation = 0,
	}
	table.insert(self.Offers, offer)
	local previous = self.Offers[#self.Offers - 1]
	if previous then
		previous.button.NextSelectionDown = purchase
		purchase.NextSelectionUp = previous.button
	end

	table.insert(
		self.Connections,
		purchase.Activated:Connect(function()
			self:_prompt(offer)
		end)
	)
	self:_loadOffer(offer)
end

function StoreController._buildOffers(self: StoreController): ()
	local russian = Localization.NormalizeLocale(self.Locale) == "ru"
	local order = 0
	self:_addSection(if russian then "Искры и эффекты" else "Sparks & effects", order)
	for _, definition in ProductCatalog.DeveloperProducts do
		-- Gifts stay hidden until a recipient picker is implemented. A purchase
		-- prompt must never open before the recipient is chosen and validated.
		if definition.key ~= "gift_glowdust" then
			order += 1
			self:_addOffer("product", definition :: AnyMap, order)
		end
	end

	order += 1
	self:_addSection(if russian then "Наборы навсегда" else "Permanent packs", order)
	for _, definition in ProductCatalog.Passes do
		order += 1
		self:_addOffer("pass", definition :: AnyMap, order)
	end

	order += 1
	self:_addSection(if russian then "Подписка" else "Subscription", order)
	for _, definition in ProductCatalog.Subscriptions do
		order += 1
		self:_addOffer("subscription", definition :: AnyMap, order)
	end
end

function StoreController._loadOffer(self: StoreController, offer: OfferView): ()
	offer.generation += 1
	local generation = offer.generation
	offer.ready = false
	if not configured(offer.kind, offer.definition) then
		offer.button.Text = if Localization.NormalizeLocale(self.Locale) == "ru"
			then "Скоро"
			else "Coming soon"
		setButtonEnabled(offer.button, false)
		return
	end
	if game.GameId == 0 then
		offer.button.Text = if Localization.NormalizeLocale(self.Locale) == "ru"
			then "После запуска"
			else "After launch"
		setButtonEnabled(offer.button, false)
		return
	end
	if not featureEnabled(offer.kind) then
		offer.button.Text = if Localization.NormalizeLocale(self.Locale) == "ru"
			then "На паузе"
			else "Paused"
		setButtonEnabled(offer.button, false)
		return
	end

	offer.button.Text = localText(self.Locale, "shop.price_loading")
	setButtonEnabled(offer.button, false)
	task.spawn(function()
		local ok, info = pcall(function(): AnyMap
			if offer.kind == "subscription" then
				return MarketplaceService:GetSubscriptionProductInfoAsync(offer.definition.id)
			end
			local infoType = if offer.kind == "pass"
				then Enum.InfoType.GamePass
				else Enum.InfoType.Product
			return MarketplaceService:GetProductInfoAsync(offer.definition.id, infoType)
		end)
		if self.Destroyed or not offer.button.Parent or offer.generation ~= generation then
			return
		end
		if not ok or type(info) ~= "table" then
			offer.button.Text = if Localization.NormalizeLocale(self.Locale) == "ru"
				then "Повторить позже"
				else "Try later"
			setButtonEnabled(offer.button, false)
			return
		end
		if info.IsForSale == false then
			offer.button.Text = if Localization.NormalizeLocale(self.Locale) == "ru"
				then "Скоро"
				else "Coming soon"
			setButtonEnabled(offer.button, false)
			return
		end
		-- A remote kill switch may change while MarketplaceService is yielding.
		-- Re-check immediately before making the prompt button actionable.
		if not featureEnabled(offer.kind) then
			offer.button.Text = if Localization.NormalizeLocale(self.Locale) == "ru"
				then "На паузе"
				else "Paused"
			setButtonEnabled(offer.button, false)
			return
		end

		local priceText: string? = nil
		local priceInRobux = tonumber(info.PriceInRobux)
		if type(info.DisplayPrice) == "string" and #info.DisplayPrice > 0 then
			priceText = info.DisplayPrice
		elseif priceInRobux then
			priceText = `R$ {math.max(0, math.floor(priceInRobux))}`
		end
		if not priceText then
			offer.button.Text = if Localization.NormalizeLocale(self.Locale) == "ru"
				then "Посмотреть"
				else "View item"
		else
			offer.button.Text = priceText
		end
		offer.ready = true
		setButtonEnabled(offer.button, true)
	end)
end

function StoreController._prompt(self: StoreController, offer: OfferView): ()
	if
		not offer.ready
		or not configured(offer.kind, offer.definition)
		or not featureEnabled(offer.kind)
	then
		self.App:ShowToast("StoreNotConfigured", "Warning")
		return
	end
	if self.App.State.ReadOnly == true then
		self.App:ShowToast("StoreReadOnly", "Warning")
		return
	end
	if game.GameId == 0 then
		self.App:ShowToast("StoreNotPublished", "Warning")
		return
	end
	local now = os.clock()
	if now - self.LastPromptAt < 1.5 then
		return
	end
	self.LastPromptAt = now

	local ok = pcall(function()
		if offer.kind == "product" then
			MarketplaceService:PromptProductPurchase(self.Player, offer.definition.id)
		elseif offer.kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(self.Player, offer.definition.id)
		else
			MarketplaceService:PromptSubscriptionPurchase(self.Player, offer.definition.id)
		end
	end)
	if not ok then
		self.App:ShowToast("StorePromptFailed", "Warning")
	end
end

function StoreController._bind(
	self: StoreController,
	openButton: TextButton,
	closeButton: TextButton
): ()
	table.insert(
		self.Connections,
		openButton.Activated:Connect(function()
			self:SetVisible(true)
		end)
	)
	for _, flagName in { "Purchases", "Passes", "Subscriptions" } do
		table.insert(
			self.Connections,
			self.Player:GetAttributeChangedSignal("AuraRushFlag_" .. flagName):Connect(function()
				for _, offer in self.Offers do
					local affected = flagName == "Purchases"
						or (flagName == "Passes" and offer.kind == "pass")
						or (flagName == "Subscriptions" and offer.kind == "subscription")
					if affected and featureEnabled(offer.kind) then
						self:_loadOffer(offer)
					elseif affected then
						offer.generation += 1
						offer.ready = false
						offer.button.Text = if Localization.NormalizeLocale(self.Locale)
								== "ru"
							then "На паузе"
							else "Paused"
						setButtonEnabled(offer.button, false)
					end
				end
				self:_refreshAvailability()
			end)
		)
	end
	table.insert(
		self.Connections,
		closeButton.Activated:Connect(function()
			self:SetVisible(false)
		end)
	)
	table.insert(
		self.Connections,
		self.Overlay.Activated:Connect(function()
			self:SetVisible(false)
		end)
	)
	table.insert(
		self.Connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or not self.Overlay.Visible then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				self:SetVisible(false)
			end
		end)
	)

	table.insert(
		self.Connections,
		self.App:On("SnapshotApplied", function(snapshot: AnyMap)
			if type(snapshot.profile) == "table" then
				self:_applyProfile(snapshot.profile)
			end
		end)
	)
	table.insert(
		self.Connections,
		self.App:On("ProfileUpdated", function(profile: AnyMap)
			self:_applyProfile(profile)
		end)
	)

	local camera = workspace.CurrentCamera
	if camera then
		table.insert(
			self.Connections,
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:_updateResponsive(camera.ViewportSize)
			end)
		)
	end
end

function StoreController._refreshAvailability(self: StoreController): ()
	local available = false
	for _, offer in self.Offers do
		if configured(offer.kind, offer.definition) and featureEnabled(offer.kind) then
			available = true
			break
		end
	end
	self.Button.Visible = available
	if not available then
		self:SetVisible(false)
	end
end

function StoreController._applyProfile(self: StoreController, profile: AnyMap): ()
	local amount = math.max(0, math.floor(tonumber(profile.glowDust) or 0))
	self.BalanceLabel.Text = `{amount} {if Localization.NormalizeLocale(self.Locale) == "ru"
		then "Искр"
		else "Sparks"}`
end

function StoreController._updateResponsive(self: StoreController, viewport: Vector2): ()
	local compact = viewport.X < 760 or viewport.Y < 560
	local headerCompact = compact or viewport.X < 1180
	self.Button.Text = if headerCompact then "М" else "Магазин"
	self.Button.Position = UDim2.new(1, if headerCompact then -202 else -510, 0.5, 0)
	self.Button.Size = UDim2.fromOffset(if headerCompact then 48 else 100, 48)
	self.Panel.Size = if compact then UDim2.new(1, -12, 1, -12) else UDim2.fromScale(0.86, 0.88)

	for _, offer in self.Offers do
		if compact then
			offer.card.Size = UDim2.new(1, 0, 0, 150)
			offer.nameLabel.Position = UDim2.fromOffset(14, 8)
			offer.nameLabel.Size = UDim2.new(1, -28, 0, 26)
			offer.nameLabel.TextSize = Theme.TextSizes.Body
			offer.descriptionLabel.Position = UDim2.fromOffset(14, 35)
			offer.descriptionLabel.Size = UDim2.new(1, -28, 0, 50)
			offer.button.AnchorPoint = Vector2.zero
			offer.button.Position = UDim2.fromOffset(12, 94)
			offer.button.Size = UDim2.new(1, -24, 0, 48)
		else
			offer.card.Size = UDim2.new(1, 0, 0, 116)
			offer.nameLabel.Position = UDim2.fromOffset(18, 10)
			offer.nameLabel.Size = UDim2.new(1, -220, 0, 28)
			offer.nameLabel.TextSize = Theme.TextSizes.Subtitle
			offer.descriptionLabel.Position = UDim2.fromOffset(18, 42)
			offer.descriptionLabel.Size = UDim2.new(1, -220, 0, 58)
			offer.button.AnchorPoint = Vector2.new(1, 0.5)
			offer.button.Position = UDim2.new(1, -18, 0.5, 0)
			offer.button.Size = UDim2.fromOffset(172, 54)
		end
	end
end

function StoreController.SetVisible(self: StoreController, visible: boolean): ()
	self.Overlay.Visible = visible
	if visible and UserInputService.GamepadEnabled then
		for _, offer in self.Offers do
			if offer.button.Selectable then
				GuiService.SelectedObject = offer.button
				break
			end
		end
	end
end

function StoreController.Destroy(self: StoreController): ()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Button:Destroy()
	self.Overlay:Destroy()
end

return StoreController
