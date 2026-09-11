--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AppModule = require(script.Parent.Parent.UI.App)
local Theme = require(script.Parent.Parent.UI.Theme)
local RemoteRegistryModule = require(script.Parent.RemoteRegistry)

local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local Localization = require(sharedRoot:WaitForChild("Localization"))

type App = AppModule.App
type RemoteRegistry = RemoteRegistryModule.RemoteRegistry
type AnyMap = { [string]: any }

local FirstMiracleController = {}
FirstMiracleController.__index = FirstMiracleController

export type FirstMiracleController = typeof(setmetatable(
	{} :: {
		App: App,
		Remotes: RemoteRegistry,
		Player: Player,
		Overlay: TextButton,
		Panel: Frame,
		PanelConstraint: UISizeConstraint,
		PanelGradient: UIGradient,
		Title: TextLabel,
		Intro: TextLabel,
		Progress: TextLabel,
		StepSegments: { Frame },
		Timer: TextLabel,
		PaletteRow: Frame,
		PaletteButtons: { TextButton },
		ActionButton: TextButton,
		Reward: TextLabel,
		SkipButton: TextButton,
		BloomCanvas: Frame,
		Connections: { RBXScriptConnection },
		State: AnyMap?,
		Requested: boolean,
		Destroyed: boolean,
		LastActionAt: number,
		LastSpatialAttemptAt: number,
		SpatialActionIndex: number,
		SpatialCheckpointPosition: Vector3?,
		SpatialCheckpointLook: Vector3?,
		SpatialCheckpointY: number,
		SpatialMarker: BasePart?,
		BloomToken: number,
		CompletionToken: number,
	},
	FirstMiracleController
))

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
	label.ZIndex = zIndex or 123
	Theme.styleText(label, size, font)
	label.TextXAlignment = Enum.TextXAlignment.Center
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
	button.ZIndex = zIndex or 124
	button.TextWrapped = true
	Theme.styleButton(button, variant)
	button.Parent = parent
	return button
end

local function parseColor(value: any, fallback: Color3): Color3
	if type(value) ~= "string" then
		return fallback
	end
	local ok, color = pcall(Color3.fromHex, string.gsub(value, "#", ""))
	return if ok then color else fallback
end

local function paletteColors(choice: AnyMap?): { Color3 }
	local source = if choice and type(choice.colors) == "table" then choice.colors else {}
	return {
		parseColor(source[1], Theme.Colors.Magenta),
		parseColor(source[2], Theme.Colors.Violet),
		parseColor(source[3], Theme.Colors.Cyan),
	}
end

local function setEnabled(button: TextButton, enabled: boolean): ()
	button.Active = enabled
	button.Selectable = enabled
	button.AutoButtonColor = enabled
	button.TextTransparency = if enabled then 0 else 0.38
end

local function localText(locale: string, key: any, args: AnyMap?): string
	if type(key) ~= "string" then
		return ""
	end
	if type(Localization.GetPlayerText) == "function" then
		return Localization.GetPlayerText(locale, key, args)
	end
	return Localization.Get(locale, key, args)
end

local function spatialSnapshot(player: Player): AnyMap?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not root or not root:IsA("BasePart") or not humanoid then
		return nil
	end
	return {
		position = root.Position,
		look = root.CFrame.LookVector,
		verticalSpeed = root.AssemblyLinearVelocity.Y,
		humanoidState = humanoid:GetState(),
	}
end

local function planarDistance(first: Vector3, second: Vector3): number
	local delta = first - second
	return Vector2.new(delta.X, delta.Z).Magnitude
end

local function lookTurnDegrees(first: Vector3, second: Vector3): number
	local firstPlanar = Vector3.new(first.X, 0, first.Z)
	local secondPlanar = Vector3.new(second.X, 0, second.Z)
	if firstPlanar.Magnitude < 0.001 or secondPlanar.Magnitude < 0.001 then
		return 0
	end
	return math.deg(math.acos(math.clamp(firstPlanar.Unit:Dot(secondPlanar.Unit), -1, 1)))
end

