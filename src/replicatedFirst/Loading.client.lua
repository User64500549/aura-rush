--!strict

-- This file is deliberately self-contained. ReplicatedFirst arrives before the
-- shared/client trees, so the loading experience must never wait for a module or
-- an external image before it can replace the default Roblox screen.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BOOT_GUI_NAME = "AuraRushBootUI"
local BOOT_STATE_ATTRIBUTE = "AuraRushBootState"
local BOOT_DETAIL_ATTRIBUTE = "AuraRushBootDetail"
local RUNTIME_STATE_NAME = "AuraRushRuntimeState"
local SERVER_STATE_ATTRIBUTE = "ServerState"
local SERVER_DETAIL_ATTRIBUTE = "ServerDetail"
local PROFILE_STATE_ATTRIBUTE = "AuraRushProfileState"
local PROFILE_DETAIL_ATTRIBUTE = "AuraRushProfileDetail"

local player = Players.LocalPlayer
local playerGuiInstance = player:FindFirstChildOfClass("PlayerGui")
	or player:WaitForChild("PlayerGui", 15)
if not playerGuiInstance or not playerGuiInstance:IsA("PlayerGui") then
	warn("[AuraRush/Boot] PlayerGui was not available for the loading shell")
	return
end
local playerGui = playerGuiInstance :: PlayerGui
local entryStartedAt = os.clock()

local previous = playerGui:FindFirstChild(BOOT_GUI_NAME)
if previous then
	previous:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = BOOT_GUI_NAME
screenGui.AutoLocalize = false
screenGui.DisplayOrder = 1000
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(8, 9, 18)
background.BorderSizePixel = 0
background.Parent = screenGui

local backgroundGradient = Instance.new("UIGradient")
backgroundGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 9, 18)),
	ColorSequenceKeypoint.new(0.48, Color3.fromRGB(22, 17, 42)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 20, 29)),
})
backgroundGradient.Rotation = 22
backgroundGradient.Parent = background

local glow = Instance.new("Frame")
glow.Name = "Glow"
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.fromScale(0.5, 0.43)
glow.Size = UDim2.fromOffset(360, 360)
glow.BackgroundColor3 = Color3.fromRGB(118, 87, 255)
glow.BackgroundTransparency = 0.8
glow.BorderSizePixel = 0
glow.Parent = background

local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(1, 0)
glowCorner.Parent = glow

local glowGradient = Instance.new("UIGradient")
glowGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 79, 216)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(118, 87, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 232, 255)),
})
glowGradient.Rotation = 35
glowGradient.Parent = glow

local card = Instance.new("Frame")
card.Name = "ArrivalCard"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(1, -48, 0, 250)
card.BackgroundColor3 = Color3.fromRGB(17, 18, 32)
card.BackgroundTransparency = 0.08
card.BorderSizePixel = 0
card.Parent = background

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(272, 250)
sizeConstraint.MaxSize = Vector2.new(520, 250)
sizeConstraint.Parent = card

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 24)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(114, 102, 170)
cardStroke.Transparency = 0.54
cardStroke.Thickness = 1
cardStroke.Parent = card

local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.Size = UDim2.new(1, 0, 0, 5)
accent.BackgroundColor3 = Color3.fromRGB(214, 255, 73)
accent.BorderSizePixel = 0
accent.Parent = card

local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accent

local mark = Instance.new("TextLabel")
mark.Name = "Mark"
mark.Position = UDim2.fromOffset(24, 28)
mark.Size = UDim2.new(1, -48, 0, 34)
mark.BackgroundTransparency = 1
mark.Font = Enum.Font.GothamBold
mark.Text = "AR // 01"
mark.TextColor3 = Color3.fromRGB(214, 255, 73)
mark.TextSize = 16
mark.TextXAlignment = Enum.TextXAlignment.Left
mark.Parent = card

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(24, 66)
title.Size = UDim2.new(1, -48, 0, 48)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "AURA RUSH"
title.TextColor3 = Color3.fromRGB(247, 247, 255)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = card

