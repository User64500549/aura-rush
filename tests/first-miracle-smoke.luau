--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local servicesRoot = ServerScriptService:WaitForChild("AuraRushServer"):WaitForChild("Services")
local FirstMiracleService = require(servicesRoot:WaitForChild("FirstMiracleService"))

local boundFunctions: { [string]: (any, any) -> any } = {}
local boundEvents: { [string]: (any, any) -> () } = {}
local profiles: { [any]: any } = {}
local readOnlyPlayers: { [any]: boolean } = {}
local remoteUpdates = 0
local saveCount = 0
local flagEnabled = true
local analyticsEvents: { [string]: number } = {}
local analyticsByPlayer: { [any]: { [string]: number } } = {}
local analyticsOnceByPlayer: { [any]: { [string]: boolean } } = {}
local firstInputKinds: { [any]: string } = {}
local roundEnrollments: { [any]: number } = {}

local function newProfile(): any
	return {
		firstMiracle = {
			version = 1,
			status = "NotStarted",
			sessionId = "",
			paletteId = "",
			actionIndex = 0,
			startedAt = 0,
			choiceExpiresAt = 0,
			expiresAt = 0,
			bloomStartedAt = 0,
			completedAt = 0,
			completionReason = "",
			skipped = false,
			rewardClaimed = false,
		},
		glowDust = 0,
		economyStats = { earned = 0, spent = 0 },
		settings = { onboardingComplete = false },
		unlocks = {
			palette = { "palette_prism", "palette_cyan", "palette_sunset" },
			aura = { "aura_spark" },
		},
		equipped = { palette = "palette_prism", aura = "aura_spark" },
		auraAtlas = { Motion = 1 },
		auraAtlasXp = { Motion = 0 },
		ledgers = { grants = { system = {} } },
	}
end

local function contains(values: { string }, target: string): boolean
	for _, value in values do
		if value == target then
			return true
		end
	end
	return false
end

local fakeServices: any = {}
fakeServices.Flags = {
	IsEnabled = function(key: string): boolean
		return key ~= "FirstMiracle" or flagEnabled
	end,
}
fakeServices.Data = {
	GetProfile = function(player: any): any
		return profiles[player]
	end,
	GetClientView = function(player: any): any
		return profiles[player]
	end,
	IsReadOnly = function(player: any): boolean
		return readOnlyPlayers[player] == true
	end,
	Update = function(player: any, mutator: (any) -> ()): boolean
		local profile = profiles[player]
		if not profile then
			return false
		end
		mutator(profile)
		return true
	end,
	Save = function(_player: any): boolean
		saveCount += 1
		return true
	end,
}
fakeServices.Remote = {
	BindFunction = function(name: string, _rate: number, callback: (any, any) -> any)
		boundFunctions[name] = callback
	end,
	BindEvent = function(name: string, _rate: number, callback: (any, any) -> ())
		boundEvents[name] = callback
	end,
	FireClient = function(_name: string, _player: any, _payload: any)
		remoteUpdates += 1
	end,
}
fakeServices.Style = {
	SetChoice = function(player: any, category: string, itemId: string): (boolean, string?)
		profiles[player].equipped[category] = itemId
		return true, nil
	end,
	ApplyToCharacter = function(_player: any) end,
}
fakeServices.AuraGenome = {
	Capture = function(_player: any, _style: any): any
		return { fingerprint = "first-miracle-smoke" }
	end,
}
fakeServices.Progression = {
	ApplySchoolXp = function(profile: any, school: string, amount: number): any
		profile.auraAtlasXp[school] = (profile.auraAtlasXp[school] or 0) + amount
		return { ok = true, school = school, xp = amount }
	end,
}
fakeServices.Economy = {
	GrantCurrency = function(
		player: any,
		_kind: string,
		grantId: string,
		amount: number,
		mutator: (any) -> any
	): any
		local profile = profiles[player]
		local ledger = profile.ledgers.grants.system
		if ledger[grantId] then
			return { ok = true, alreadyApplied = true, amount = 0 }
		end
		ledger[grantId] = os.time()
		profile.glowDust += amount
		profile.economyStats.earned += amount
		local result = mutator(profile)
		return { ok = true, alreadyApplied = false, amount = amount, result = result }
	end,
}
local function recordAnalytics(player: any, name: string, fields: any): ()
	analyticsEvents[name] = (analyticsEvents[name] or 0) + 1
	local counts = analyticsByPlayer[player] or {}
	analyticsByPlayer[player] = counts
	counts[name] = (counts[name] or 0) + 1
	if name == "first_input" then
		firstInputKinds[player] = fields.input
	end