function FirstMiracleController.new(app: App, remotes: RemoteRegistry): FirstMiracleController
	local player = Players.LocalPlayer
	local overlay = Instance.new("TextButton")
	overlay.Name = "FirstMiracleOverlay"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Active = true
	overlay.Selectable = false
	overlay.Modal = true
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.Colors.Black
	overlay.BackgroundTransparency = 0.34
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 120
	overlay.Parent = app.OverlayContainer
	app:TrackPrimaryOverlay(overlay)

	local panel = Instance.new("Frame")
	panel.Name = "MiracleCard"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -18)
	panel.Size = UDim2.new(0.92, 0, 0, 380)
	panel.ZIndex = 121
	panel.ClipsDescendants = true
	Theme.stylePanel(panel, true)
	local panelGradient = Theme.addGradient(
		panel,
		{ Theme.Colors.SurfaceRaised, Theme.Colors.Surface, Theme.Colors.BackgroundSoft },
		0
	)
	panelGradient.Name = "MiracleGradient"
	Theme.addAccentBand(panel, Theme.Colors.Lime, 8)
	panel.Parent = overlay

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 360)
	constraint.MaxSize = Vector2.new(720, 380)
	constraint.Parent = panel

	local bloomCanvas = Instance.new("Frame")
	bloomCanvas.Name = "BloomCanvas"
	bloomCanvas.Size = UDim2.fromScale(1, 1)
	bloomCanvas.BackgroundTransparency = 1
	bloomCanvas.ZIndex = 122
	bloomCanvas.ClipsDescendants = true
	bloomCanvas.Parent = panel

	local title = createLabel(
		panel,
		"Title",
		localText(app.Locale, "first_miracle.title", nil),
		Theme.TextSizes.Title,
		Theme.Fonts.Display,
		124
	)
	title.Position = UDim2.fromScale(0.06, 0.05)
	title.Size = UDim2.new(0.72, 0, 0, 44)
	title.TextColor3 = Theme.Colors.Text
	title.TextXAlignment = Enum.TextXAlignment.Left

	local timer =
		createLabel(panel, "Timer", "1:30", Theme.TextSizes.Caption, Theme.Fonts.Bold, 125)
	timer.AnchorPoint = Vector2.new(1, 0)
	timer.Position = UDim2.fromScale(0.95, 0.025)
	timer.Size = UDim2.fromOffset(64, 28)
	timer.TextColor3 = Theme.Colors.Lime

	local intro = createLabel(
		panel,
		"Intro",
		localText(app.Locale, "first_miracle.intro", nil),
		Theme.TextSizes.Body,
		Theme.Fonts.Medium,
		124
	)
	intro.Position = UDim2.fromScale(0.08, 0.17)
	intro.Size = UDim2.new(0.84, 0, 0, 46)
	intro.TextColor3 = Theme.Colors.TextMuted
	intro.TextXAlignment = Enum.TextXAlignment.Left

	local progress =
		createLabel(panel, "Progress", "", Theme.TextSizes.Subtitle, Theme.Fonts.Bold, 124)
	progress.Position = UDim2.fromScale(0.08, 0.3)
	progress.Size = UDim2.new(0.84, 0, 0, 30)
	progress.TextColor3 = Theme.Colors.Lime
	progress.TextXAlignment = Enum.TextXAlignment.Left

	local stepRail = Instance.new("Frame")
	stepRail.Name = "StepRail"
	stepRail.Position = UDim2.fromScale(0.08, 0.39)
	stepRail.Size = UDim2.new(0.84, 0, 0, 24)
	stepRail.BackgroundTransparency = 1
	stepRail.ZIndex = 124
	stepRail.Parent = panel
	local stepLayout = Instance.new("UIListLayout")
	stepLayout.FillDirection = Enum.FillDirection.Horizontal
	stepLayout.Padding = UDim.new(0, Theme.Spacing.S)
	stepLayout.Parent = stepRail
	local stepSegments: { Frame } = {}
	for index, labelText in { "1  Цвет", "2  Жест", "3  Кадр" } do
		local segment = Instance.new("Frame")
		segment.Name = `Step{index}`
		segment.LayoutOrder = index
		segment.Size = UDim2.new(1 / 3, -6, 1, 0)
		segment.BackgroundColor3 = Theme.Colors.BackgroundSoft
		segment.BorderSizePixel = 0
		segment.ZIndex = 124
		Theme.addCorner(segment, Theme.Radius.Small)
		segment.Parent = stepRail
		local segmentLabel =
			createLabel(segment, "Label", labelText, Theme.TextSizes.Caption, Theme.Fonts.Bold, 125)
		segmentLabel.Size = UDim2.fromScale(1, 1)
		table.insert(stepSegments, segment)
	end

	local paletteRow = Instance.new("Frame")
	paletteRow.Name = "PaletteChoices"
	paletteRow.Position = UDim2.fromScale(0.06, 0.46)
	paletteRow.Size = UDim2.new(0.88, 0, 0, 86)
	paletteRow.BackgroundTransparency = 1
	paletteRow.ZIndex = 124
	paletteRow.Parent = panel
	local paletteLayout = Instance.new("UIListLayout")
	paletteLayout.FillDirection = Enum.FillDirection.Horizontal
	paletteLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	paletteLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	paletteLayout.Padding = UDim.new(0, Theme.Spacing.S)
	paletteLayout.Parent = paletteRow

	local paletteButtons: { TextButton } = {}
	for index = 1, 3 do
		local button =
			createButton(paletteRow, `Palette{index}`, "ПАЛИТРА", "Secondary", 125)
		button.Size = UDim2.new(1 / 3, -6, 1, 0)
		button.LayoutOrder = index
		table.insert(paletteButtons, button)
	end
	for index, button in paletteButtons do
		button.NextSelectionLeft = paletteButtons[math.max(1, index - 1)]
		button.NextSelectionRight = paletteButtons[math.min(#paletteButtons, index + 1)]
	end

	local actionButton =
		createButton(panel, "CreativeAction", "Сделать жест", "Primary", 125)
	actionButton.AnchorPoint = Vector2.new(0.5, 0)
	actionButton.Position = UDim2.fromScale(0.5, 0.43)
	actionButton.Size = UDim2.new(0.78, 0, 0, 68)
	actionButton.Visible = false

	local reward = createLabel(panel, "Reward", "", Theme.TextSizes.Body, Theme.Fonts.Bold, 124)
	reward.Position = UDim2.fromScale(0.08, 0.71)
	reward.Size = UDim2.new(0.84, 0, 0, 36)
	reward.TextColor3 = Theme.Colors.Lime

	local skipButton = createButton(
		panel,
		"Skip",
		if app.Locale == "ru"
			then "Сразу увидеть результат"
			else "SKIP TO BLOOM",
		"Quiet",
		125
	)
	skipButton.AnchorPoint = Vector2.new(0.5, 1)
	skipButton.Position = UDim2.fromScale(0.5, 0.96)
	skipButton.Size = UDim2.new(0.62, 0, 0, 44)
	actionButton.NextSelectionDown = skipButton
	for _, paletteButton in paletteButtons do
		paletteButton.NextSelectionDown = skipButton
	end

	local self: FirstMiracleController = setmetatable({
		App = app,
		Remotes = remotes,
		Player = player,
		Overlay = overlay,
		Panel = panel,
		PanelConstraint = constraint,
		PanelGradient = panelGradient,
		Title = title,
		Intro = intro,
		Progress = progress,
		StepSegments = stepSegments,
		Timer = timer,
		PaletteRow = paletteRow,
		PaletteButtons = paletteButtons,
		ActionButton = actionButton,
		Reward = reward,
		SkipButton = skipButton,
		BloomCanvas = bloomCanvas,
		Connections = {},
		State = nil,
		Requested = false,
		Destroyed = false,
		LastActionAt = 0,
		LastSpatialAttemptAt = 0,
		SpatialActionIndex = -1,
		SpatialCheckpointPosition = nil,
		SpatialCheckpointLook = nil,
		SpatialCheckpointY = 0,
		SpatialMarker = nil,
		BloomToken = 0,
		CompletionToken = 0,
	}, FirstMiracleController)

	self:_bind()
	task.defer(function()
		self:_requestIfReady()
	end)
	return self
end

function FirstMiracleController._fire(self: FirstMiracleController, payload: AnyMap): ()
	local remote = self.Remotes:GetEvent("FirstMiracleAction")
	if remote then
		remote:FireServer(payload)
	else
		self.App:ShowToast("ConnectionUnavailable", "Warning")
	end
end

function FirstMiracleController._setSpatialMode(self: FirstMiracleController, enabled: boolean): ()
	self.Overlay.Modal = not enabled
	self.Overlay.Active = not enabled
	self.Overlay.BackgroundTransparency = if enabled then 0.9 else 0.34
	self.Panel.AnchorPoint = if enabled then Vector2.new(0.5, 0) else Vector2.new(0.5, 1)
	self.Panel.Position = if enabled then UDim2.new(0.5, 0, 0, 18) else UDim2.new(0.5, 0, 1, -18)
	self.Panel.Size = if enabled then UDim2.new(0.9, 0, 0, 284) else UDim2.new(0.92, 0, 0, 380)
	self.PanelConstraint.MinSize = if enabled then Vector2.new(300, 284) else Vector2.new(320, 360)
	self.PanelConstraint.MaxSize = if enabled then Vector2.new(620, 284) else Vector2.new(720, 380)
	self.Title.Position = if enabled then UDim2.new(0.06, 0, 0, 12) else UDim2.fromScale(0.06, 0.05)
	self.Title.Size = UDim2.new(0.72, 0, 0, if enabled then 34 else 44)
	self.Intro.Position = if enabled then UDim2.new(0.06, 0, 0, 50) else UDim2.fromScale(0.08, 0.17)
	self.Intro.Size = UDim2.new(if enabled then 0.88 else 0.84, 0, 0, if enabled then 38 else 46)
	self.Progress.Position = if enabled
		then UDim2.new(0.06, 0, 0, 96)
		else UDim2.fromScale(0.08, 0.3)
	self.Progress.Size = UDim2.new(if enabled then 0.88 else 0.84, 0, 0, if enabled then 28 else 30)
	local stepRail = self.Panel:FindFirstChild("StepRail") :: Frame?
	if stepRail then
		stepRail.Position = if enabled
			then UDim2.new(0.06, 0, 0, 132)
			else UDim2.fromScale(0.08, 0.39)
		stepRail.Size = UDim2.new(if enabled then 0.88 else 0.84, 0, 0, if enabled then 22 else 24)
	end
	self.ActionButton.Position = if enabled
		then UDim2.new(0.5, 0, 0, 166)
		else UDim2.fromScale(0.5, 0.43)
	self.ActionButton.Size =
		UDim2.new(if enabled then 0.72 else 0.78, 0, 0, if enabled then 48 else 68)
	self.SkipButton.Position = if enabled
		then UDim2.new(0.5, 0, 1, -12)
		else UDim2.fromScale(0.5, 0.96)
	self.SkipButton.Size = UDim2.new(if enabled then 0.58 else 0.62, 0, 0, 48)
	self.Reward.Visible = not enabled
end

function FirstMiracleController._captureSpatialCheckpoint(
	self: FirstMiracleController,
	actionIndex: number
): ()
	local snapshot = spatialSnapshot(self.Player)
	self.SpatialActionIndex = actionIndex
	self.SpatialCheckpointPosition = if snapshot then snapshot.position else nil
	self.SpatialCheckpointLook = if snapshot then snapshot.look else nil
	self.SpatialCheckpointY = if snapshot then snapshot.position.Y else 0
end

function FirstMiracleController._setSpatialMarker(
	self: FirstMiracleController,
	targetPosition: any
): ()
	if typeof(targetPosition) ~= "Vector3" then
		if self.SpatialMarker then
			self.SpatialMarker:Destroy()
			self.SpatialMarker = nil
		end
		return
	end
	local marker = self.SpatialMarker
	if not marker then
		local part = Instance.new("Part")
		part.Name = "FirstMiracleWaypoint"
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Color = Theme.Colors.Lime
		part.Size = Vector3.new(1.4, 1.4, 1.4)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Transparency = 0.16
		part.Parent = Workspace
		marker = part
		self.SpatialMarker = part
	end
	marker.Position = targetPosition + Vector3.new(0, 1.6, 0)
end

function FirstMiracleController._trySpatialAction(self: FirstMiracleController, force: boolean): ()
	local state = self.State
	if not state or tostring(state.status or "") ~= "Actions" then
		return
	end
	local spatial = if type(state.spatial) == "table" then state.spatial else nil
	if not spatial or spatial.enabled ~= true then
		return
	end
	local now = os.clock()
	if now - self.LastSpatialAttemptAt < 0.45 then
		return
	end
	local completed = math.max(0, math.floor(tonumber(state.actionIndex) or 0))
	if self.SpatialActionIndex ~= completed then
		self:_captureSpatialCheckpoint(completed)
	end
	local snapshot = spatialSnapshot(self.Player)
	local checkpointPosition = self.SpatialCheckpointPosition
	local checkpointLook = self.SpatialCheckpointLook
	if not snapshot or not checkpointPosition or not checkpointLook then
		return
	end

	local distance = planarDistance(snapshot.position, checkpointPosition)
	local height = snapshot.position.Y - self.SpatialCheckpointY
	local rotation = lookTurnDegrees(checkpointLook, snapshot.look)
	local ready = false
	if spatial.check == "world_distance" then
		ready = distance >= (tonumber(spatial.distance) or 6)
	elseif spatial.check == "airborne_pulse" then
		ready = height >= (tonumber(spatial.height) or 1.5)
			or math.abs(snapshot.verticalSpeed) >= (tonumber(spatial.verticalSpeed) or 3)
			or snapshot.humanoidState == Enum.HumanoidStateType.Jumping
			or snapshot.humanoidState == Enum.HumanoidStateType.Freefall
	elseif spatial.check == "move_and_turn" then
		ready = distance >= (tonumber(spatial.distance) or 4)
			and rotation >= (tonumber(spatial.turnDegrees) or 35)
	end

	if ready or force then
		local actions = state.actions
		local action = if type(actions) == "table" then actions[completed + 1] else nil
		if type(action) == "table" and type(action.id) == "string" then
			self.LastSpatialAttemptAt = now
			self.LastActionAt = now
			self:_fire({ action = "PerformAction", actionId = action.id, mode = "spatial" })
		end
	end
end

function FirstMiracleController._requestIfReady(self: FirstMiracleController): ()
	if
		self.Destroyed
		or self.Requested
		or self.Player:GetAttribute("AuraRushOnboarded") ~= true
	then
		return
	end
	if self.Player:GetAttribute("AuraRushFlag_FirstMiracle") == false then
		self.Overlay.Visible = false
		return
	end
	local request = self.Remotes:GetFunction("RequestFirstMiracle")
	if not request then
		return
	end
	self.Requested = true
	task.spawn(function()
		local ok, result = pcall(function()
			return request:InvokeServer({})
		end)
		if self.Destroyed then
			return
		end
		if not ok or type(result) ~= "table" then
			self.Requested = false
			task.delay(2.5, function()
				self:_requestIfReady()
			end)
			return
		end
		self:_apply(result)
	end)
end

function FirstMiracleController._bind(self: FirstMiracleController): ()
	for index, button in self.PaletteButtons do
		table.insert(
			self.Connections,
			button.Activated:Connect(function()
				local state = self.State
				local choice = if state and type(state.choices) == "table"
					then state.choices[index]
					else nil
				if type(choice) == "table" and type(choice.id) == "string" then
					setEnabled(button, false)
					self:_fire({ action = "ChoosePalette", paletteId = choice.id })
				end
			end)
		)
	end
	table.insert(
		self.Connections,
		self.ActionButton.Activated:Connect(function()
			local state = self.State
			if not state or type(state.actions) ~= "table" then
				return
			end
			if type(state.spatial) == "table" and state.spatial.enabled == true then
				self:_trySpatialAction(true)
				return
			end
			if os.clock() - self.LastActionAt < 0.16 then
				return
			end
			local nextIndex = math.max(0, math.floor(tonumber(state.actionIndex) or 0)) + 1
			local action = state.actions[nextIndex]
			if type(action) == "table" and type(action.id) == "string" then
				self.LastActionAt = os.clock()
				self:_fire({ action = "PerformAction", actionId = action.id })
			end
		end)
	)
	table.insert(
		self.Connections,
		self.SkipButton.Activated:Connect(function()
			setEnabled(self.SkipButton, false)
			self.SkipButton.Text = if self.App.Locale == "ru"
				then "Готовим финальный кадр..."
				else "CREATING BLOOM…"
			self:_fire({ action = "Skip" })
		end)
	)

	local update = self.Remotes:GetEvent("FirstMiracleUpdate")
	if update then
		table.insert(
			self.Connections,
			update.OnClientEvent:Connect(function(payload: any)
				if type(payload) == "table" then
					self:_apply(payload)
				end
			end)
		)
	end
	for _, attribute in { "AuraRushOnboarded", "AuraRushFlag_FirstMiracle" } do
		table.insert(
			self.Connections,
			self.Player:GetAttributeChangedSignal(attribute):Connect(function()
				if
					attribute == "AuraRushFlag_FirstMiracle"
					and self.Player:GetAttribute(attribute) == false
				then
					self.Overlay.Visible = false
				else
					self:_requestIfReady()
				end
			end)
		)
	end
	table.insert(
		self.Connections,
		RunService.Heartbeat:Connect(function()
			local state = self.State
			if not self.Overlay.Visible or not state then
				return
			end
			local remaining = if type(state.expiresAt) == "number" and state.expiresAt > 0
				then math.max(0, state.expiresAt - os.time())
				else math.max(0, math.floor(tonumber(state.remainingSeconds) or 0))
			self.Timer.Text = string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
			if tostring(state.status or "") == "Actions" then
				self:_trySpatialAction(false)
			end
			if self.SpatialMarker then
				self.SpatialMarker.Transparency = 0.18 + (math.sin(os.clock() * 4) + 1) * 0.12
			end
		end)
	)
end

function FirstMiracleController._renderPalettes(self: FirstMiracleController, state: AnyMap): ()
	for index, button in self.PaletteButtons do
		local choice = if type(state.choices) == "table" then state.choices[index] else nil
		button.Visible = type(choice) == "table"
		if type(choice) == "table" then
			button.Text = localText(self.App.Locale, choice.nameKey, nil)
			local colors = paletteColors(choice)
			button.BackgroundColor3 = colors[2]
			local luminance = colors[2].R * 0.2126 + colors[2].G * 0.7152 + colors[2].B * 0.0722
			button.TextColor3 = if luminance > 0.56
				then Theme.Colors.Background
				else Theme.Colors.Text
			local existing = button:FindFirstChild("PaletteGradient")
			if existing then
				existing:Destroy()
			end
			-- UIGradient on a TextButton also tints its text and destroys contrast.
			-- The palette's solid mid-tone keeps the authored foreground readable.
			setEnabled(button, true)
		end
	end
end

function FirstMiracleController._setStep(self: FirstMiracleController, activeStep: number): ()
	for index, segment in self.StepSegments do
		local reached = index <= activeStep
		segment.BackgroundColor3 = if reached
			then Theme.Colors.Lime
			else Theme.Colors.BackgroundSoft
		local label = segment:FindFirstChild("Label") :: TextLabel?
		if label then
			label.TextColor3 = if reached then Theme.Colors.Background else Theme.Colors.TextMuted
		end
	end
end

function FirstMiracleController._animateBloom(self: FirstMiracleController, state: AnyMap): ()
	self.BloomToken += 1
	local token = self.BloomToken
	for _, child in self.BloomCanvas:GetChildren() do
		child:Destroy()
	end
	local bloom = if type(state.bloom) == "table" then state.bloom else {}
	local colors = paletteColors(bloom)
	self.PanelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors[1]),
		ColorSequenceKeypoint.new(0.5, colors[2]),
		ColorSequenceKeypoint.new(1, colors[3]),
	})
	local settings = self.App:GetSettings()
	local count = if settings.lowVfx then 6 else 18
	local seed = 7919
	for index = 1, #tostring(state.sessionId or "") do
		seed += string.byte(tostring(state.sessionId), index) * index
	end
	local random = Random.new(seed)
	for index = 1, count do
		local spark = Instance.new("Frame")
		spark.Name = `SignalStrip{index}`
		local width = random:NextInteger(5, if settings.lowVfx then 9 else 16)
		local height = random:NextInteger(18, if settings.lowVfx then 38 else 66)
		spark.Size = UDim2.fromOffset(width, height)
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Position =
			UDim2.fromScale(random:NextNumber(0.08, 0.92), random:NextNumber(0.72, 0.94))
		spark.BackgroundColor3 = colors[((index - 1) % #colors) + 1]
		spark.BackgroundTransparency = if settings.noFlashes then 0.28 else 0.08
		spark.BorderSizePixel = 0
		spark.ZIndex = 123
		Theme.addCorner(spark, Theme.Radius.Small)
		spark.Parent = self.BloomCanvas
		if not settings.reducedMotion then
			TweenService:Create(
				spark,
				TweenInfo.new(
					random:NextNumber(1.2, 2.4),
					Enum.EasingStyle.Quint,
					Enum.EasingDirection.Out
				),
				{
					Position = UDim2.fromScale(
						random:NextNumber(0.12, 0.88),
						random:NextNumber(0.08, 0.42)
					),
					BackgroundTransparency = if settings.noFlashes then 0.5 else 1,
					Rotation = random:NextInteger(-90, 90),
				}
			):Play()
		end
	end
	task.delay(3, function()
		if self.Destroyed or self.BloomToken ~= token then
			return
		end
		for _, child in self.BloomCanvas:GetChildren() do
			child:Destroy()
		end
	end)
end

function FirstMiracleController._apply(self: FirstMiracleController, state: AnyMap): ()
	self.State = table.clone(state)
	if state.enabled ~= true or state.required == false and state.status ~= "Complete" then
		self.Overlay.Visible = false
		return
	end
	local status = tostring(state.status or "NotStarted")
	local spatial = if type(state.spatial) == "table" then state.spatial else nil
	local spatialMode = status == "Actions" and spatial ~= nil and spatial.enabled == true
	self:_setSpatialMode(spatialMode)
	self:_setSpatialMarker(if spatialMode then spatial.targetPosition else nil)
	self.Overlay.Visible = status ~= "NotStarted"
	self.PaletteRow.Visible = status == "PaletteChoice"
	self.ActionButton.Visible = status == "Actions"
	self.SkipButton.Visible = status == "PaletteChoice" or status == "Actions"
	setEnabled(self.SkipButton, true)
	self.SkipButton.NextSelectionUp = if status == "PaletteChoice"
		then self.PaletteButtons[1]
		else self.ActionButton
	self.SkipButton.Text = if self.App.Locale == "ru"
		then "Сразу увидеть результат"
		else "SKIP TO BLOOM"
	if UserInputService.GamepadEnabled then
		task.defer(function()
			if not self.Overlay.Visible then
				return
			end
			GuiService.SelectedObject = if status == "PaletteChoice"
				then self.PaletteButtons[1]
				else if status == "Actions" then self.ActionButton else nil
		end)
	end

	local rewards = if type(state.rewards) == "table" then state.rewards else {}
	self.Reward.Text = localText(self.App.Locale, "first_miracle.reward", {
		glowDust = math.max(0, math.floor(tonumber(rewards.glowDust) or 100)),
		atlasXp = math.max(0, math.floor(tonumber(rewards.atlasXp) or 80)),
	})
	if state.readOnly == true then
		self.Reward.Text ..= if self.App.Locale == "ru"
			then "\nВ этом запуске прогресс не сохранится"
			else "\nProgress will not be saved in this session"
	end

	if status == "PaletteChoice" then
		self:_setStep(1)
		self.Title.Text = localText(self.App.Locale, "first_miracle.title", nil)
		self.Intro.Text = localText(self.App.Locale, "first_miracle.intro", nil)
		self.Progress.Text = if self.App.Locale == "ru"
			then "Шаг 1 из 3. Выбери палитру"
			else "Step 1 of 3. Choose a palette"
		self:_renderPalettes(state)
	elseif status == "Actions" then
		self:_setStep(2)
		local completed = math.max(0, math.floor(tonumber(state.actionIndex) or 0))
		local target = math.max(1, math.floor(tonumber(state.actionTarget) or 3))
		local action = if type(state.actions) == "table" then state.actions[completed + 1] else nil
		local actionName = if type(action) == "table"
			then localText(self.App.Locale, action.nameKey, nil)
			else if self.App.Locale == "ru" then "Действуй" else "Act"
		if
			spatialMode
			and (
				self.SpatialActionIndex ~= completed
				or tostring(spatial.status or "") == "checkpoint_refreshed"
			)
		then
			self:_captureSpatialCheckpoint(completed)
		end
		self.Title.Text = if self.App.Locale == "ru"
			then "Сделай три шага"
			else "Make three moves"
		local check = if spatial then tostring(spatial.check or "") else ""
		if check == "world_distance" then
			self.Intro.Text = if self.App.Locale == "ru"
				then "Иди к световой метке."
				else "Follow the line to the light marker."
		elseif check == "airborne_pulse" then
			self.Intro.Text = if self.App.Locale == "ru"
				then "Прыгни, чтобы поймать импульс."
				else "Jump to tune the pulse. The step triggers while you are airborne."
		elseif check == "move_and_turn" then
			self.Intro.Text = if self.App.Locale == "ru"
				then "Дойди до метки сбоку и повернись по линии."
				else "Reach the side marker and turn your character toward the new direction."
		else
			self.Intro.Text = if self.App.Locale == "ru"
				then "Повтори действие в мире."
				else "Perform the next gesture in the game world."
		end
		self.Progress.Text = `{completed} из {target}. {actionName}`
		self.ActionButton.Text = if spatialMode
			then if self.App.Locale == "ru" then "Проверить шаг" else "VERIFY STEP"
			else actionName
		setEnabled(self.ActionButton, true)
	elseif status == "Bloom" then
		self:_setStep(3)
		self.Title.Text = if self.App.Locale == "ru"
			then "Район поймал твой цвет"
			else "The district caught your color"
		self.Intro.Text = if self.App.Locale == "ru"
			then "Свет и сцена подстроились под твою палитру."
			else "Light, scenery, and music now match your choices."
		self.Progress.Text = if self.App.Locale == "ru"
			then "Перекраска идёт"
			else "Color is spreading"
		self.Progress.TextColor3 = Theme.Colors.Lime
		self:_animateBloom(state)
	elseif status == "Complete" then
		self:_setStep(3)
		self.Title.Text = if self.App.Locale == "ru"
			then "Готово — это твой почерк"
			else "Your signature is ready"
		self.Intro.Text = if self.App.Locale == "ru"
			then "Твой цвет готов. Теперь собери общий финал с командой."
			else "Your style is ready. Now build a team finale."
		self.Progress.Text = if self.App.Locale == "ru"
			then "Первый выход готов"
			else "First entrance complete"
		self.Progress.TextColor3 = Theme.Colors.Success
		self.ActionButton.Visible = false
		self.PaletteRow.Visible = false
		self.SkipButton.Visible = false
		self.App:CompleteOnboarding()
		self.App:ShowCaption(self.Title.Text, 2.2, "Success")
		self.CompletionToken += 1
		local token = self.CompletionToken
		task.delay(2.8, function()
			if not self.Destroyed and self.CompletionToken == token then
				self.Overlay.Visible = false
			end
		end)
	end
end

function FirstMiracleController.Destroy(self: FirstMiracleController): ()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.BloomToken += 1
	self.CompletionToken += 1
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	if self.SpatialMarker then
		self.SpatialMarker:Destroy()
		self.SpatialMarker = nil
	end
	self.Overlay:Destroy()
end

return FirstMiracleController
