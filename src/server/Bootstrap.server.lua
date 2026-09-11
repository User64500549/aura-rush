--!strict

-- Release automation can start a server from a local place snapshot. The
-- one-shot publisher removes this marker before serializing the place, so
-- production servers always continue through the normal bootstrap below.
local publishGuard = game:GetService("ServerScriptService"):FindFirstChild("__AuraRushPublishGuard")
if publishGuard then
	publishGuard:SetAttribute("BootstrapBlocked", true)
	print("[AuraRush] publish guard active; bootstrap skipped")
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RUNTIME_STATE_NAME = "AuraRushRuntimeState"
local serverBootStartedAt = os.clock()
local runtimeCandidate = ReplicatedStorage:FindFirstChild(RUNTIME_STATE_NAME)
if runtimeCandidate and not runtimeCandidate:IsA("Folder") then
	runtimeCandidate:Destroy()
	runtimeCandidate = nil
end

local runtimeState: Folder
if runtimeCandidate then
	runtimeState = runtimeCandidate :: Folder
else
	runtimeState = Instance.new("Folder")
	runtimeState.Name = RUNTIME_STATE_NAME
	runtimeState.Parent = ReplicatedStorage
end

local function setRuntimeState(state: string, detail: string, step: string): ()
	runtimeState:SetAttribute("ServerState", state)
	runtimeState:SetAttribute("ServerDetail", detail)
	runtimeState:SetAttribute("ServerStep", step)
end

local function failureCode(message: string): string
	local hash = 5381
	for index = 1, #message do
		hash = (hash * 33 + string.byte(message, index)) % 4294967296
	end
	return string.format("S-%08X", hash)
end

setRuntimeState("server_starting", "Проверяем игровые системы", "contracts")
runtimeState:SetAttribute("ServerFailureCode", nil)
runtimeState:SetAttribute("CleanupFailureCount", 0)

