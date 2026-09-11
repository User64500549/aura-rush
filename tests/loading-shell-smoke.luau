--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local checks = 0
local function check(condition: boolean, message: string): ()
	assert(condition, "AURA RUSH loading shell failure: " .. message)
	checks += 1
end

local loadingShell = ReplicatedFirst:FindFirstChild("AuraRushLoading")
check(loadingShell ~= nil, "AuraRushLoading is missing from ReplicatedFirst")
check(loadingShell:IsA("LocalScript"), "AuraRushLoading is not a LocalScript")

local loadingSource = (loadingShell :: LocalScript).Source
for _, token in
	{
		"RemoveDefaultLoadingScreen",
		"AuraRushBootUI",
		"AuraRushBootState",
		"client_starting",
		"ready",
		"failed",
		"AuraRushRuntimeState",
		"server_ready",
		"server_failed",
		"ServerDetail",
		"AuraRushProfileState",
		"profile_ready",
		"profile_failed",
		"EntryReady",
		"ЗАГРУЗКА ИДЁТ ДОЛЬШЕ ОБЫЧНОГО",
		"РАЙОН НЕ ОТВЕЧАЕТ",
		"ReducedMotionEnabled",
	}
do
	check(string.find(loadingSource, token, 1, true) ~= nil, `loading token is missing: {token}`)
end
check(
	string.find(loadingSource, "rbxassetid://", 1, true) == nil,
	"entry screen depends on a remote asset"
)
check(
	string.find(loadingSource, "RunService.RenderStepped", 1, true) == nil,
	"entry screen uses an unnecessary per-frame loop"
)
check(
	string.find(loadingSource, 'and profileState == "profile_ready"', 1, true) ~= nil,
	"entry screen closes before the player profile is ready"
)
check(
	string.find(loadingSource, 'SetAttribute("ServerState"', 1, true) == nil,
	"client loading shell tries to author server state"
)
check(
	string.find(loadingSource, "ReplicatedStorage.ChildAdded:Connect", 1, true) ~= nil,
	"late server-state replication is not observed"
)

local clientRoot = StarterPlayer.StarterPlayerScripts:FindFirstChild("AuraRushClient")
check(clientRoot ~= nil and clientRoot:IsA("Folder"), "client root is missing")
local bootstrap = (clientRoot :: Folder):FindFirstChild("Bootstrap")
check(bootstrap ~= nil and bootstrap:IsA("LocalScript"), "client bootstrap is missing")
local bootstrapSource = (bootstrap :: LocalScript).Source
check(
	string.find(bootstrapSource, "xpcall(boot, debug.traceback)", 1, true) ~= nil,
	"client boot has no top-level failure boundary"
)
check(
	string.find(bootstrapSource, 'SetAttribute("AuraRushBootState", "ready")', 1, true) ~= nil,
	"client boot never signals readiness"
)
check(
	string.find(bootstrapSource, 'SetAttribute("AuraRushBootState", "failed")', 1, true) ~= nil,
	"client boot never signals failure"
)
check(
	string.find(bootstrapSource, "network contract unavailable", 1, true) ~= nil,
	"client can report ready with an incomplete network contract"
)
check(
	string.find(bootstrapSource, "ClientBoot=", 1, true) ~= nil,
	"client boot duration has no runtime evidence"
)

local serverRoot = ServerScriptService:FindFirstChild("AuraRushServer")
check(serverRoot ~= nil and serverRoot:IsA("Folder"), "server root is missing")
local serverBootstrap = (serverRoot :: Folder):FindFirstChild("Bootstrap")
check(serverBootstrap ~= nil and serverBootstrap:IsA("Script"), "server bootstrap is missing")
local serverSource = (serverBootstrap :: Script).Source
local serverBootStart = string.find(serverSource, "local function boot(): ()", 1, true)
local firstServiceRequire = string.find(serverSource, "local Config = require", 1, true)
local serverBoundary = string.find(serverSource, "xpcall(boot, debug.traceback)", 1, true)
check(
	serverBootStart ~= nil
		and firstServiceRequire ~= nil
		and serverBoundary ~= nil
		and serverBootStart < firstServiceRequire
		and firstServiceRequire < serverBoundary,
	"server module loading is outside the failure boundary"
)
for _, token in
	{
		"AuraRushRuntimeState",
		"server_starting",
		"server_ready",
		"server_failed",
		"ServerFailureCode",
		"ServerStep",
		"AuraRushProfileState",
		"profile_loading",
		"profile_ready",
		"profile_failed",
		"AuraRushProfileFailureCode",
		"local profileOk, profileMessage = xpcall",
		"[AuraRush/Boot:%s]",
		"ServerBootDurationMs",
		"ProfileReady=",
	}
do
	check(string.find(serverSource, token, 1, true) ~= nil, `server boot token is missing: {token}`)
end
check(
	string.find(serverSource, "[AuraRush/Profile:%s]", 1, true) ~= nil,
	"profile initialization failure has no server evidence"
)
check(
	string.find(serverSource, "local analyticsOk, analyticsMessage = xpcall", 1, true) ~= nil,
	"non-critical analytics can block player initialization"
)

print(`AURA_RUSH_LOADING_SHELL_PASS ({checks} checks)`)