end

fakeServices.Analytics = {
	Log = function(player: any, name: string, _value: number, fields: any)
		recordAnalytics(player, name, fields)
	end,
	LogOnce = function(
		player: any,
		name: string,
		_value: number,
		fields: any,
		dedupeKey: string
	): boolean
		local once = analyticsOnceByPlayer[player] or {}
		analyticsOnceByPlayer[player] = once
		if once[dedupeKey] then
			return false
		end
		once[dedupeKey] = true
		recordAnalytics(player, name, fields)
		return true
	end,
	CompleteOnboarding = function(player: any, fields: any)
		fakeServices.Analytics.LogOnce(
			player,
			"onboarding_complete",
			1,
			fields,
			"onboarding_complete"
		)
	end,
	Onboarding = function(_player: any, _step: number, _name: string, _fields: any) end,
}
fakeServices.Round = {
	TryEnrollLateJoin = function(player: any): boolean
		roundEnrollments[player] = (roundEnrollments[player] or 0) + 1
		return true
	end,
}

local testConfig = {
	FeatureFlags = { FirstMiracle = true },
	FirstMiracle = {
		Enabled = true,
		MaximumSeconds = 30,
		ChoiceSeconds = 4,
		ActionTarget = 3,
		ActionCooldownSeconds = 0.1,
		BloomSeconds = 2,
		CompletionGlowDust = 100,
		CompletionAtlasXp = 80,
		CompletionAtlasSchool = "Motion",
		CompletionAuraId = "aura_first_miracle",
		PaletteChoices = {
			{
				id = "palette_prism",
				nameKey = "first_miracle.palette.prism",
				colors = { "#1", "#2", "#3" },
			},
			{
				id = "palette_cyan",
				nameKey = "first_miracle.palette.cyan",
				colors = { "#1", "#2", "#3" },
			},
			{
				id = "palette_sunset",
				nameKey = "first_miracle.palette.sunset",
				colors = { "#1", "#2", "#3" },
			},
		},
		ActionSequence = {
			{ id = "collect_thread", nameKey = "first_miracle.action.collect_thread" },
			{ id = "tune_pulse", nameKey = "first_miracle.action.tune_pulse" },
			{ id = "focus_prism", nameKey = "first_miracle.action.focus_prism" },
		},
	},
}

