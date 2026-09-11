--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local serverRoot = ServerScriptService:WaitForChild("AuraRushServer")
local servicesRoot = serverRoot:WaitForChild("Services")
local analyticsModule = servicesRoot:WaitForChild("AnalyticsService")
local AnalyticsService = require(analyticsModule)

local checks = 0
local function check(condition: boolean, message: string): ()
	assert(condition, "AURA RUSH analytics lifecycle failure: " .. message)
	checks += 1
end

AnalyticsService.Init({
	Config = {
		AnalyticsEnabled = true,
		FeatureFlags = { Analytics = true },
	},
	Services = {
		Flags = {
			IsEnabled = function(_key: string): boolean
				return true
			end,
		},
	},
})

local baseline = AnalyticsService.GetStudioEventCount()
local newcomer: any = { Name = "AnalyticsNewcomer", Parent = Players }
AnalyticsService.BeginSession(newcomer, true, { schemaVersion = "7", readOnly = "false" })
check(
	AnalyticsService.GetStudioEventCount() == baseline + 2,
	"newcomer must emit one join and one onboarding start"
)
check(
	AnalyticsService.LogOnce(newcomer, "first_core_action", 1, nil, "first_core_action"),
	"first once-only event was rejected"
)
check(
	not AnalyticsService.LogOnce(newcomer, "first_core_action", 1, nil, "first_core_action"),
	"duplicate once-only event was accepted"
)
check(
	AnalyticsService.GetStudioEventCount() == baseline + 3,
	"once-only event count is not deduplicated"
)
AnalyticsService.CompleteOnboarding(newcomer, { reason = "actions_complete" })
AnalyticsService.CompleteOnboarding(newcomer, { reason = "duplicate" })
check(
	AnalyticsService.GetStudioEventCount() == baseline + 4,
	"onboarding completion was not deduplicated"
)
AnalyticsService.EndSession(newcomer, "Complete")
check(
	AnalyticsService.GetStudioEventCount() == baseline + 4,
	"completed onboarding was incorrectly recorded as abandonment"
)

local returning: any = { Name = "AnalyticsReturning", Parent = Players }
AnalyticsService.BeginSession(returning, false, { schemaVersion = "7" })
AnalyticsService.EndSession(returning, "complete")
check(
	AnalyticsService.GetStudioEventCount() == baseline + 5,
	"returning player must emit only join lifecycle telemetry"
)

local abandoning: any = { Name = "AnalyticsAbandoning", Parent = Players }
AnalyticsService.BeginSession(abandoning, true, nil)
AnalyticsService.EndSession(abandoning, "Actions")
AnalyticsService.EndSession(abandoning, "Actions")
check(
	AnalyticsService.GetStudioEventCount() == baseline + 8,
	"tutorial abandonment must emit exactly once after join and onboarding start"
)

local analyticsSource = (analyticsModule :: ModuleScript).Source
for _, token in
	{
		"session_milestone",
		"tutorial_abandonment",
		"onboarding_complete",
		"SESSION_MILESTONES",
		"5m",
		"15m",
		"30m",
	}
do
	check(string.find(analyticsSource, token, 1, true) ~= nil, `analytics token missing: {token}`)
end

local bootstrap = serverRoot:WaitForChild("Bootstrap")
local bootstrapSource = (bootstrap :: Script).Source
local beginSessionPosition = string.find(bootstrapSource, "AnalyticsService.BeginSession", 1, true)
local resumePosition = string.find(bootstrapSource, "FirstMiracleService.Resume", 1, true)
check(
	beginSessionPosition ~= nil and resumePosition ~= nil and beginSessionPosition < resumePosition,
	"analytics session starts after resumable onboarding work"
)
check(
	string.find(bootstrapSource, 'AnalyticsService.Log(player, "onboarding_start"', 1, true) == nil,
	"bootstrap still logs onboarding start for every returning player"
)
check(
	string.find(bootstrapSource, "AnalyticsService.EndSession", 1, true) ~= nil,
	"player removal does not finalize session telemetry"
)

local firstMiracleSource = (servicesRoot:WaitForChild("FirstMiracleService") :: ModuleScript).Source
for _, token in { "first_core_action", "first_reward", "CompleteOnboarding" } do
	check(
		string.find(firstMiracleSource, token, 1, true) ~= nil,
		`First Miracle lifecycle token missing: {token}`
	)
end

local roundSource = (servicesRoot:WaitForChild("RoundService") :: ModuleScript).Source
for _, token in { "queue_start", "round_start", "round_complete", "participantBucket" } do
	check(string.find(roundSource, token, 1, true) ~= nil, `round lifecycle token missing: {token}`)
end
check(
	string.find(roundSource, "if previousState ~= nextState then", 1, true) ~= nil,
	"repeated phase states can still duplicate custom telemetry"
)

AnalyticsService.Destroy()
print(`AURA_RUSH_ANALYTICS_LIFECYCLE_PASS ({checks} checks)`)
