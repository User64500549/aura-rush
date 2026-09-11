--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")

local checks = 0

print(
	string.format(
		"AURA_RUSH_ENV PlaceId=%s GameId=%s",
		tostring(game.PlaceId),
		tostring(game.GameId)
	)
)

local function check(condition: boolean, message: string): ()
	assert(condition, "AURA RUSH smoke failure: " .. message)
	checks += 1
end

local shared = ReplicatedStorage:FindFirstChild("AuraRushShared")
check(shared ~= nil and shared:IsA("Folder"), "AuraRushShared folder is missing")

local serverRoot = ServerScriptService:FindFirstChild("AuraRushServer")
check(serverRoot ~= nil and serverRoot:IsA("Folder"), "AuraRushServer folder is missing")

local clientRoot = StarterPlayer.StarterPlayerScripts:FindFirstChild("AuraRushClient")
check(clientRoot ~= nil and clientRoot:IsA("Folder"), "AuraRushClient folder is missing")

local loadingShell = ReplicatedFirst:FindFirstChild("AuraRushLoading")
check(
	loadingShell ~= nil and loadingShell:IsA("LocalScript"),
	"ReplicatedFirst loading shell is missing"
)

local serverBootstrap = (serverRoot :: Folder):FindFirstChild("Bootstrap")
check(serverBootstrap ~= nil and serverBootstrap:IsA("Script"), "server Bootstrap is missing")
check(
	string.find(
		(serverBootstrap :: Script).Source,
		'PerformanceService.Measure("ServerBoot.WorldBuild", WorldService.Build)',
		1,
		true
	) ~= nil,
	"server world build is not measured"
)
check(
	string.find((serverBootstrap :: Script).Source, "ServerBootWorldBuildMilliseconds", 1, true)
		~= nil,
	"world-build measurement is not exposed for private-server evidence"
)
check(
	string.find((serverBootstrap :: Script).Source, "[AuraRush][Performance]", 1, true) ~= nil,
	"world-build measurement is missing from server logs"
)

local function requireNamed(root: Instance, name: string): any
	local module = root:FindFirstChild(name, true)
	check(module ~= nil and module:IsA("ModuleScript"), name .. " ModuleScript is missing")
	local ok, result = pcall(require, module :: ModuleScript)
	check(ok, name .. " did not require: " .. tostring(result))
	return result
end

local config = requireNamed(shared :: Instance, "Config")
local briefs = requireNamed(shared :: Instance, "BriefCatalog")
local styles = requireNamed(shared :: Instance, "StyleCatalog")
local remotes = requireNamed(shared :: Instance, "Remotes")
local products = requireNamed(shared :: Instance, "ProductCatalog")

