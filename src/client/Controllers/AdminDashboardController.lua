--!strict

local UserInputService = game:GetService("UserInputService")

local AppModule = require(script.Parent.Parent.UI.App)
local StyleOS = require(script.Parent.Parent.UI.StyleOS)
local Theme = require(script.Parent.Parent.UI.Theme)
local RemoteRegistryModule = require(script.Parent.RemoteRegistry)

type App = AppModule.App
type RemoteRegistry = RemoteRegistryModule.RemoteRegistry
type AnyMap = { [string]: any }

local AdminDashboardController = {}
AdminDashboardController.__index = AdminDashboardController

export type AdminDashboardController = typeof(setmetatable(
	{} :: {
		App: App,
		Remotes: RemoteRegistry,
		PlayerGui: PlayerGui,
		Connections: { RBXScriptConnection },
		ScreenGui: ScreenGui?,
		OpenButton: TextButton?,
		Overlay: TextButton?,
		Panel: Frame?,
		Summary: TextLabel?,
		Audit: TextLabel?,
		AnnouncementButtons: { TextButton },
		Snapshot: AnyMap?,
		Refreshing: boolean,
		Destroyed: boolean,
	},
	AdminDashboardController
))

local function createLabel(parent: Instance, name: string, text: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.ZIndex = 212
	Theme.styleText(label, size, Theme.Fonts.Regular)
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
	button.ZIndex = 213
	Theme.styleButton(button, variant)
	StyleOS.makePressable(button, text)
	button.Parent = parent
	return button
end

local function number(value: any): number
	return math.max(0, math.floor(tonumber(value) or 0))
end

local function text(value: any, fallback: string): string
	return if type(value) == "string" and value ~= "" then value else fallback
end

local function hasPermission(snapshot: AnyMap?, permission: string): boolean
	if not snapshot or type(snapshot.permissions) ~= "table" then
		return false
	end
	for _, value in snapshot.permissions do
		if value == permission then
			return true
		end
	end
	return false
end

function AdminDashboardController.new(
	app: App,
	remotes: RemoteRegistry,
	playerGui: PlayerGui
): AdminDashboardController
	local self: AdminDashboardController = setmetatable({
		App = app,
		Remotes = remotes,
		PlayerGui = playerGui,
		Connections = {},
		ScreenGui = nil,
		OpenButton = nil,
		Overlay = nil,
		Panel = nil,
		Summary = nil,
		Audit = nil,
		AnnouncementButtons = {},
		Snapshot = nil,
		Refreshing = false,
		Destroyed = false,
	}, AdminDashboardController)

	local update = remotes:GetEvent("AdminUpdate")
	if update then
		table.insert(
			self.Connections,
			update.OnClientEvent:Connect(function(payload: any)
				if type(payload) == "table" and type(payload.data) == "table" then
					self:_applySnapshot(payload.data)
					if payload.result == "ok" then
						self.App:ShowToast("toast.admin_action_done", "Success")
					elseif type(payload.result) == "string" and payload.result ~= "" then
						self.App:ShowToast("toast.admin_action_blocked", "Warning")
					end
				end
			end)
		)
	end
	task.defer(function()
		self:Refresh()
	end)
	return self
end

function AdminDashboardController:_build(): ()
	if self.ScreenGui or self.Destroyed then
		return
	end
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AuraRushAdminDashboard"
	screenGui.DisplayOrder = 210
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = self.PlayerGui
	self.ScreenGui = screenGui

	local openButton = createButton(screenGui, "Open", "OPS", "Quiet")
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(1, -16, 0, 72)
	openButton.Size = UDim2.fromOffset(58, 48)
	openButton.TextSize = 13
	openButton.ZIndex = 211
	self.OpenButton = openButton

	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Visible = false
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 211
	overlay.Parent = screenGui
	self.Overlay = overlay
	self.App:TrackPrimaryOverlay(overlay)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -24, 1, -32)
	panel.BackgroundColor3 = Theme.Colors.BackgroundSoft
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 212
	Theme.addCorner(panel, Theme.Radius.Large)
	Theme.addStroke(panel, Theme.Colors.Lime, 0.38)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(286, 280)
	constraint.MaxSize = Vector2.new(560, 660)
	constraint.Parent = panel
	panel.Parent = screenGui
	self.Panel = panel

	local header = createLabel(
		panel,
		"Header",
		"ОПЕРАЦИОННЫЙ ЦЕНТР",
		Theme.TextSizes.Subtitle
	)
	header.Font = Theme.Fonts.Bold
	header.Position = UDim2.fromOffset(18, 14)
	header.Size = UDim2.new(1, -128, 0, 32)
	header.TextColor3 = Theme.Colors.Lime

	local close = createButton(panel, "Close", "Закрыть", "Quiet")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 12)
	close.Size = UDim2.fromOffset(88, 36)

	-- The operation view is deliberately scrollable. On a landscape phone the
	-- health, audit and action rows must never overlap or fall below the safe
	-- area; a compact panel simply scrolls its content instead.
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(14, 58)
	content.Size = UDim2.new(1, -28, 1, -72)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.CanvasSize = UDim2.fromOffset(0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = Theme.Colors.Lime
	content.ZIndex = 212
	content.Parent = panel
	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingRight = UDim.new(0, 6)
	contentPadding.PaddingBottom = UDim.new(0, 4)
	contentPadding.Parent = content
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, 10)
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = content

	local summary = createLabel(
		content,
		"Summary",
		"Собираем состояние сервера…",
		Theme.TextSizes.Body
	)
	summary.LayoutOrder = 1
	summary.Size = UDim2.new(1, -8, 0, 142)
	summary.TextColor3 = Theme.Colors.Text
	summary.TextYAlignment = Enum.TextYAlignment.Top
	self.Summary = summary

	local audit = createLabel(
		content,
		"Audit",
		"Последние действия: нет данных",
		Theme.TextSizes.Caption
	)
	audit.LayoutOrder = 2
	audit.Size = UDim2.new(1, -8, 0, 84)
	audit.TextColor3 = Theme.Colors.TextMuted
	audit.TextYAlignment = Enum.TextYAlignment.Top
	self.Audit = audit

	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.LayoutOrder = 3
	actions.Size = UDim2.new(1, -8, 0, 126)
	actions.BackgroundTransparency = 1
	actions.ZIndex = 212
	actions.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = actions

	local refresh =
		createButton(actions, "Refresh", "Обновить состояние", "Secondary")
	refresh.Size = UDim2.new(1, 0, 0, 36)
	local maintenance =
		createButton(actions, "Maintenance", "Сообщить: скоро перерыв", "Quiet")
	maintenance.Size = UDim2.new(1, 0, 0, 36)
	maintenance:SetAttribute("TemplateId", "maintenance_soon")
	local updateReady = createButton(
		actions,
		"UpdateReady",
		"Сообщить: обновление готово",
		"Quiet"
	)
	updateReady.Size = UDim2.new(1, 0, 0, 36)
	updateReady:SetAttribute("TemplateId", "update_ready")
	self.AnnouncementButtons = { maintenance, updateReady }

	table.insert(
		self.Connections,
		openButton.Activated:Connect(function()
			self:SetVisible(true)
			self:Refresh()
		end)
	)
	table.insert(
		self.Connections,
		close.Activated:Connect(function()
			self:SetVisible(false)
		end)
	)
	table.insert(
		self.Connections,
		overlay.Activated:Connect(function()
			self:SetVisible(false)
		end)
	)
	table.insert(
		self.Connections,
		refresh.Activated:Connect(function()
			self:Refresh()
		end)
	)
	for _, button in self.AnnouncementButtons do
		table.insert(
			self.Connections,
			button.Activated:Connect(function()
				self:_broadcast(text(button:GetAttribute("TemplateId"), ""))
			end)
		)
	end
	table.insert(
		self.Connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or input.KeyCode ~= Enum.KeyCode.F8 then
				return
			end
			self:SetVisible(not (self.Panel and self.Panel.Visible == true))
		end)
	)
