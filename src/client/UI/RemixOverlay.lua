--!strict

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local RemixOverlay = {}
RemixOverlay.__index = RemixOverlay

type AnyMap = { [string]: any }
type ActionHandler = (string, AnyMap?) -> ()

export type RemixOverlay = typeof(setmetatable(
	{} :: {
		ScreenGui: ScreenGui,
		Panel: Frame,
		Scale: UIScale,
		PulseCard: Frame,
		PulseScale: UIScale,
		PulseTitle: TextLabel,
		PulseCue: TextLabel,
		PulseFill: Frame,
		PulseMeta: TextLabel,
		Phase: TextLabel,
		Chemistry: TextLabel,
		RoleCue: TextLabel,
		RoleButtons: { [string]: TextButton },
		MomentDots: { Frame },
		GuardianCard: Frame,
		GuardianTitle: TextLabel,
		GuardianCue: TextLabel,
		GuardianFill: Frame,
		GuardianButton: TextButton,
		ResultsCard: Frame,
		SaveButton: TextButton,
		ConsentButton: TextButton,
		EncoreButton: TextButton,
		Connections: { RBXScriptConnection },
		ActionHandler: ActionHandler?,
		ReducedMotion: boolean,
		Suppressed: boolean,
		LastState: AnyMap?,
		LastCityPulse: AnyMap?,
		ReplayToken: number,
	},
	RemixOverlay
))

local ROLE_SHORT = table.freeze({
	navigator = "ПУТЬ",
	rhythmer = "БИТ",
	colorist = "ЦВЕТ",
	director = "КАДР",
})

local ROLE_ORDER = table.freeze({ "navigator", "rhythmer", "colorist", "director" })

local PHASE_RU = table.freeze({
	BriefChoice = "ВЫБОР МАРШРУТА",
	ThreadRun = "01 • СИГНАЛ",
	BeatLab = "02 • ДУЭТ",
	PrismPuzzle = "03 • ПАЛИТРА",
	MixLab = "СОБЕРИ ОБРАЗ",
	Finale = "ФИНАЛ • СТРАЖ",
	Results = "ТВОЙ РЕМИКС ГОТОВ",
	Replay = "АРХИВ • ПОВТОР",
})

local MOMENT_COLORS = table.freeze({
	route = Theme.Colors.Cyan,
	role = Theme.Colors.Violet,
	thread = Theme.Colors.Lime,
	beat = Theme.Colors.Magenta,
	prism = Theme.Colors.Gold,
	assist = Theme.Colors.Success,
	guardian = Theme.Colors.Orange,
	bloom = Theme.Colors.Text,
})

local function parseColor(value: any, fallback: Color3): Color3
	if type(value) ~= "string" then
		return fallback
	end
	local ok, color = pcall(Color3.fromHex, value)
	return if ok then color else fallback
end

local function label(
	parent: Instance,
	name: string,
	text: string,
	position: UDim2,
	size: UDim2,
	textSize: number,
	font: Enum.Font,
	zIndex: number
): TextLabel
	local result = Instance.new("TextLabel")
	result.Name = name
	result.Text = text
	result.Position = position
	result.Size = size
	result.ZIndex = zIndex
	Theme.styleText(result, textSize, font)
	result.Parent = parent
	return result
end

local function button(
	parent: Instance,
	name: string,
	text: string,
	position: UDim2,
	size: UDim2,
	variant: Theme.ButtonVariant,
	zIndex: number
): TextButton
	local result = Instance.new("TextButton")
	result.Name = name
	result.Text = text
	result.Position = position
	result.Size = size
	result.ZIndex = zIndex
	Theme.styleButton(result, variant)
	result.Parent = parent
	return result
end