local lifecycle: any = nil
local function runLifecycleCleanup(reason: string): ()
	if not lifecycle then
		return
	end
	local errors = lifecycle:Run()
	runtimeState:SetAttribute("CleanupFailureCount", #errors)
	for _, cleanupError in errors do
		warn(
			string.format(
				"[AuraRush/Cleanup:%s] %s failed:\n%s",
				reason,
				cleanupError.label,
				cleanupError.message
			)
		)
	end
end

local function boot(): ()
	local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
	local servicesRoot = script.Parent:WaitForChild("Services")
	local LifecycleStack =
		require(script.Parent:WaitForChild("Util"):WaitForChild("LifecycleStack"))
	lifecycle = LifecycleStack.new()

	local Config = require(sharedRoot:WaitForChild("Config"))
	local RemotesDefinition = require(sharedRoot:WaitForChild("Remotes"))
	local BriefCatalog = require(sharedRoot:WaitForChild("BriefCatalog"))
	local StyleCatalog = require(sharedRoot:WaitForChild("StyleCatalog"))
	local RemixCatalog = require(sharedRoot:WaitForChild("RemixCatalog"))
	local PremiumCityCatalog = require(sharedRoot:WaitForChild("PremiumCityCatalog"))
	local StyleChemistry = require(sharedRoot:WaitForChild("StyleChemistry"))
	local ArtDirectionRegistry = require(sharedRoot:WaitForChild("ArtDirectionRegistry"))
	local LiveOpsManifest = require(sharedRoot:WaitForChild("LiveOpsManifest"))
	local ProductionAssetManifest = require(sharedRoot:WaitForChild("ProductionAssetManifest"))
	local ProductCatalogModule = sharedRoot:FindFirstChild("ProductCatalog")
	local ProductCatalog = if ProductCatalogModule then require(ProductCatalogModule) else {}

	local RemoteService = require(servicesRoot:WaitForChild("RemoteService"))
	local FeatureFlagService = require(servicesRoot:WaitForChild("FeatureFlagService"))
	local PerformanceService = require(servicesRoot:WaitForChild("PerformanceService"))
	local ProductionAssetService = require(servicesRoot:WaitForChild("ProductionAssetService"))
	local PartyService = require(servicesRoot:WaitForChild("PartyService"))
	local DataService = require(servicesRoot:WaitForChild("DataService"))
	local EconomyService = require(servicesRoot:WaitForChild("EconomyService"))
	local ProgressionService = require(servicesRoot:WaitForChild("ProgressionService"))
	local QuestService = require(servicesRoot:WaitForChild("QuestService"))
	local LiveOpsService = require(servicesRoot:WaitForChild("LiveOpsService"))
	local CommunityBloomService = require(servicesRoot:WaitForChild("CommunityBloomService"))
	local WorldService = require(servicesRoot:WaitForChild("WorldService"))
	local ChallengeService = require(servicesRoot:WaitForChild("ChallengeService"))
	local StyleService = require(servicesRoot:WaitForChild("StyleService"))
	local RemixCityService = require(servicesRoot:WaitForChild("RemixCityService"))
	local CityPulseService = require(servicesRoot:WaitForChild("CityPulseService"))
	local RewardService = require(servicesRoot:WaitForChild("RewardService"))
	local AnalyticsService = require(servicesRoot:WaitForChild("AnalyticsService"))
	local PurchaseService = require(servicesRoot:WaitForChild("PurchaseService"))
	local RunDirectorService = require(servicesRoot:WaitForChild("RunDirectorService"))
	local AuraGenomeService = require(servicesRoot:WaitForChild("AuraGenomeService"))
	local RoundService = require(servicesRoot:WaitForChild("RoundService"))
	local SocialCreationService = require(servicesRoot:WaitForChild("SocialCreationService"))
	local CelebrationService = require(servicesRoot:WaitForChild("CelebrationService"))
	local FirstMiracleService = require(servicesRoot:WaitForChild("FirstMiracleService"))
	local MetaService = require(servicesRoot:WaitForChild("MetaService"))
	local SecretFrameService = require(servicesRoot:WaitForChild("SecretFrameService"))

	local context: any = {
		Config = Config,
		RemotesDefinition = RemotesDefinition,
		BriefCatalog = BriefCatalog,
		StyleCatalog = StyleCatalog,
		RemixCatalog = RemixCatalog,
		PremiumCityCatalog = PremiumCityCatalog,
		StyleChemistry = StyleChemistry,
		ArtDirectionRegistry = ArtDirectionRegistry,
		LiveOpsManifest = LiveOpsManifest,
		ProductionAssetManifest = ProductionAssetManifest,
		ProductCatalog = ProductCatalog,
		Services = {},
	}

	setRuntimeState(
		"server_starting",
		"Подключаем безопасную сеть",
		"network"
	)
	context.Services.Remote = RemoteService
	lifecycle:Add("network", RemoteService.Destroy)
	RemoteService.Init(context)

	context.Services.Flags = FeatureFlagService
	lifecycle:Add("feature flags", FeatureFlagService.Destroy)
	FeatureFlagService.Init(context)

	context.Services.Performance = PerformanceService
	lifecycle:Add("performance", PerformanceService.Destroy)
	PerformanceService.Init(context)

	context.Services.ProductionAssets = ProductionAssetService
	ProductionAssetService.Init(context)

	context.Services.Party = PartyService
	lifecycle:Add("party", PartyService.Destroy)
	PartyService.Init(context)

	setRuntimeState("server_starting", "Собираем город", "world")
	context.Services.World = WorldService
	WorldService.Init(context)
	local world: Model? = nil
	lifecycle:Add("world", function()
		local builtWorld = world or workspace:FindFirstChild("AuraRushWorld")
		if builtWorld then
			builtWorld:Destroy()
		end
	end)
	world = PerformanceService.Measure("ServerBoot.WorldBuild", WorldService.Build)
	local worldBuildMetrics = PerformanceService.GetSnapshot().phases["ServerBoot.WorldBuild"]
	if worldBuildMetrics then
		local worldBuildMilliseconds = worldBuildMetrics.p50Milliseconds
		local builtWorld = world :: Model
		builtWorld:SetAttribute("ServerBootWorldBuildMilliseconds", worldBuildMilliseconds)
		print(
			string.format(
				"[AuraRush][Performance] ServerBoot.WorldBuild=%.2fms",
				worldBuildMilliseconds
			)
		)
	end
	ProductionAssetService.Preload(world :: Model)

	setRuntimeState("server_starting", "Готовим прогресс", "data")
	context.Services.Data = DataService
	DataService.Init(context)
	lifecycle:Add("data", DataService.Shutdown)

	context.Services.Analytics = AnalyticsService
	lifecycle:Add("analytics", AnalyticsService.Destroy)
	AnalyticsService.Init(context)

	context.Services.Economy = EconomyService
	EconomyService.Init(context)

	context.Services.Progression = ProgressionService
	ProgressionService.Init(context)

	context.Services.Quest = QuestService
	QuestService.Init(context)

	context.Services.LiveOps = LiveOpsService
	LiveOpsService.Init(context)

	context.Services.Community = CommunityBloomService
	lifecycle:Add("community bloom", CommunityBloomService.Stop)
	CommunityBloomService.Init(context)

	setRuntimeState(
		"server_starting",
		"Запускаем игровые маршруты",
		"gameplay"
	)
	context.Services.Style = StyleService
	StyleService.Init(context)

	context.Services.CityPulse = CityPulseService
	lifecycle:Add("city pulse", CityPulseService.Stop)
	CityPulseService.Init(context)

	context.Services.Remix = RemixCityService
	lifecycle:Add("remix city", RemixCityService.Reset)
	RemixCityService.Init(context)

	context.Services.Challenge = ChallengeService
	ChallengeService.Init(context)
	ChallengeService.BindWorld()

	context.Services.Reward = RewardService
	RewardService.Init(context)

	context.Services.Purchase = PurchaseService
	PurchaseService.Init(context)

	context.Services.RunDirector = RunDirectorService
	context.Services.AuraGenome = AuraGenomeService

	context.Services.Round = RoundService
	lifecycle:Add("round", RoundService.Stop)
	RoundService.Init(context)

	context.Services.SocialCreation = SocialCreationService
	SocialCreationService.Init(context)

	context.Services.Celebration = CelebrationService
	CelebrationService.Init(context)

	context.Services.FirstMiracle = FirstMiracleService
	FirstMiracleService.Init(context)

	context.Services.Meta = MetaService
	MetaService.Init(context)

	context.Services.SecretFrames = SecretFrameService
	lifecycle:Add("secret frames", SecretFrameService.Destroy)
	SecretFrameService.Init(context)

	setRuntimeState("server_starting", "Встречаем игроков", "players")
	local lifecycleActive = true
	local observedPlayers: { [Player]: boolean } = {}
	local characterConnections: { [Player]: RBXScriptConnection } = {}
	local playerAddedConnection: RBXScriptConnection? = nil
	local playerRemovingConnection: RBXScriptConnection? = nil
	lifecycle:Add("player lifecycle", function()
		lifecycleActive = false
		if playerAddedConnection then
			playerAddedConnection:Disconnect()
			playerAddedConnection = nil
		end
		if playerRemovingConnection then
			playerRemovingConnection:Disconnect()
			playerRemovingConnection = nil
		end
		for player, connection in characterConnections do
			connection:Disconnect()
			characterConnections[player] = nil
		end
		table.clear(observedPlayers)
	end)

	local function onCharacterAdded(player: Player, character: Model): ()
		if not lifecycleActive or player.Parent ~= Players then
			return
		end
		RoundService.HandleCharacter(player, character)
	end

	local function onPlayerAdded(player: Player): ()
		if not lifecycleActive or observedPlayers[player] then
			return
		end
		observedPlayers[player] = true
		player:SetAttribute("AuraRushProfileState", "profile_loading")
		player:SetAttribute("AuraRushProfileDetail", "Загружаем твой стиль")
		player:SetAttribute("AuraRushProfileFailureCode", nil)
		characterConnections[player] = player.CharacterAdded:Connect(function(character)
			local characterOk, characterMessage = xpcall(function()
				onCharacterAdded(player, character)
			end, debug.traceback)
			if not characterOk then
				warn(
					string.format(
						"[AuraRush/Character] setup failed for %s:\n%s",
						player.Name,
						tostring(characterMessage)
					)
				)
			end
		end)
		local initialCharacter = player.Character
		if initialCharacter then
			local characterOk, characterMessage = xpcall(function()
				onCharacterAdded(player, initialCharacter)
			end, debug.traceback)
			if not characterOk then
				warn(
					string.format(
						"[AuraRush/Character] initial setup failed for %s:\n%s",
						player.Name,
						tostring(characterMessage)
					)
				)
			end
		end

		task.spawn(function()
			local profileStartedAt = os.clock()
			local profileOk, profileMessage = xpcall(function()
				local writable = DataService.Load(player)
				if not lifecycleActive or player.Parent ~= Players then
					if DataService.IsLoaded(player) then
						DataService.Release(player)
					end
					return
				end
				local analyticsOk, analyticsMessage = xpcall(function()
					local profile = DataService.GetProfile(player)
					local roundsPlayed = if profile and type(profile.stats) == "table"
						then math.max(0, math.floor(tonumber(profile.stats.roundsPlayed) or 0))
						else 0
					local onboardingRequired = roundsPlayed == 0
						or not profile
						or type(profile.settings) ~= "table"
						or profile.settings.onboardingComplete ~= true
					AnalyticsService.BeginSession(player, onboardingRequired, {
						schemaVersion = tostring(DataService.GetSchemaVersion()),
						readOnly = tostring(DataService.IsReadOnly(player)),
					})
					if onboardingRequired then
						AnalyticsService.Onboarding(player, 1, "Joined Game", {
							schemaVersion = tostring(DataService.GetSchemaVersion()),
						})
					end
				end, debug.traceback)
				if not analyticsOk then
					warn(
						string.format(
							"[AuraRush/Analytics] join telemetry failed for %s:\n%s",
							player.Name,
							tostring(analyticsMessage)
						)
					)
				end
				if writable then
					CelebrationService.RecoverPending(player)
				end
				FirstMiracleService.Resume(player)
				ProgressionService.EnsureMasteryUnlocks(player)
				QuestService.RefreshPlayer(player)
				PartyService.RefreshPlayer(player)
				RemoteService.FireClient("ProgressUpdate", player, {
					kind = "Profile",
					profile = DataService.GetClientView(player),
				})
				RemoteService.FireClient("RoundSnapshot", player, RoundService.GetSnapshot(player))
				MetaService.Push(player, "Loaded")
			end, debug.traceback)

			if not lifecycleActive or player.Parent ~= Players then
				if DataService.IsLoaded(player) then
					DataService.Release(player)
				end
				return
			end

			if profileOk then
				local profileDurationMilliseconds =
					math.max(0, math.floor((os.clock() - profileStartedAt) * 1000 + 0.5))
				player:SetAttribute("AuraRushProfileDetail", "Стиль загружен")
				player:SetAttribute("AuraRushProfileState", "profile_ready")
				player:SetAttribute("AuraRushProfileReadyAt", workspace:GetServerTimeNow())
				print(
					string.format(
						"[AuraRush][Performance] ProfileReady=%dms readOnly=%s",
						profileDurationMilliseconds,
						tostring(DataService.IsReadOnly(player))
					)
				)
			else
				local profileFailureMessage = tostring(profileMessage)
				local code = "P-" .. string.sub(failureCode(profileFailureMessage), 3)
				player:SetAttribute("AuraRushProfileFailureCode", code)
				player:SetAttribute(
					"AuraRushProfileDetail",
					"Профиль не загрузился. Перезайди · " .. code
				)
				player:SetAttribute("AuraRushProfileState", "profile_failed")
				warn(
					string.format(
						"[AuraRush/Profile:%s] initialization failed for %s:\n%s",
						code,
						player.Name,
						profileFailureMessage
					)
				)
			end
		end)
	end

	local function onPlayerRemoving(player: Player): ()
		observedPlayers[player] = nil
		local characterConnection = characterConnections[player]
		if characterConnection then
			characterConnection:Disconnect()
			characterConnections[player] = nil
		end
		local profile = DataService.GetProfile(player)
		local onboardingStage = "profile_unavailable"
		if profile and type(profile.firstMiracle) == "table" then
			onboardingStage = tostring(profile.firstMiracle.status or "unknown")
		elseif profile and type(profile.settings) == "table" then
			onboardingStage = if profile.settings.onboardingComplete == true
				then "complete"
				else "unknown"
		end
		local analyticsOk, analyticsMessage = xpcall(function()
			AnalyticsService.EndSession(player, onboardingStage)
		end, debug.traceback)
		if not analyticsOk then
			warn(
				string.format(
					"[AuraRush/Analytics] leave telemetry failed for %s:\n%s",
					player.Name,
					tostring(analyticsMessage)
				)
			)
		end
		DataService.Release(player)
	end

	playerAddedConnection = Players.PlayerAdded:Connect(onPlayerAdded)
	playerRemovingConnection = Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	DataService.StartAutosave()
	RoundService.Start()

	setRuntimeState("server_ready", "Район готов", "ready")
	runtimeState:SetAttribute("ServerReadyAt", workspace:GetServerTimeNow())
	local serverBootDurationMilliseconds =
		math.max(0, math.floor((os.clock() - serverBootStartedAt) * 1000 + 0.5))
	runtimeState:SetAttribute("ServerBootDurationMs", serverBootDurationMilliseconds)
	print(string.format("[AuraRush][Performance] ServerBoot=%dms", serverBootDurationMilliseconds))

	game:BindToClose(function()
		runLifecycleCleanup("shutdown")
	end)

	print(
		string.format(
			"[AuraRush] REMIX CITY server booted (schema v%d, client v%d)",
			Config.SchemaVersion,
			Config.ClientVersion
		)
	)
end

local ok, message = xpcall(boot, debug.traceback)
if not ok then
	local failureMessage = tostring(message)
	local code = failureCode(failureMessage)
	runtimeState:SetAttribute("ServerFailureCode", code)
	setRuntimeState(
		"server_failed",
		"Сервер не запустился. Перезайди через минуту · "
			.. code,
		"failed"
	)
	warn(string.format("[AuraRush/Boot:%s] server bootstrap failed:\n%s", code, failureMessage))
	runLifecycleCleanup("boot_failure")
end