check(config.GameName == "AURA RUSH: СТИЛЬ-РЕЙД", "unexpected game name")
check(config.LegacyGameName == "AURA RUSH", "legacy product name compatibility changed")
check(config.UI.DefaultLocale == "ru", "Russian must be the default UI locale")
check(config.SchemaVersion == 5, "profile schema must be v5")
check(config.ClientVersion >= 5, "v5 client compatibility version must be declared")
check(briefs.CombinationCount == 192, "brief catalog must expose exactly 192 combinations")
local art = requireNamed(shared :: Instance, "ArtDirectionRegistry")
check(art.Count == 6, "art direction registry must expose exactly six worlds")
check(styles.Count >= 60, "style catalog must expose at least 60 items")
check(#remotes.All == 32, "v5 remote contract must contain exactly 32 remotes")
check(remotes.ClientToServer.RemixAction ~= nil, "Remix action remote is missing")
check(remotes.ServerToClient.RemixUpdate ~= nil, "Remix update remote is missing")
check(remotes.ClientToServer.RequestFirstMiracle ~= nil, "First Miracle request remote is missing")
check(remotes.ClientToServer.FirstMiracleAction ~= nil, "First Miracle action remote is missing")
check(remotes.ServerToClient.FirstMiracleUpdate ~= nil, "First Miracle update remote is missing")
check(config.FirstMiracle.MaximumSeconds <= 30, "first visible payoff exceeds 30 seconds")
check(
	config.FirstMiracle.ActionTarget == #config.FirstMiracle.ActionSequence,
	"First Miracle action target does not match its authored sequence"
)
check(#products.DeveloperProducts >= 5, "product catalog is incomplete")
check(products.DeveloperProducts[1].id == 0, "developer product must use the canonical id field")
check(products.Subscriptions[1].id == "", "subscription must use a string id")
local signatureCollection = products.GetProduct("signature_prism_collection")
check(signatureCollection ~= nil, "signature collection is missing")
check(
	signatureCollection.grant.duplicateGlowDustPerItem > 0,
	"repeatable cosmetic collection must compensate owned items"
)

local defaultLoadout = styles.GetDefaultLoadout()
for category, itemId in defaultLoadout do
	local item = styles.GetById(itemId)
	check(item ~= nil and item.category == category, "invalid default item " .. itemId)
	check(styles.IsStarter(itemId), "default item is not unlocked: " .. itemId)
end

-- Require every ModuleScript to catch parse errors and broken local dependencies.
for _, root in { shared :: Instance, serverRoot :: Instance, clientRoot :: Instance } do
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ModuleScript") then
			local ok, result = pcall(require, descendant)
			check(ok, descendant:GetFullName() .. " failed to require: " .. tostring(result))
		end
	end
end

local dataService = requireNamed(serverRoot :: Instance, "DataService")
local roundService = requireNamed(serverRoot :: Instance, "RoundService")
local freshProfile = {
	settings = { onboardingComplete = false },
	firstMiracle = { status = "NotStarted" },
}
local activeMiracleProfile = {
	settings = { onboardingComplete = false },
	firstMiracle = { status = "Actions" },
}
local completedMiracleProfile = {
	settings = { onboardingComplete = false },
	firstMiracle = { status = "Complete" },
}
local freshEligible, freshReason = roundService.EvaluateProfileEligibility(freshProfile, true)
check(
	not freshEligible and freshReason == "first_miracle_incomplete",
	"fresh creator entered too early"
)
local activeEligible = roundService.EvaluateProfileEligibility(activeMiracleProfile, true)
check(activeEligible == false, "creator entered while First Miracle was active")
local completeEligible = roundService.EvaluateProfileEligibility(completedMiracleProfile, true)
check(completeEligible == true, "completed First Miracle did not unlock the round")
local disabledEligible, disabledReason =
	roundService.EvaluateProfileEligibility(freshProfile, false)
check(
	disabledEligible and disabledReason == "first_miracle_disabled",
	"First Miracle kill-switch blocked read-only players"
)
check(roundService.CanJoinInState("BriefChoice"), "pre-act join window is missing")
check(roundService.CanJoinInState("ThreadRun"), "backstage join window is missing")
check(not roundService.CanJoinInState("Results"), "results must not accept late participants")
check(
	not dataService.CanClientCompleteOnboarding(activeMiracleProfile, true),
	"client could bypass First Miracle completion"
)
check(
	dataService.CanClientCompleteOnboarding(activeMiracleProfile, false),
	"disabled First Miracle must preserve welcome-only onboarding"
)
local boundEvents = {}
dataService.Init({
	Config = config,
	StyleCatalog = styles,
	Services = {
		Remote = {
			BindEvent = function(name: string, _rate: number, handler: (...any) -> ())
				boundEvents[name] = handler
			end,
		},
	},
})
check(boundEvents.UpdateSettings ~= nil, "unpublished DataService initialization failed")
check(
	dataService.GetSchemaVersion() == config.SchemaVersion,
	"DataService and Config profile schema versions diverged"
)
check(dataService.ResolveProfileSchemaVersion(3) == 5, "legacy schema was not upgraded")
check(dataService.ResolveProfileSchemaVersion(7) == 7, "future schema was incorrectly downgraded")

local worldService = requireNamed(serverRoot :: Instance, "WorldService")
worldService.Init({})
local world = worldService.Build()
check(world.Name == "AuraRushWorld", "runtime world was not built")
check(#worldService.GetCollectibles() == 8, "Thread Run must contain eight collectibles")
check(#worldService.GetCollectibles("material_surf") == 8, "Material Surf samples are missing")
check(#worldService.GetAllCollectibles() == 16, "unexpected collectible pool size")
check(world:FindFirstChild("Hub") ~= nil, "Hub is missing")
check(world:FindFirstChild("PrismMetro") ~= nil, "Prism Metro finale is missing")
check(world:FindFirstChild("CloudBazaar") ~= nil, "Cloud Bazaar finale is missing")
check(world:FindFirstChild("MoonlitGreenhouse") ~= nil, "Moonlit Greenhouse finale is missing")
check(world:FindFirstChild("OrbitalBoardwalk") ~= nil, "Orbital Boardwalk finale is missing")
check(world:FindFirstChild("VelvetArchive") ~= nil, "Velvet Archive finale is missing")
check(world:FindFirstChild("SolarCathedral") ~= nil, "Solar Cathedral finale is missing")
check(world:FindFirstChild("MaterialSurf") ~= nil, "Material Surf act is missing")
check(world:FindFirstChild("LightLoom") ~= nil, "Light Loom act is missing")
check(world:FindFirstChild("BloomRescue") ~= nil, "Bloom Rescue act is missing")
worldService.TriggerGlowstorm("SmokeTester")
check(workspace:FindFirstChild("AuraRushGlowstorm") ~= nil, "server Glowstorm folder is missing")
check(Lighting:FindFirstChild("AuraRushGlowstormColor") ~= nil, "Glowstorm color effect is missing")
for _, worldId in
	{
		"prism_metro",
		"cloud_bazaar",
		"moonlit_greenhouse",
		"orbital_boardwalk",
		"velvet_archive",
		"solar_cathedral",
	}
do
	check(
		world:FindFirstChild("FinaleCamera_" .. worldId, true) ~= nil,
		"finale camera is missing for " .. worldId
	)
end

print(string.format("AURA_RUSH_" .. "SMOKE_PASS (%d checks)", checks))