function RemixOverlay.new(parent: PlayerGui): RemixOverlay
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RemixCityHUD"
	screenGui.DisplayOrder = 72
	screenGui.IgnoreGuiInset = false
	screenGui.AutoLocalize = false
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = parent

	local panel = Instance.new("Frame")
	panel.Name = "RemixPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -18, 0, 72)
	panel.Size = UDim2.fromOffset(344, 184)
	panel.ClipsDescendants = true
	panel.ZIndex = 72
	panel.Visible = false
	Theme.stylePanel(panel, true)
	Theme.addGradient(panel, {
		Theme.Colors.SurfaceRaised,
		Theme.Colors.BackgroundSoft,
		Theme.Colors.Surface,
	}, 115)
	panel.Parent = screenGui

	local scale = Instance.new("UIScale")
	scale.Name = "ResponsiveScale"
	scale.Parent = panel

	local pulseCard = Instance.new("Frame")
	pulseCard.Name = "CityPulseCard"
	pulseCard.AnchorPoint = Vector2.new(1, 0)
	pulseCard.Position = UDim2.new(1, -18, 0, 72)
	pulseCard.Size = UDim2.fromOffset(344, 134)
	pulseCard.ClipsDescendants = true
	pulseCard.ZIndex = 72
	pulseCard.Visible = false
	Theme.stylePanel(pulseCard, true)
	Theme.addGradient(pulseCard, {
		Theme.Colors.SurfaceRaised,
		Theme.Colors.BackgroundSoft,
		Theme.Colors.Surface,
	}, 118)
	pulseCard.Parent = screenGui
	local pulseScale = Instance.new("UIScale")
	pulseScale.Name = "ResponsiveScale"
	pulseScale.Parent = pulseCard
	local pulseSignal = Instance.new("Frame")
	pulseSignal.Name = "Signal"
	pulseSignal.Position = UDim2.fromOffset(14, 12)
	pulseSignal.Size = UDim2.fromOffset(6, 31)
	pulseSignal.BackgroundColor3 = Theme.Colors.Lime
	pulseSignal.BorderSizePixel = 0
	pulseSignal.ZIndex = 74
	Theme.addCorner(pulseSignal, Theme.Radius.Pill)
	pulseSignal.Parent = pulseCard
	local pulseTitle = label(
		pulseCard,
		"PulseTitle",
		"ГОРОДСКОЙ ПУЛЬС",
		UDim2.fromOffset(30, 8),
		UDim2.new(1, -44, 0, 28),
		17,
		Theme.Fonts.Display,
		74
	)
	pulseTitle.TextWrapped = false
	local pulseCue = label(
		pulseCard,
		"PulseCue",
		"Наступай на световые плиты вместе с другими.",
		UDim2.fromOffset(14, 39),
		UDim2.new(1, -28, 0, 39),
		12,
		Theme.Fonts.Medium,
		74
	)
	pulseCue.TextColor3 = Theme.Colors.TextMuted
	pulseCue.TextWrapped = true
	local pulseTrack = Instance.new("Frame")
	pulseTrack.Name = "PulseTrack"
	pulseTrack.Position = UDim2.fromOffset(14, 92)
	pulseTrack.Size = UDim2.new(1, -118, 0, 15)
	pulseTrack.BackgroundColor3 = Theme.Colors.BackgroundSoft
	pulseTrack.BorderSizePixel = 0
	pulseTrack.ClipsDescendants = true
	pulseTrack.ZIndex = 74
	Theme.addCorner(pulseTrack, Theme.Radius.Pill)
	pulseTrack.Parent = pulseCard
	local pulseFill = Instance.new("Frame")
	pulseFill.Name = "Fill"
	pulseFill.Size = UDim2.fromScale(0, 1)
	pulseFill.BackgroundColor3 = Theme.Colors.Lime
	pulseFill.BorderSizePixel = 0
	pulseFill.ZIndex = 75
	Theme.addCorner(pulseFill, Theme.Radius.Pill)
	pulseFill.Parent = pulseTrack
	local pulseMeta = label(
		pulseCard,
		"PulseMeta",
		"0 / 10",
		UDim2.new(1, -96, 0, 86),
		UDim2.fromOffset(82, 28),
		11,
		Theme.Fonts.Bold,
		74
	)
	pulseMeta.TextColor3 = Theme.Colors.Lime
	pulseMeta.TextXAlignment = Enum.TextXAlignment.Right
	pulseMeta.TextWrapped = false

	local headerSignal = Instance.new("Frame")
	headerSignal.Name = "LiveSignal"
	headerSignal.Position = UDim2.fromOffset(14, 12)
	headerSignal.Size = UDim2.fromOffset(6, 26)
	headerSignal.BackgroundColor3 = Theme.Colors.Lime
	headerSignal.BorderSizePixel = 0
	headerSignal.ZIndex = 74
	Theme.addCorner(headerSignal, Theme.Radius.Pill)
	headerSignal.Parent = panel

	local title = label(
		panel,
		"Title",
		"РЕМИКС",
		UDim2.fromOffset(30, 8),
		UDim2.fromOffset(132, 28),
		20,
		Theme.Fonts.Display,
		74
	)
	title.TextWrapped = false

	local phase = label(
		panel,
		"Phase",
		"ЖИВОЙ ЗАБЕГ",
		UDim2.new(1, -154, 0, 11),
		UDim2.fromOffset(138, 24),
		11,
		Theme.Fonts.Bold,
		74
	)
	phase.TextColor3 = Theme.Colors.Lime
	phase.TextXAlignment = Enum.TextXAlignment.Right
	phase.TextWrapped = false

	local chemistry = label(
		panel,
		"Chemistry",
		"СТИЛЬ КОМАНДЫ • СОБИРАЕТСЯ",
		UDim2.fromOffset(14, 44),
		UDim2.new(1, -28, 0, 34),
		13,
		Theme.Fonts.Bold,
		74
	)
	chemistry.BackgroundColor3 = Theme.Colors.BackgroundSoft
	chemistry.BackgroundTransparency = 0.08
	chemistry.TextColor3 = Theme.Colors.Cyan
	chemistry.TextXAlignment = Enum.TextXAlignment.Center
	Theme.addCorner(chemistry, Theme.Radius.Medium)
	Theme.addStroke(chemistry, Theme.Colors.Cyan, 0.55)

	local roleHeader = label(
		panel,
		"RoleHeader",
		"ТВОЯ РОЛЬ",
		UDim2.fromOffset(14, 85),
		UDim2.new(1, -28, 0, 16),
		10,
		Theme.Fonts.Bold,
		74
	)
	roleHeader.TextColor3 = Theme.Colors.TextMuted
	roleHeader.TextWrapped = false

	local roleRow = Instance.new("Frame")
	roleRow.Name = "RoleRow"
	roleRow.Position = UDim2.fromOffset(14, 104)
	roleRow.Size = UDim2.new(1, -28, 0, 40)
	roleRow.BackgroundTransparency = 1
	roleRow.ZIndex = 74
	roleRow.Parent = panel
	local roleLayout = Instance.new("UIListLayout")
	roleLayout.FillDirection = Enum.FillDirection.Horizontal
	roleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	roleLayout.Padding = UDim.new(0, 6)
	roleLayout.Parent = roleRow

	local roleButtons: { [string]: TextButton } = {}
	for order, roleId in ROLE_ORDER do
		local roleButton = button(
			roleRow,
			"Role_" .. roleId,
			ROLE_SHORT[roleId],
			UDim2.fromOffset(0, 0),
			UDim2.new(0.25, -6, 1, 0),
			"Secondary",
			75
		)
		roleButton.LayoutOrder = order
		roleButton.TextSize = 11
		roleButtons[roleId] = roleButton
	end

	local roleCue = label(
		panel,
		"RoleCue",
		"Выбери, за что отвечаешь в команде",
		UDim2.fromOffset(14, 147),
		UDim2.new(1, -28, 0, 20),
		11,
		Theme.Fonts.Medium,
		74
	)
	roleCue.TextColor3 = Theme.Colors.TextMuted
	roleCue.TextXAlignment = Enum.TextXAlignment.Left

	local storyboardLabel = label(
		panel,
		"StoryboardLabel",
		"КАДРЫ ЗАБЕГА",
		UDim2.fromOffset(14, 166),
		UDim2.fromOffset(0, 0),
		11,
		Theme.Fonts.Bold,
		74
	)
	storyboardLabel.TextColor3 = Theme.Colors.TextDim
	storyboardLabel.TextWrapped = false
	storyboardLabel.Visible = false

	local momentRow = Instance.new("Frame")
	momentRow.Name = "MomentRow"
	momentRow.Position = UDim2.fromOffset(14, 169)
	momentRow.Size = UDim2.new(1, -28, 0, 10)
	momentRow.BackgroundTransparency = 1
	momentRow.ZIndex = 74
	momentRow.Parent = panel
	local momentLayout = Instance.new("UIListLayout")
	momentLayout.FillDirection = Enum.FillDirection.Horizontal
	momentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	momentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	momentLayout.Padding = UDim.new(0, 4)
	momentLayout.Parent = momentRow
	local momentDots = {}
	for index = 1, 12 do
		local dot = Instance.new("Frame")
		dot.Name = `Moment_{index}`
		dot.LayoutOrder = index
		dot.Size = UDim2.fromOffset(9, 9)
		dot.BackgroundColor3 = Theme.Colors.SurfaceRaised
		dot.BackgroundTransparency = 0.25
		dot.BorderSizePixel = 0
		dot.ZIndex = 75
		Theme.addCorner(dot, Theme.Radius.Pill)
		dot.Parent = momentRow
		table.insert(momentDots, dot)
	end

	local guardianCard = Instance.new("Frame")
	guardianCard.Name = "GuardianCard"
	guardianCard.Position = UDim2.fromOffset(10, 184)
	guardianCard.Size = UDim2.new(1, -20, 0, 106)
	guardianCard.ZIndex = 74
	guardianCard.Visible = false
	Theme.styleCard(guardianCard, true)
	guardianCard.Parent = panel
	local guardianTitle = label(
		guardianCard,
		"GuardianTitle",
		"СТРАЖ КВАРТАЛА",
		UDim2.fromOffset(12, 7),
		UDim2.new(1, -112, 0, 23),
		14,
		Theme.Fonts.Display,
		75
	)
	local guardianCue = label(
		guardianCard,
		"GuardianCue",
		"Лови подсвеченную роль",
		UDim2.fromOffset(12, 31),
		UDim2.new(1, -112, 0, 29),
		11,
		Theme.Fonts.Medium,
		75
	)
	guardianCue.TextColor3 = Theme.Colors.TextMuted
	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "ProgressTrack"
	progressTrack.Position = UDim2.fromOffset(12, 72)
	progressTrack.Size = UDim2.new(1, -126, 0, 15)
	progressTrack.BackgroundColor3 = Theme.Colors.BackgroundSoft
	progressTrack.BorderSizePixel = 0
	progressTrack.ClipsDescendants = true
	progressTrack.ZIndex = 75
	Theme.addCorner(progressTrack, Theme.Radius.Pill)
	progressTrack.Parent = guardianCard
	local guardianFill = Instance.new("Frame")
	guardianFill.Name = "Fill"
	guardianFill.Size = UDim2.fromScale(0, 1)
	guardianFill.BackgroundColor3 = Theme.Colors.Orange
	guardianFill.BorderSizePixel = 0
	guardianFill.ZIndex = 76
	Theme.addCorner(guardianFill, Theme.Radius.Pill)
	guardianFill.Parent = progressTrack
	local guardianButton = button(
		guardianCard,
		"Pulse",
		"В РИТМ",
		UDim2.new(1, -104, 0, 12),
		UDim2.fromOffset(92, 80),
		"Primary",
		76
	)
	guardianButton.TextSize = 15

	local resultsCard = Instance.new("Frame")
	resultsCard.Name = "ResultsCard"
	resultsCard.Position = UDim2.fromOffset(10, 184)
	resultsCard.Size = UDim2.new(1, -20, 0, 104)
	resultsCard.ZIndex = 74
	resultsCard.Visible = false
	Theme.styleCard(resultsCard, true)
	resultsCard.Parent = panel
	local resultTitle = label(
		resultsCard,
		"ResultTitle",
		"СОХРАНИ ЛУЧШИЕ КАДРЫ",
		UDim2.fromOffset(10, 6),
		UDim2.new(1, -24, 0, 22),
		13,
		Theme.Fonts.Bold,
		75
	)
	resultTitle.TextColor3 = Theme.Colors.Lime
	local saveButton = button(
		resultsCard,
		"Save",
		"СОХРАНИТЬ",
		UDim2.fromOffset(10, 34),
		UDim2.new(0.34, -7, 0, 56),
		"Primary",
		76
	)
	local consentButton = button(
		resultsCard,
		"Consent",
		"ПОВТОР: ДА",
		UDim2.new(0.34, 3, 0, 34),
		UDim2.new(0.32, -7, 0, 56),
		"Secondary",
		76
	)
	local encoreButton = button(
		resultsCard,
		"Encore",
		"ЕЩЁ РАЗ",
		UDim2.new(0.66, 7, 0, 34),
		UDim2.new(0.34, -17, 0, 56),
		"Secondary",
		76
	)

	local self: RemixOverlay = setmetatable({
		ScreenGui = screenGui,
		Panel = panel,
		Scale = scale,
		PulseCard = pulseCard,
		PulseScale = pulseScale,
		PulseTitle = pulseTitle,
		PulseCue = pulseCue,
		PulseFill = pulseFill,
		PulseMeta = pulseMeta,
		Phase = phase,
		Chemistry = chemistry,
		RoleCue = roleCue,
		RoleButtons = roleButtons,
		MomentDots = momentDots,
		GuardianCard = guardianCard,
		GuardianTitle = guardianTitle,
		GuardianCue = guardianCue,
		GuardianFill = guardianFill,
		GuardianButton = guardianButton,
		ResultsCard = resultsCard,
		SaveButton = saveButton,
		ConsentButton = consentButton,
		EncoreButton = encoreButton,
		Connections = {},
		ActionHandler = nil,
		ReducedMotion = false,
		Suppressed = false,
		LastState = nil,
		LastCityPulse = nil,
		ReplayToken = 0,
	}, RemixOverlay)

	for roleId, roleButton in roleButtons do
		table.insert(
			self.Connections,
			roleButton.Activated:Connect(function()
				if self.ActionHandler then
					self.ActionHandler("select_role", { roleId = roleId })
				end
			end)
		)
	end
	table.insert(
		self.Connections,
		guardianButton.Activated:Connect(function()
			if self.ActionHandler then
				self.ActionHandler("guardian_pulse")
			end
		end)
	)
	table.insert(
		self.Connections,
		saveButton.Activated:Connect(function()
			if self.ActionHandler then
				self.ActionHandler("save_remix")
			end
		end)
	)
	table.insert(
		self.Connections,
		consentButton.Activated:Connect(function()
			local current = self.LastState
			if self.ActionHandler and current then
				self.ActionHandler("set_replay_consent", {
					consent = current.replayConsent ~= true,
				})
			end
		end)
	)
	table.insert(
		self.Connections,
		encoreButton.Activated:Connect(function()
			if self.ActionHandler then
				self.ActionHandler("encore")
			end
		end)
	)

	return self