local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MinTextSize = 30
titleConstraint.MaxTextSize = 43
titleConstraint.Parent = title

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Position = UDim2.fromOffset(24, 119)
status.Size = UDim2.new(1, -48, 0, 28)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamBold
status.Text = "СОБИРАЕМ ГОРОД"
status.TextColor3 = Color3.fromRGB(247, 247, 255)
status.TextSize = 18
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = card

local detail = Instance.new("TextLabel")
detail.Name = "Detail"
detail.Position = UDim2.fromOffset(24, 150)
detail.Size = UDim2.new(1, -48, 0, 44)
detail.BackgroundTransparency = 1
detail.Font = Enum.Font.Gotham
detail.Text = "Свет, музыка и твой первый маршрут — уже рядом"
detail.TextColor3 = Color3.fromRGB(178, 178, 202)
detail.TextSize = 14
detail.TextWrapped = true
detail.TextXAlignment = Enum.TextXAlignment.Left
detail.TextYAlignment = Enum.TextYAlignment.Top
detail.Parent = card

local progressTrack = Instance.new("Frame")
progressTrack.Name = "ProgressTrack"
progressTrack.Position = UDim2.new(0, 24, 1, -34)
progressTrack.Size = UDim2.new(1, -48, 0, 8)
progressTrack.BackgroundColor3 = Color3.fromRGB(41, 42, 63)
progressTrack.BorderSizePixel = 0
progressTrack.ClipsDescendants = true
progressTrack.Parent = card

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = progressTrack

local runner = Instance.new("Frame")
runner.Name = "Runner"
runner.Position = UDim2.fromScale(-0.28, 0)
runner.Size = UDim2.fromScale(0.28, 1)
runner.BackgroundColor3 = Color3.fromRGB(214, 255, 73)
runner.BorderSizePixel = 0
runner.Parent = progressTrack

local runnerCorner = Instance.new("UICorner")
runnerCorner.CornerRadius = UDim.new(1, 0)
runnerCorner.Parent = runner

local runnerGradient = Instance.new("UIGradient")
runnerGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(56, 232, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(214, 255, 73)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 79, 216)),
})
runnerGradient.Parent = runner

screenGui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

local reducedMotion = false
pcall(function()
	reducedMotion = (GuiService :: any).ReducedMotionEnabled == true
end)

local runnerTween: Tween? = nil
local glowTween: Tween? = nil
if not reducedMotion then
	runnerTween = TweenService:Create(
		runner,
		TweenInfo.new(1.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1),
		{ Position = UDim2.fromScale(1, 0) }
	)
	runnerTween:Play()
	glowTween = TweenService:Create(
		glow,
		TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{
			Size = UDim2.fromOffset(390, 390),
			BackgroundTransparency = 0.86,
		}
	)
	glowTween:Play()
else
	runner.Position = UDim2.fromScale(0.36, 0)
end

local finished = false
local stateConnection: RBXScriptConnection? = nil
local clientDetailConnection: RBXScriptConnection? = nil
local runtimeChildConnection: RBXScriptConnection? = nil
local serverStateConnection: RBXScriptConnection? = nil
local serverDetailConnection: RBXScriptConnection? = nil
local profileStateConnection: RBXScriptConnection? = nil
local profileDetailConnection: RBXScriptConnection? = nil
local runtimeState: Folder? = nil