FirstMiracleService.Init({ Config = testConfig, Services = fakeServices })
assert(boundFunctions.RequestFirstMiracle ~= nil, "RequestFirstMiracle was not bound")
assert(boundEvents.FirstMiracleAction ~= nil, "FirstMiracleAction was not bound")
local spatialContract = FirstMiracleService.GetSpatialContract()
assert(#spatialContract == 3, "First Miracle spatial contract must expose three world steps")
local spatialChecks: { [string]: boolean } = {}
local spatialVerbs: { [string]: boolean } = {}
for _, step in spatialContract do
	assert(not spatialChecks[step.check], "spatial checks must be distinct")
	assert(not spatialVerbs[step.verb], "spatial verbs must be distinct")
	spatialChecks[step.check] = true
	spatialVerbs[step.verb] = true
end

local player: any = { Parent = Players, UserId = 101, DisplayName = "Smoke Creator" }
profiles[player] = newProfile()
local started = boundFunctions.RequestFirstMiracle(player, {})
assert(started.status == "PaletteChoice", "miracle did not start in PaletteChoice")
assert(started.required == true and started.enabled == true, "miracle start flags are invalid")
assert(
	started.expiresAt - profiles[player].firstMiracle.startedAt <= 30,
	"miracle exceeds 30 seconds"
)
assert(#started.choices == 3 and #started.actions == 3, "miracle content contract is incomplete")
assert(
	started.spatial.legacyFallback == true,
	"plain-table smoke player did not retain compatibility fallback"
)

boundEvents.FirstMiracleAction(player, { action = "ChoosePalette", paletteId = "not_allowlisted" })
assert(profiles[player].firstMiracle.status == "PaletteChoice", "invalid palette was accepted")
assert(analyticsEvents.first_input == nil, "invalid palette fabricated first input")
boundEvents.FirstMiracleAction(player, { action = "ChoosePalette", paletteId = "palette_cyan" })
assert(profiles[player].firstMiracle.status == "Actions", "valid palette was not accepted")
assert(profiles[player].equipped.palette == "palette_cyan", "chosen palette was not equipped")
local actionView = FirstMiracleService.GetView(player)
assert(
	actionView.spatial.enabled == false and actionView.spatial.check == "world_distance",
	"world-step view contract is invalid"
)

boundEvents.FirstMiracleAction(player, { action = "PerformAction", actionId = "focus_prism" })
assert(profiles[player].firstMiracle.actionIndex == 0, "out-of-order action was accepted")
for _, actionId in { "collect_thread", "tune_pulse", "focus_prism" } do
	boundEvents.FirstMiracleAction(player, { action = "PerformAction", actionId = actionId })
	task.wait(0.12)
end
assert(profiles[player].firstMiracle.status == "Bloom", "three actions did not begin Bloom")
task.wait(2.1)
assert(profiles[player].firstMiracle.status == "Complete", "Bloom did not complete")
assert(profiles[player].firstMiracle.rewardClaimed == true, "reward was not marked claimed")
assert(profiles[player].glowDust == 100, "First Miracle GlowDust amount changed")
assert(profiles[player].auraAtlasXp.Motion == 80, "First Miracle Motion XP amount changed")
assert(contains(profiles[player].unlocks.aura, "aura_first_miracle"), "milestone aura missing")
assert(profiles[player].equipped.aura == "aura_first_miracle", "milestone aura was not equipped")
assert(profiles[player].settings.onboardingComplete == true, "onboarding was not completed")
assert(roundEnrollments[player] == 1, "completed creator was not handed into the live round")
assert(analyticsEvents.first_input == 1, "first input funnel step was not logged once")
assert(analyticsEvents.first_core_action == 1, "first core action was not logged once")
assert(firstInputKinds[player] == "palette", "manual first input lost its source")
assert(analyticsEvents.first_movement == 1, "first movement funnel step was not logged once")
assert(
	analyticsEvents.first_world_reaction == 1,
	"first world reaction funnel step was not logged once"
)
assert(analyticsEvents.onboarding_complete == 1, "onboarding completion was not logged once")
assert(analyticsEvents.first_reward == 1, "first durable reward was not logged once")

boundEvents.FirstMiracleAction(player, { action = "Skip" })
task.wait(0.1)
assert(profiles[player].glowDust == 100, "duplicate completion granted currency twice")
assert(analyticsEvents.first_reward == 1, "duplicate completion duplicated first reward telemetry")

local skippedPlayer: any = { Parent = Players, UserId = 102, DisplayName = "Skip Creator" }
profiles[skippedPlayer] = newProfile()
boundFunctions.RequestFirstMiracle(skippedPlayer, {})
boundEvents.FirstMiracleAction(skippedPlayer, { action = "Skip" })
assert(profiles[skippedPlayer].firstMiracle.status == "Bloom", "skip did not begin inclusive Bloom")
task.wait(2.1)
assert(profiles[skippedPlayer].glowDust == 100, "skip path lost the guaranteed reward")

local disabledPlayer: any = { Parent = Players, UserId = 103, DisplayName = "Disabled Creator" }
profiles[disabledPlayer] = newProfile()
flagEnabled = false
local disabled = boundFunctions.RequestFirstMiracle(disabledPlayer, {})
assert(
	disabled.enabled == false and disabled.required == false,
	"kill switch did not disable miracle"
)
assert(
	profiles[disabledPlayer].firstMiracle.status == "NotStarted",
	"disabled miracle mutated profile"
)
flagEnabled = true

local readOnlyPlayer: any = { Parent = Players, UserId = 104, DisplayName = "ReadOnly Creator" }
profiles[readOnlyPlayer] = newProfile()
readOnlyPlayers[readOnlyPlayer] = true
boundFunctions.RequestFirstMiracle(readOnlyPlayer, {})
boundEvents.FirstMiracleAction(readOnlyPlayer, { action = "Skip" })
task.wait(2.1)
assert(
	profiles[readOnlyPlayer].firstMiracle.status == "Complete",
	"read-only demo stalled in Bloom"
)

assert(remoteUpdates > 0, "FirstMiracleUpdate was never sent")
assert(saveCount > 0, "durable completion did not request a save")

local timeoutPlayer: any = { Parent = Players, UserId = 105, DisplayName = "Timeout Creator" }
profiles[timeoutPlayer] = newProfile()
boundFunctions.RequestFirstMiracle(timeoutPlayer, {})
task.wait(4.1)
assert(profiles[timeoutPlayer].firstMiracle.status == "Actions", "palette timeout stalled")
assert(
	analyticsByPlayer[timeoutPlayer].first_miracle_palette == 1,
	"automatic palette was not recorded as a fallback"
)
assert(
	analyticsByPlayer[timeoutPlayer].first_input == nil,
	"automatic palette fabricated player input"
)
boundEvents.FirstMiracleAction(
	timeoutPlayer,
	{ action = "PerformAction", actionId = "focus_prism" }
)
assert(analyticsByPlayer[timeoutPlayer].first_input == nil, "rejected action fabricated input")
boundEvents.FirstMiracleAction(
	timeoutPlayer,
	{ action = "PerformAction", actionId = "collect_thread" }
)
assert(analyticsByPlayer[timeoutPlayer].first_input == 1, "input after automatic palette was lost")
assert(firstInputKinds[timeoutPlayer] == "world_action", "world input lost its source")
task.wait(0.12)
boundEvents.FirstMiracleAction(timeoutPlayer, { action = "PerformAction", actionId = "tune_pulse" })
boundEvents.FirstMiracleAction(
	timeoutPlayer,
	{ action = "ChoosePalette", paletteId = "palette_cyan" }
)
assert(
	analyticsByPlayer[timeoutPlayer].first_input == 1,
	"subsequent actions duplicated first input"
)

local resumedPlayer: any = { Parent = Players, UserId = 106, DisplayName = "Resume Creator" }
profiles[resumedPlayer] = newProfile()
local resumedState = profiles[resumedPlayer].firstMiracle
resumedState.status = "PaletteChoice"
resumedState.sessionId = "resume-choice-timeout-smoke"
resumedState.choiceExpiresAt = os.time() - 1
resumedState.expiresAt = os.time() + 25
FirstMiracleService.Resume(resumedPlayer)
assert(resumedState.status == "Actions", "expired resumed palette stalled")
assert(analyticsByPlayer[resumedPlayer].first_input == nil, "resumed timeout fabricated input")
print("AURA_RUSH_FIRST_MIRACLE_" .. "SMOKE_PASS")