end

function RemixOverlay.SetActionHandler(self: RemixOverlay, handler: ActionHandler): ()
	self.ActionHandler = handler
end

function RemixOverlay.SetReducedMotion(self: RemixOverlay, enabled: boolean): ()
	self.ReducedMotion = enabled
end

function RemixOverlay.SetSuppressed(self: RemixOverlay, suppressed: boolean): ()
	self.Suppressed = suppressed
	self.ScreenGui.Enabled = not suppressed and (self.Panel.Visible or self.PulseCard.Visible)
end

local function hubPhase(phase: string): boolean
	return phase == "Waiting"
		or phase == "Intermission"
		or phase == "BriefChoice"
		or phase == "Cleanup"
end

local function renderCityPulse(self: RemixOverlay, data: AnyMap?, visible: boolean): ()
	self.PulseCard.Visible = visible
	if not visible or type(data) ~= "table" then
		return
	end
	local accent = parseColor(data.accentHex, Theme.Colors.Lime)
	local progress = math.max(0, math.floor(tonumber(data.progress) or 0))
	local target = math.max(1, math.floor(tonumber(data.target) or 1))
	local alpha = math.clamp(progress / target, 0, 1)
	self.PulseTitle.Text = if data.complete == true
		then "ПЛОЩАДЬ ОЖИЛА"
		else `ПУЛЬС • {tostring(data.nameRu or "ГОРОД")}`
	local preferredIndex = math.max(0, math.floor(tonumber(data.preferredPadIndex) or 0))
	local preferredName = tostring(data.preferredPadNameRu or "")
	local preferredCue = if preferredIndex > 0 and preferredName ~= ""
		then `БОНУС: {preferredIndex} · {preferredName}  •  `
		else ""
	self.PulseCue.Text = if data.complete == true
		then "Готово. Новый импульс появится совсем скоро."
		else preferredCue .. tostring(
			data.cueRu
				or "Наступай на световые плиты вместе с другими."
		)
	self.PulseMeta.Text = `{progress} / {target} · {math.max(
		0,
		math.floor(tonumber(data.contributors) or 0)
	)} чел.`
	self.PulseMeta.TextColor3 = accent
	local signal = self.PulseCard:FindFirstChild("Signal")
	if signal and signal:IsA("Frame") then
		signal.BackgroundColor3 = accent
	end
	local goal = { Size = UDim2.fromScale(alpha, 1), BackgroundColor3 = accent }
	if self.ReducedMotion then
		self.PulseFill.Size = goal.Size
		self.PulseFill.BackgroundColor3 = goal.BackgroundColor3
	else
		TweenService:Create(
			self.PulseFill,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goal
		):Play()
	end