local function setCopy(clientStateValue: any, serverStateValue: any, profileStateValue: any): ()
	local clientState = if type(clientStateValue) == "string" then clientStateValue else "starting"
	local serverState = if type(serverStateValue) == "string"
		then serverStateValue
		else "server_starting"
	local profileState = if type(profileStateValue) == "string"
		then profileStateValue
		else "profile_loading"
	local authoredDetail = playerGui:GetAttribute(BOOT_DETAIL_ATTRIBUTE)
	local serverDetail = if runtimeState
		then runtimeState:GetAttribute(SERVER_DETAIL_ATTRIBUTE)
		else nil
	local profileDetail = player:GetAttribute(PROFILE_DETAIL_ATTRIBUTE)
	status.TextColor3 = Color3.fromRGB(247, 247, 255)
	accent.BackgroundColor3 = Color3.fromRGB(214, 255, 73)
	if clientState == "failed" then
		status.Text = "НЕ УДАЛОСЬ ОТКРЫТЬ РАЙОН"
		status.TextColor3 = Color3.fromRGB(255, 121, 138)
		accent.BackgroundColor3 = Color3.fromRGB(255, 121, 138)
		detail.Text = if type(authoredDetail) == "string" and authoredDetail ~= ""
			then authoredDetail
			else "Перезапусти игру и проверь соединение с интернетом"
	elseif serverState == "server_failed" then
		status.Text = "СЕРВЕР НЕ ЗАПУСТИЛСЯ"
		status.TextColor3 = Color3.fromRGB(255, 121, 138)
		accent.BackgroundColor3 = Color3.fromRGB(255, 121, 138)
		detail.Text = if type(serverDetail) == "string" and serverDetail ~= ""
			then serverDetail
			else "Перезайди через минуту"
	elseif profileState == "profile_failed" then
		status.Text = "ПРОФИЛЬ НЕ ЗАГРУЗИЛСЯ"
		status.TextColor3 = Color3.fromRGB(255, 121, 138)
		accent.BackgroundColor3 = Color3.fromRGB(255, 121, 138)
		detail.Text = if type(profileDetail) == "string" and profileDetail ~= ""
			then profileDetail
			else "Перезайди в игру"
	elseif clientState == "ready" and serverState ~= "server_ready" then
		status.Text = "ЗАПУСКАЕМ РАЙОН"
		detail.Text = if type(serverDetail) == "string" and serverDetail ~= ""
			then serverDetail
			else "Собираем игровые системы"
	elseif
		clientState == "ready"
		and serverState == "server_ready"
		and profileState ~= "profile_ready"
	then
		status.Text = "ЗАГРУЖАЕМ ТВОЙ СТИЛЬ"
		detail.Text = if type(profileDetail) == "string" and profileDetail ~= ""
			then profileDetail
			else "Получаем прогресс и коллекцию"
	elseif clientState == "client_starting" then
		status.Text = "ПОДКЛЮЧАЕМ ИНТЕРФЕЙС"
		if type(authoredDetail) == "string" and authoredDetail ~= "" then
			detail.Text = authoredDetail
		end
	else
		status.Text = "СОБИРАЕМ ГОРОД"
	end
end

local function finish(): ()
	if finished then
		return
	end
	finished = true
	if stateConnection then
		stateConnection:Disconnect()
	end
	if clientDetailConnection then
		clientDetailConnection:Disconnect()
	end
	if runtimeChildConnection then
		runtimeChildConnection:Disconnect()
	end
	if serverStateConnection then
		serverStateConnection:Disconnect()
	end
	if serverDetailConnection then
		serverDetailConnection:Disconnect()
	end
	if profileStateConnection then
		profileStateConnection:Disconnect()
	end
	if profileDetailConnection then
		profileDetailConnection:Disconnect()
	end
	if runnerTween then
		runnerTween:Cancel()
	end
	if glowTween then
		glowTween:Cancel()
	end

	status.Text = "РАЙОН ГОТОВ"
	status.TextColor3 = Color3.fromRGB(214, 255, 73)
	local entryDurationMilliseconds =
		math.max(0, math.floor((os.clock() - entryStartedAt) * 1000 + 0.5))
	playerGui:SetAttribute("AuraRushEntryDurationMs", entryDurationMilliseconds)
	print(string.format("[AuraRush][Performance] EntryReady=%dms", entryDurationMilliseconds))
	local fadeInfo = TweenInfo.new(if reducedMotion then 0.08 else 0.28, Enum.EasingStyle.Quad)
	for _, descendant in screenGui:GetDescendants() do
		if descendant:IsA("GuiObject") then
			local goals: { [string]: any } = { BackgroundTransparency = 1 }
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				goals.TextTransparency = 1
			end
			TweenService:Create(descendant, fadeInfo, goals):Play()
		elseif descendant:IsA("UIStroke") then
			TweenService:Create(descendant, fadeInfo, { Transparency = 1 }):Play()
		end
	end
	task.delay(fadeInfo.Time + 0.04, function()
		if screenGui.Parent then
			screenGui:Destroy()
		end
	end)