end

function AdminDashboardController:_render(): ()
	local snapshot = self.Snapshot
	if not snapshot or not self.Summary then
		return
	end
	local server = if type(snapshot.server) == "table" then snapshot.server else {}
	local round = if type(snapshot.round) == "table" then snapshot.round else {}
	local network = if type(snapshot.network) == "table" then snapshot.network else {}
	local persistence = if type(snapshot.persistence) == "table" then snapshot.persistence else {}
	local performance = if type(snapshot.performance) == "table" then snapshot.performance else {}
	self.Summary.Text = string.format(
		"Роль: %s\nСервер: %s · %s\nИгроки: %d/%d · раунд: %s\nСеть: %d принято · %d отклонено\nДанные: %d запросов · %d повторов · %d ошибок\nHeartbeat p95: %.1f мс · uptime: %d с",
		text(snapshot.roleLabel, "Сотрудник"),
		text(server.state, "unknown"),
		text(server.step, "unknown"),
		number(server.players),
		number(server.maximumPlayers),
		text(round.state, "unknown"),
		number(network.accepted),
		number(network.rejected),
		number(persistence.requests),
		number(persistence.retries),
		number(persistence.failures),
		tonumber(performance.heartbeatP95Milliseconds) or 0,
		number(server.uptimeSeconds)
	)

	if self.Audit then
		local entries = if type(snapshot.audit) == "table" then snapshot.audit else {}
		local lines = { "Последние действия:" }
		for index = math.max(1, #entries - 2), #entries do
			local entry = entries[index]
			if type(entry) == "table" then
				table.insert(
					lines,
					string.format(
						"• %s — %s (%s)",
						text(entry.actor, "сотрудник"),
						text(entry.action, "действие"),
						text(entry.result, "ok")
					)
				)
			end
		end
		if #lines == 1 then
			table.insert(lines, "• Пока нет действий в этой сессии")
		end
		self.Audit.Text = table.concat(lines, "\n")
	end
	local canBroadcast = hasPermission(snapshot, "broadcast_announcement")
	for _, button in self.AnnouncementButtons do
		button.Visible = canBroadcast
		button.Active = canBroadcast
		button.Selectable = canBroadcast
	end
end

function AdminDashboardController:_applySnapshot(snapshot: AnyMap): ()
	if self.Destroyed or snapshot.authorized ~= true then
		if self.ScreenGui then
			self.ScreenGui:Destroy()
			self.ScreenGui = nil
		end
		return
	end
	self.Snapshot = snapshot
	self:_build()
	self:_render()
end

function AdminDashboardController:Refresh(): ()
	if self.Destroyed or self.Refreshing then
		return
	end
	local request = self.Remotes:GetFunction("RequestAdminSnapshot")
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
			self:_applySnapshot(result)
		end
	end)
end

function AdminDashboardController:_broadcast(templateId: string): ()
	if
		self.Destroyed
		or templateId == ""
		or not hasPermission(self.Snapshot, "broadcast_announcement")
	then
		return
	end
	local remote = self.Remotes:GetEvent("AdminAction")
	if not remote then
		return
	end
	remote:FireServer({
		action = "BroadcastTemplate",
		templateId = templateId,
		confirmed = true,
	})
end

function AdminDashboardController.SetVisible(self: AdminDashboardController, visible: boolean): ()
	if self.Destroyed or not self.Overlay or not self.Panel then
		return
	end
	self.Overlay.Visible = visible
	self.Panel.Visible = visible
end

function AdminDashboardController.Destroy(self: AdminDashboardController): ()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end
	table.clear(self.AnnouncementButtons)
	self.Snapshot = nil
end

return AdminDashboardController
