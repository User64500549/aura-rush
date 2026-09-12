--!strict

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGuiInstance = player:FindFirstChildOfClass("PlayerGui")
	or player:WaitForChild("PlayerGui", 10)
if not playerGuiInstance or not playerGuiInstance:IsA("PlayerGui") then
	warn("[AuraRush] PlayerGui was not available; client bootstrap stopped safely")
	return
end
local playerGui = playerGuiInstance :: PlayerGui
local bootStartedAt = os.clock()
playerGui:SetAttribute("AuraRushBootState", "client_starting")
playerGui:SetAttribute("AuraRushBootDetail", "Готовим твой первый маршрут")

local function boot(): ()
	local App = require(script.Parent.UI.App)
	local RemoteRegistry = require(script.Parent.Controllers.RemoteRegistry)
	local RoundController = require(script.Parent.Controllers.RoundController)
	local InputController = require(script.Parent.Controllers.InputController)
	local StyleController = require(script.Parent.Controllers.StyleController)
	local CameraController = require(script.Parent.Controllers.CameraController)
	local AudioDirector = require(script.Parent.Controllers.AudioDirector)
	local AvatarPreviewController = require(script.Parent.Controllers.AvatarPreviewController)
	local VfxDirector = require(script.Parent.Controllers.VfxDirector)
	local CaptureController = require(script.Parent.Controllers.CaptureController)
	local PoseController = require(script.Parent.Controllers.PoseController)
	local SocialInviteController = require(script.Parent.Controllers.SocialInviteController)
	local StoreController = require(script.Parent.Controllers.StoreController)
	local ClientFeatureFlagController =
		require(script.Parent.Controllers.ClientFeatureFlagController)
	local FirstMiracleController = require(script.Parent.Controllers.FirstMiracleController)
	local MetaPanelController = require(script.Parent.Controllers.MetaPanelController)
	local RemixController = require(script.Parent.Controllers.RemixController)
	local AdminDashboardController = require(script.Parent.Controllers.AdminDashboardController)

	local remotes = RemoteRegistry.new()
	if not remotes:IsReady() then
		error("network contract unavailable: " .. remotes:GetReadinessIssue())
	end

	local app = App.new(playerGui)
	app:SetLoadingStatus("Ищем портал AURA RUSH…")

	-- The default leaderboard occupies the same top-right space as the timer and
	-- settings. Only that list is hidden; chat, Roblox menu and safety tools remain.
	local alive = true
	local previousPlayerList: boolean? = nil
	task.spawn(function()
		for _ = 1, 12 do
			if not alive then
				return
			end
			local ok = pcall(function()
				if previousPlayerList == nil then
					previousPlayerList = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
				end
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)
			if ok then
				return
			end
			task.wait(0.25)
		end
	end)

	-- RoundController starts last so every consumer is subscribed before the first snapshot arrives.
	local featureFlagController = ClientFeatureFlagController.new(remotes)
	local firstMiracleController = FirstMiracleController.new(app, remotes)
	local metaPanelController = MetaPanelController.new(app, remotes)
	local audioDirector = AudioDirector.new(app, remotes)
	local previewController = AvatarPreviewController.new(app)
	StyleController.new(app, remotes)
	local inputController = InputController.new(app, audioDirector)
	local cameraController = CameraController.new(app, remotes)
	local vfxDirector = VfxDirector.new(app, remotes)
	local captureController = CaptureController.new(app)
	local poseController = PoseController.new(app)
	local socialInviteController = SocialInviteController.new(app)
	local storeController = StoreController.new(app)
	local remixController = RemixController.new(app, remotes)
	local adminDashboardController = AdminDashboardController.new(app, remotes, playerGui)
	local roundController = RoundController.new(app, remotes)

	local bootDurationMilliseconds =
		math.max(0, math.floor((os.clock() - bootStartedAt) * 1000 + 0.5))
	playerGui:SetAttribute("AuraRushBootDurationMs", bootDurationMilliseconds)
	playerGui:SetAttribute("AuraRushBootDetail", "Район готов")
	playerGui:SetAttribute("AuraRushBootState", "ready")
	print(string.format("[AuraRush][Performance] ClientBoot=%dms", bootDurationMilliseconds))

	script.Destroying:Connect(function()
		alive = false
		if previousPlayerList ~= nil then
			pcall(function()
				StarterGui:SetCoreGuiEnabled(
					Enum.CoreGuiType.PlayerList,
					previousPlayerList :: boolean
				)
			end)
		end
		roundController:Destroy()
		inputController:Destroy()
		cameraController:Destroy()
		vfxDirector:Destroy()
		previewController:Destroy()
		audioDirector:Destroy()
		captureController:Destroy()
		poseController:Destroy()
		socialInviteController:Destroy()
		storeController:Destroy()
		remixController:Destroy()
		adminDashboardController:Destroy()
		metaPanelController:Destroy()
		firstMiracleController:Destroy()
		featureFlagController:Destroy()
		app:Destroy()
	end)
end

local ok, message = xpcall(boot, debug.traceback)
if not ok then
	playerGui:SetAttribute(
		"AuraRushBootDetail",
		"Перезапусти игру и проверь соединение"
	)
	playerGui:SetAttribute("AuraRushBootState", "failed")
	warn("[AuraRush/Boot] client bootstrap failed:\n" .. tostring(message))
end