end

local function syncState(): ()
	if finished then
		return
	end
	local clientState = playerGui:GetAttribute(BOOT_STATE_ATTRIBUTE)
	local serverState = if runtimeState
		then runtimeState:GetAttribute(SERVER_STATE_ATTRIBUTE)
		else nil
	local profileState = player:GetAttribute(PROFILE_STATE_ATTRIBUTE)
	if
		clientState == "ready"
		and serverState == "server_ready"
		and profileState == "profile_ready"
	then
		finish()
	else
		setCopy(clientState, serverState, profileState)
	end
end

local function attachRuntimeState(candidate: Instance): ()
	if runtimeState or not candidate:IsA("Folder") or candidate.Name ~= RUNTIME_STATE_NAME then
		return
	end
	runtimeState = candidate
	serverStateConnection =
		candidate:GetAttributeChangedSignal(SERVER_STATE_ATTRIBUTE):Connect(syncState)
	serverDetailConnection =
		candidate:GetAttributeChangedSignal(SERVER_DETAIL_ATTRIBUTE):Connect(syncState)
	syncState()
end

stateConnection = playerGui:GetAttributeChangedSignal(BOOT_STATE_ATTRIBUTE):Connect(syncState)
clientDetailConnection =
	playerGui:GetAttributeChangedSignal(BOOT_DETAIL_ATTRIBUTE):Connect(syncState)
profileStateConnection =
	player:GetAttributeChangedSignal(PROFILE_STATE_ATTRIBUTE):Connect(syncState)
profileDetailConnection =
	player:GetAttributeChangedSignal(PROFILE_DETAIL_ATTRIBUTE):Connect(syncState)
runtimeChildConnection = ReplicatedStorage.ChildAdded:Connect(attachRuntimeState)
local existingRuntimeState = ReplicatedStorage:FindFirstChild(RUNTIME_STATE_NAME)
if existingRuntimeState then
	attachRuntimeState(existingRuntimeState)
else
	syncState()
end

task.delay(12, function()
	local serverState = if runtimeState
		then runtimeState:GetAttribute(SERVER_STATE_ATTRIBUTE)
		else nil
	local profileState = player:GetAttribute(PROFILE_STATE_ATTRIBUTE)
	if
		finished
		or playerGui:GetAttribute(BOOT_STATE_ATTRIBUTE) == "failed"
		or serverState == "server_failed"
		or profileState == "profile_failed"
	then
		return
	end
	status.Text = "ЗАГРУЗКА ИДЁТ ДОЛЬШЕ ОБЫЧНОГО"
	detail.Text = "Проверяем соединение с сервером…"
end)

task.delay(30, function()
	local serverState = if runtimeState
		then runtimeState:GetAttribute(SERVER_STATE_ATTRIBUTE)
		else nil
	local profileState = player:GetAttribute(PROFILE_STATE_ATTRIBUTE)
	if
		finished
		or playerGui:GetAttribute(BOOT_STATE_ATTRIBUTE) == "failed"
		or serverState == "server_failed"
		or profileState == "profile_failed"
	then
		return
	end
	status.Text = "РАЙОН НЕ ОТВЕЧАЕТ"
	status.TextColor3 = Color3.fromRGB(255, 205, 92)
	accent.BackgroundColor3 = Color3.fromRGB(255, 205, 92)
	detail.Text =
		"Перезапусти игру. Если экран серый — проверь интернет"
end)