end

function RemixOverlay.UpdateViewport(self: RemixOverlay, viewport: Vector2): ()
	if viewport.X < 720 then
		local compactScale = math.clamp((viewport.X - 18) / 344, 0.82, 0.98)
		self.Scale.Scale = compactScale
		self.PulseScale.Scale = compactScale
		self.Panel.Position = UDim2.new(1, -10, 0, 64)
		self.PulseCard.Position = UDim2.new(1, -10, 0, 64)
	else
		self.Scale.Scale = 1
		self.PulseScale.Scale = 1
		self.Panel.Position = UDim2.new(1, -18, 0, 72)
		self.PulseCard.Position = UDim2.new(1, -18, 0, 72)
	end
end

function RemixOverlay.Apply(self: RemixOverlay, data: AnyMap): ()
	self.LastState = data
	local phase = tostring(data.phase or "Waiting")
	local runVisible = data.enabled == true
		and type(data.roundId) == "string"
		and data.roundId ~= ""
		and phase ~= "Waiting"
		and phase ~= "Cleanup"
		and phase ~= "Results"
	local cityPulse = if type(data.cityPulse) == "table" then data.cityPulse else self.LastCityPulse
	if type(data.cityPulse) == "table" then
		self.LastCityPulse = data.cityPulse
	end
	local pulseVisible = not runVisible
		and hubPhase(phase)
		and type(cityPulse) == "table"
		and cityPulse.enabled == true
	self.Panel.Visible = runVisible
	renderCityPulse(self, cityPulse, pulseVisible)
	self.ScreenGui.Enabled = not self.Suppressed and (runVisible or pulseVisible)
	if not runVisible then
		return
	end

	self.Phase.Text = PHASE_RU[phase] or "ЖИВОЙ ЗАБЕГ"
	local chemistry = data.chemistry
	local primary = if type(chemistry) == "table" then chemistry.primary else nil
	if type(primary) == "table" then
		local resonance =
			math.floor(math.clamp(tonumber(chemistry.resonance) or 0, 0, 1) * 100 + 0.5)
		self.Chemistry.Text =
			`СТИЛЬ • {tostring(primary.nameRu or "Новый микс")}  {resonance}%`
	else
		self.Chemistry.Text = "СТИЛЬ КОМАНДЫ • СОБИРАЕТСЯ"
	end

	local roleId = tostring(data.roleId or "")
	for buttonRoleId, roleButton in self.RoleButtons do
		Theme.setButtonSelected(roleButton, buttonRoleId == roleId)
		local canChangeRole = phase ~= "Replay" and phase ~= "Finale"
		roleButton.Active = canChangeRole
		roleButton.AutoButtonColor = canChangeRole
	end
	local role = data.role
	self.RoleCue.Text = if phase == "Replay"
		then `Сохранённый забег • {#(if type(data.storyboard) == "table"
			then data.storyboard
			else {})} кадров`
		elseif type(role) == "table" then tostring(
			role.cueRu or "Держи свою часть общего ритма"
		)
		else "Выбери, за что отвечаешь в команде"

	local storyboard = if type(data.storyboard) == "table" then data.storyboard else {}
	for index, dot in self.MomentDots do
		local moment = storyboard[index]
		dot.BackgroundColor3 = if type(moment) == "table"
			then MOMENT_COLORS[tostring(moment.kind)] or Theme.Colors.TextMuted
			else Theme.Colors.SurfaceRaised
		dot.BackgroundTransparency = if moment then 0 else 0.45
	end

	local guardian = data.guardian
	local showGuardian = phase == "Finale" and type(guardian) == "table"
	self.GuardianCard.Visible = showGuardian
	self.ResultsCard.Visible = false
	self.Panel.Size = UDim2.fromOffset(
		344,
		if showGuardian
			then 300
			elseif phase == "Results" then 298
			elseif phase == "BriefChoice" then 82
			else 184
	)
	if showGuardian then
		local accent = parseColor(guardian.accentHex, Theme.Colors.Orange)
		self.GuardianTitle.Text = tostring(guardian.nameRu or "Страж квартала")
		local requiredRole = ROLE_SHORT[tostring(guardian.requiredRoleId)] or "В РИТМ"
		self.GuardianCue.Text = if guardian.complete == true
			then "ГОТОВО • КВАРТАЛ ОЖИЛ"
			else `СЕЙЧАС: {requiredRole} • {tostring(
				guardian.verbRu or "Лови волну"
			)}`
		local target = math.max(tonumber(guardian.target) or 1, 1)
		local alpha = math.clamp((tonumber(guardian.progress) or 0) / target, 0, 1)
		local goal = { Size = UDim2.fromScale(alpha, 1), BackgroundColor3 = accent }
		if self.ReducedMotion then
			self.GuardianFill.Size = goal.Size
			self.GuardianFill.BackgroundColor3 = goal.BackgroundColor3
		else
			TweenService:Create(
				self.GuardianFill,
				TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				goal
			):Play()
		end
		self.GuardianButton.Text = if guardian.complete == true
			then "ГОТОВО"
			else "В РИТМ"
		self.GuardianButton.Active = guardian.complete ~= true
		self.GuardianButton.AutoButtonColor = guardian.complete ~= true
	end

	if phase == "Results" then
		local hasReplay = data.hasPendingReplay == true
		local writable = data.readOnly ~= true
		self.SaveButton.Text = if not writable
			then "ПОСЛЕ ЗАПУСКА"
			elseif hasReplay then "СОХРАНИТЬ"
			else "СОХРАНЕНО"
		self.SaveButton.Active = hasReplay and writable
		self.SaveButton.AutoButtonColor = hasReplay and writable
		self.ConsentButton.Text = if data.replayConsent == true
			then "ПОВТОР: ДА"
			else "ПОВТОР: НЕТ"
		self.ConsentButton.Active = writable
		self.ConsentButton.AutoButtonColor = writable
		Theme.setButtonSelected(self.ConsentButton, data.replayConsent == true)
	end
