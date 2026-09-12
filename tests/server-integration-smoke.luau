--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local serverRoot = ServerScriptService:WaitForChild("AuraRushServer")
local servicesRoot = serverRoot:WaitForChild("Services")

local checks = 0
local function check(condition: boolean, message: string): ()
	assert(condition, "AURA RUSH server integration failure: " .. message)
	checks += 1
end

local function stage(name: string): ()
	print("AURA_RUSH_SERVER_INTEGRATION_STAGE " .. name)
end

local function load(root: Instance, name: string): any
	local module = root:FindFirstChild(name, true)
	check(module ~= nil and module:IsA("ModuleScript"), `module missing: {name}`)
	return require(module :: ModuleScript)
end

local Config = load(sharedRoot, "Config")
local RemotesDefinition = load(sharedRoot, "Remotes")
local BriefCatalog = load(sharedRoot, "BriefCatalog")
local StyleCatalog = load(sharedRoot, "StyleCatalog")
local RemixCatalog = load(sharedRoot, "RemixCatalog")
local PremiumCityCatalog = load(sharedRoot, "PremiumCityCatalog")
local StyleChemistry = load(sharedRoot, "StyleChemistry")
local ArtDirectionRegistry = load(sharedRoot, "ArtDirectionRegistry")
local LiveOpsManifest = load(sharedRoot, "LiveOpsManifest")
local ProductionAssetManifest = load(sharedRoot, "ProductionAssetManifest")
local ProductCatalog = load(sharedRoot, "ProductCatalog")
local StaffPolicy = load(sharedRoot, "StaffPolicy")

local RemoteService = load(servicesRoot, "RemoteService")
local FeatureFlagService = load(servicesRoot, "FeatureFlagService")
local PerformanceService = load(servicesRoot, "PerformanceService")
local ProductionAssetService = load(servicesRoot, "ProductionAssetService")
local PartyService = load(servicesRoot, "PartyService")
local DataService = load(servicesRoot, "DataService")
local EconomyService = load(servicesRoot, "EconomyService")
local ProgressionService = load(servicesRoot, "ProgressionService")
local QuestService = load(servicesRoot, "QuestService")
local LiveOpsService = load(servicesRoot, "LiveOpsService")
local CommunityBloomService = load(servicesRoot, "CommunityBloomService")
local WorldService = load(servicesRoot, "WorldService")
local ChallengeService = load(servicesRoot, "ChallengeService")
local StyleService = load(servicesRoot, "StyleService")
local RemixCityService = load(servicesRoot, "RemixCityService")
local CityPulseService = load(servicesRoot, "CityPulseService")
local RewardService = load(servicesRoot, "RewardService")
local AnalyticsService = load(servicesRoot, "AnalyticsService")
local PurchaseService = load(servicesRoot, "PurchaseService")
local RunDirectorService = load(servicesRoot, "RunDirectorService")
local AuraGenomeService = load(servicesRoot, "AuraGenomeService")
local RoundService = load(servicesRoot, "RoundService")
local SocialCreationService = load(servicesRoot, "SocialCreationService")
local CelebrationService = load(servicesRoot, "CelebrationService")
local FirstMiracleService = load(servicesRoot, "FirstMiracleService")
local MetaService = load(servicesRoot, "MetaService")
local SecretFrameService = load(servicesRoot, "SecretFrameService")
local AdminService = load(servicesRoot, "AdminService")

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

local world: Model? = nil
local initOk, initMessage = xpcall(function()
	stage("network")
	context.Services.Remote = RemoteService
	RemoteService.Init(context)
	context.Services.Flags = FeatureFlagService
	FeatureFlagService.Init(context)
	context.Services.Performance = PerformanceService
	PerformanceService.Init(context)
	context.Services.ProductionAssets = ProductionAssetService
	ProductionAssetService.Init(context)
	context.Services.Party = PartyService
	PartyService.Init(context)

	stage("world")
	context.Services.World = WorldService
	WorldService.Init(context)
	world = PerformanceService.Measure("Integration.WorldBuild", WorldService.Build)
	ProductionAssetService.Preload(world :: Model)

	stage("data")
	context.Services.Data = DataService
	DataService.Init(context)
	context.Services.Analytics = AnalyticsService
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
	CommunityBloomService.Init(context)

	stage("gameplay")
	context.Services.Style = StyleService
	StyleService.Init(context)
	context.Services.CityPulse = CityPulseService
	CityPulseService.Init(context)
	context.Services.Remix = RemixCityService
	RemixCityService.Init(context)
	context.Services.Challenge = ChallengeService
	ChallengeService.Init(context)
	ChallengeService.BindWorld()
	context.Services.Reward = RewardService
	RewardService.Init(context)
	stage("commerce")
	context.Services.Purchase = PurchaseService
	PurchaseService.Init(context)
	context.Services.RunDirector = RunDirectorService
	context.Services.AuraGenome = AuraGenomeService
	context.Services.Round = RoundService
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
	SecretFrameService.Init(context)
	context.Services.Admin = AdminService
	AdminService.Init(context)

	stage("round")
	RoundService.Start()
	task.wait(0.35)
	stage("initialized")
end, debug.traceback)