end

function RemixOverlay.ApplyCityPulse(self: RemixOverlay, data: AnyMap): ()
	self.LastCityPulse = data
	local phase = if self.LastState then tostring(self.LastState.phase or "Waiting") else "Waiting"
	local visible = not self.Panel.Visible and hubPhase(phase) and data.enabled == true
	renderCityPulse(self, data, visible)
	self.ScreenGui.Enabled = not self.Suppressed and (self.Panel.Visible or visible)
end

function RemixOverlay.PlayReplay(self: RemixOverlay, data: AnyMap): ()
	self.ReplayToken += 1
	local token = self.ReplayToken
	local returnState = self.LastState
	local storyboard = if type(data.storyboard) == "table" then data.storyboard else {}
	local replayView = table.clone(data)
	replayView.storyboard = storyboard
	self:Apply(replayView)
	for _, dot in self.MomentDots do
		dot.BackgroundColor3 = Theme.Colors.SurfaceRaised
		dot.BackgroundTransparency = 0.45
	end
	task.spawn(function()
		for index, moment in storyboard do
			if token ~= self.ReplayToken or not self.ScreenGui.Parent then
				return
			end
			local dot = self.MomentDots[index]
			if dot then
				dot.BackgroundColor3 = if type(moment) == "table"
					then MOMENT_COLORS[tostring(moment.kind)] or Theme.Colors.TextMuted
					else Theme.Colors.TextMuted
				dot.BackgroundTransparency = 0
				if not self.ReducedMotion then
					local original = dot.Size
					dot.Size = UDim2.fromOffset(18, 18)
					TweenService:Create(
						dot,
						TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Size = original }
					):Play()
				end
			end
			task.wait(0.32)
		end
		task.wait(5)
		if token == self.ReplayToken and self.LastState and self.LastState.phase == "Replay" then
			self.Panel.Visible = false
			self.PulseCard.Visible = false
			self.ScreenGui.Enabled = false
			self.LastState = returnState
		end
	end)
end

function RemixOverlay.Destroy(self: RemixOverlay): ()
	self.ReplayToken += 1
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self.ScreenGui:Destroy()
end

return RemixOverlay