local worldWasBuilt = world ~= nil and world.Parent == workspace
local hubWasBuilt = world ~= nil and world:FindFirstChild("Hub") ~= nil
local secretFramesWereBuilt = #WorldService.GetSecretFrames() == #PremiumCityCatalog.SecretFrames
local remoteFolder = ReplicatedStorage:FindFirstChild(RemotesDefinition.FolderName)
local remoteContractWasReady = remoteFolder ~= nil
	and remoteFolder:GetAttribute("ContractReady") == true
	and remoteFolder:GetAttribute("ContractVersion") == RemotesDefinition.Version
local adminPolicy = AdminService.GetPolicySummary()
local operationsView = RoundService.GetOperationsView()
local fakeOwner: any = {
	UserId = 910001,
	GetRankInGroup = function(): number
		return 0
	end,
}
local fakeAdmin: any = {
	UserId = 910002,
	GetRankInGroup = function(): number
		return 200
	end,
}
local explicitOwnerConfig = {
	Enabled = true,
	OwnerUserIds = { 910001 },
	GroupId = 0,
	GroupRanks = {},
}
local groupAdminConfig = {
	Enabled = true,
	OwnerUserIds = {},
	GroupId = 1,
	GroupRanks = { Admin = 200, Moderator = 100, Support = 50 },
}

local cleanupErrors = {}
local function cleanup(label: string, callback: () -> ()): ()
	local ok, message = pcall(callback)
	if not ok then
		table.insert(cleanupErrors, label .. ": " .. tostring(message))
	end
end

stage("cleanup")
cleanup("round", RoundService.Destroy)
cleanup("first miracle", FirstMiracleService.Destroy)
cleanup("celebration", CelebrationService.Destroy)
cleanup("social creation", SocialCreationService.Destroy)
cleanup("challenge", ChallengeService.Destroy)
cleanup("style", StyleService.Destroy)
cleanup("remix", RemixCityService.Destroy)
cleanup("city pulse", CityPulseService.Stop)
cleanup("community", CommunityBloomService.Stop)
cleanup("secret frames", SecretFrameService.Destroy)
cleanup("admin operations", AdminService.Destroy)
cleanup("data", DataService.Shutdown)
cleanup("party", PartyService.Destroy)
cleanup("flags", FeatureFlagService.Destroy)
cleanup("performance", PerformanceService.Destroy)
cleanup("analytics", AnalyticsService.Destroy)
cleanup("network", RemoteService.Destroy)

check(initOk, "service graph did not initialize: " .. tostring(initMessage))
check(#cleanupErrors == 0, "cleanup failed: " .. table.concat(cleanupErrors, " | "))
check(worldWasBuilt, "world graph was not built")
check(hubWasBuilt, "integrated world has no hub")
check(secretFramesWereBuilt, "secret frames were not integrated into the world")
check(remoteContractWasReady, "remote contract was not atomically published")
check(#RemotesDefinition.All == 35, "network definition count changed")
check(
	RemotesDefinition.ByName.RequestAdminSnapshot.className == "RemoteFunction",
	"admin snapshot remote has the wrong contract"
)
check(
	RemotesDefinition.ByName.AdminAction.className == "RemoteEvent",
	"admin action remote has the wrong contract"
)
check(adminPolicy.enabled == true and adminPolicy.announcementCount == 2, "admin policy is invalid")
check(
	operationsView.state ~= nil and operationsView.participantCount ~= nil,
	"operations view is invalid"
)
check(StaffPolicy.ResolveRole(fakeOwner, explicitOwnerConfig) == "Owner", "owner policy failed")
check(StaffPolicy.ResolveRole(fakeAdmin, groupAdminConfig) == "Admin", "group policy failed")
check(
	StaffPolicy.Can("Player", "view_dashboard") == false
		and StaffPolicy.Can("Admin", "broadcast_announcement") == true,
	"staff permissions are invalid"
)

local stats = RemoteService.GetStats()
check(next(stats) == nil, "destroy left stale remote counters")

print(`AURA_RUSH_SERVER_INTEGRATION_PASS ({checks} checks)`)
