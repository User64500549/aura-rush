--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local DataStoreRetry = require(script.Parent.Parent.Util.DataStoreRetry)

local DataService = {}

export type Profile = {
	schemaVersion: number,
	glowDust: number,
	unlocks: { [string]: { string } },
	equipped: { [string]: string },
	savedLooks: { any },
	auraAtlas: { [string]: number },
	auraAtlasXp: { [string]: number },
	progression: any,
	achievements: { [string]: boolean },
	seasonProgress: number,
	quests: any,
	liveOps: any,
	activationTokens: { [string]: number },
	pendingActivations: { [string]: any },
	postcards: { any },
	atelier: any,
	firstMiracle: any,
	remixCity: any,
	grantLedger: { [string]: any },
	settings: { [string]: any },
	stats: { [string]: number },
	ledgers: any,
	economyStats: { [string]: number },
	grantedRounds: { string },
	purchaseReceipts: { [string]: boolean },
	livingCityContribution: number,
	fusedAuras: { any },
	photoModeUnlocks: { string },
	raidStats: { clears: number, bestScore: number },
	lastSeenAt: number,
	session: { jobId: string, expiresAt: number }?,
}

type Entry = {
	profile: Profile,
	readOnly: boolean,
	dirty: boolean,
	revision: number,
	saving: boolean,
}

local config: any = nil
local styleCatalog: any = nil
local store: any = nil
local entries: { [Player]: Entry } = {}
local sessionId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)
local shuttingDown = false
local autosaveEpoch = 0
local autosaveStarted = false
local persistenceDiagnostics: { [string]: number } = {
	requests = 0,
	attempts = 0,
	retries = 0,
	failures = 0,
	budgetWaits = 0,
}
local MINIMUM_SCHEMA_VERSION = 5

local SCHOOL_NAMES = { "Color", "Texture", "Motion", "Camera", "SetDesign" }
local FIRST_MIRACLE_STATUSES = {
	NotStarted = true,
	PaletteChoice = true,
	Actions = true,
	Bloom = true,
	Complete = true,
}

function DataService.CanClientCompleteOnboarding(
	profile: any,
	firstMiracleRequired: boolean
): boolean
	if not firstMiracleRequired then
		return true
	end
	local miracle = if type(profile) == "table" then profile.firstMiracle else nil
	return type(miracle) == "table" and miracle.status == "Complete"
end

local function targetSchemaVersion(): number
	local configured = math.floor(tonumber(config and config.SchemaVersion) or 1)
	return math.max(MINIMUM_SCHEMA_VERSION, configured)
end

function DataService.ResolveProfileSchemaVersion(storedVersion: any): number
	local stored = math.max(1, math.floor(tonumber(storedVersion) or 1))
	return math.max(stored, targetSchemaVersion())
end

local function sessionLockSeconds(): number
	return math.max(1, math.floor(tonumber(config and config.SessionLockSeconds) or 180))
end

local function autosaveIntervalSeconds(): number
	return math.max(1, tonumber(config and config.AutosaveIntervalSeconds) or 60)
end

local function persistenceSetting(name: string, fallback: number): number
	local section = if config and type(config.Persistence) == "table"
		then config.Persistence
		else nil
	return tonumber(section and section[name]) or fallback
end

local function retryPolicy(): any
	return {
		maxAttempts = persistenceSetting("MaximumAttempts", 3),
		initialDelaySeconds = persistenceSetting("InitialRetryDelaySeconds", 0.35),
		backoffMultiplier = persistenceSetting("BackoffMultiplier", 2),
		maximumDelaySeconds = persistenceSetting("MaximumRetryDelaySeconds", 1.5),
	}
end

local function requestType(name: string): any
	local requestTypes: any = Enum.DataStoreRequestType
	local ok, result = pcall(function()
		return requestTypes[name]
	end)
	return if ok and typeof(result) == "EnumItem" then result else nil
end

local function hasUpdateBudget(): boolean
	local standardRead = requestType("StandardRead")
	local standardWrite = requestType("StandardWrite")
	if standardRead and standardWrite then
		return DataStoreService:GetRequestBudgetForRequestType(standardRead) > 0
			and DataStoreService:GetRequestBudgetForRequestType(standardWrite) > 0
	end
	local legacyUpdate = requestType("UpdateAsync")
	if legacyUpdate then
		return DataStoreService:GetRequestBudgetForRequestType(legacyUpdate) > 0
	end
	-- If an engine version does not expose a compatible budget enum, let the
	-- protected request report the real backend error instead of blocking forever.
	return true
end

local function waitForUpdateBudget(): boolean
	local maximumWait = math.clamp(persistenceSetting("RequestBudgetWaitSeconds", 2), 0, 10)
	local pollSeconds = math.clamp(persistenceSetting("RequestBudgetPollSeconds", 0.1), 0.05, 1)
	local deadline = os.clock() + maximumWait
	local waited = false
	while true do
		local ok, available = pcall(hasUpdateBudget)
		if not ok or available then
			if waited then
				persistenceDiagnostics.budgetWaits += 1
			end
			return true
		end
		if os.clock() >= deadline then
			if waited then
				persistenceDiagnostics.budgetWaits += 1
			end
			return false
		end
		waited = true
		task.wait(math.min(pollSeconds, math.max(0, deadline - os.clock())))
	end
end

local function shouldRetryDataStoreFailure(failure: any, _attempt: number): boolean
	local message = string.lower(tostring(failure))
	for _, token in
		{
			"keynameempty",
			"keynamelimit",
			"valuenotallowed",
			"studioaccesstoapisnotallowed",
			"datamodelnoaccess",
			"luawebsrvsnoaccess",
		}
	do
		if string.find(message, string.lower(token), 1, true) then
			return false
		end
	end
	return true
end

local function updateAsyncWithRetry(key: string, transform: (any) -> any): (boolean, any)
	persistenceDiagnostics.requests += 1
	local success, result, attempts = DataStoreRetry.Run(function()
		if not waitForUpdateBudget() then
			error("DataStore UpdateAsync request budget unavailable", 0)
		end
		return store:UpdateAsync(key, function(current: any, keyInfo: any)
			local nextValue = transform(current)
			if nextValue == nil then
				return nil
			end
			if keyInfo then
				return nextValue, keyInfo:GetUserIds(), keyInfo:GetMetadata()
			end
			return nextValue
		end)
	end, retryPolicy(), shouldRetryDataStoreFailure)
	persistenceDiagnostics.attempts += attempts
	persistenceDiagnostics.retries += math.max(0, attempts - 1)
	if not success then
		persistenceDiagnostics.failures += 1
	end
	return success, result
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[deepCopy(key)] = deepCopy(item)
	end
	return result
end

local function getDefaultLoadout(): { [string]: string }
	if styleCatalog and type(styleCatalog.GetDefaultLoadout) == "function" then
		return styleCatalog.GetDefaultLoadout()
	end
	return {
		palette = "palette_prism",
		material = "material_smooth",
		aura = "aura_spark",
		pose = "pose_hero",
		accent = "accent_orbit",
	}
end

local function defaultFirstMiracleState(): any
	return {
		version = 2,
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
	}
end

local function defaultRemixCityState(): any
	return {
		version = 1,
		preferredRole = "",
		replayConsent = false,
		savedReplays = {},
		stats = {
			momentsCaptured = 0,
			guardiansCompleted = 0,
			encoresRequested = 0,
			remixesSaved = 0,
			cityContribution = 0,
		},
		season = {
			id = "remix_city_s1",
			xp = 0,
			claimedFree = {},
			claimedPremium = {},
		},
	}
end

local function defaultProfile(): Profile
	local starterUnlocks = {
		palette = { "palette_prism" },
		material = { "material_smooth" },
		aura = { "aura_spark" },
		pose = { "pose_hero" },
		accent = { "accent_orbit" },
	}
	if styleCatalog and type(styleCatalog.GetStarterUnlocks) == "function" then
		starterUnlocks = styleCatalog.GetStarterUnlocks()
	end
	return {
		schemaVersion = targetSchemaVersion(),
		glowDust = 0,
		unlocks = starterUnlocks,
		equipped = getDefaultLoadout(),
		savedLooks = {},
		auraAtlas = { Color = 1, Texture = 1, Motion = 1, Camera = 1, SetDesign = 1 },
		auraAtlasXp = { Color = 0, Texture = 0, Motion = 0, Camera = 0, SetDesign = 0 },
		progression = {
			creativeRank = 1,
			creativeXp = 0,
			totalCreativeXp = 0,
			masteryUnlocks = 0,
		},
		achievements = {},
		seasonProgress = 0,
		quests = {
			daily = { day = 0, items = {}, bank = {}, rerollsUsed = 0 },
			weekly = { week = 0, items = {} },
			streak = { count = 0, lastCompletedDay = 0, graceCredits = 1 },
			totals = { dailyCompleted = 0, weeklyCompleted = 0, glowDustEarned = 0 },
		},
		liveOps = {
			contributions = {},
			dailyContributions = {},
			weeklyContributions = {},
			claimedMilestones = {},
		},
		activationTokens = {},
		pendingActivations = {},
		postcards = {},
		atelier = { id = "", role = "", joinedAt = 0, blockedInviters = {} },
		firstMiracle = defaultFirstMiracleState(),
		remixCity = defaultRemixCityState(),
		grantLedger = {},
		settings = {
			language = "auto",
			reducedMotion = false,
			lowVfx = false,
			noFlashes = false,
			highContrast = false,
			largeText = false,
			captions = true,
			haptics = true,
			cameraShake = 0.2,
			musicVolume = 0.7,
			sfxVolume = 0.7,
			ambienceVolume = 0.7,
			onboardingComplete = false,
		},
		stats = {
			roundsPlayed = 0,
			finalesCompleted = 0,
			bestBeatScore = 0,
			threadsCollected = 0,
		},
		ledgers = {
			paidReceipts = {},
			grants = {
				rounds = {},
				events = {},
				quests = {},
				mastery = {},
				system = {},
			},
			spends = {},
		},
		economyStats = { earned = 0, spent = 0 },
		grantedRounds = {},
		purchaseReceipts = {},
		livingCityContribution = 0,
		fusedAuras = {},
		photoModeUnlocks = {},
		raidStats = { clears = 0, bestScore = 0 },
		lastSeenAt = os.time(),
		session = nil,
	}
end

local function normalizeSavedLooks(profile: any): ()
	if type(profile.savedLooks) ~= "table" then
		profile.savedLooks = {}
		return
	end
	local normalized = {}
	for _, saved in profile.savedLooks do
		if type(saved) == "table" then
			local index = #normalized + 1
			local isModernRecord = type(saved.loadout) == "table"
			local loadout = if isModernRecord then saved.loadout else saved
			local mergedLoadout = getDefaultLoadout()
			for category, itemId in loadout do
				if type(category) == "string" and type(itemId) == "string" then
					mergedLoadout[category] = itemId
				end
			end
			local record = if isModernRecord then deepCopy(saved) else {}
			record.id = if type(saved.id) == "string"
				then saved.id
				else string.format("legacy_%d", index)
			record.name = if type(saved.name) == "string"
				then saved.name
				else string.format("Look %d", index)
			record.createdAt =
				math.floor(tonumber(saved.createdAt) or tonumber(profile.lastSeenAt) or os.time())
			record.loadout = mergedLoadout
			table.insert(normalized, record)
		end
	end
	profile.savedLooks = normalized
end

local function migrateProfile(current: any): any
	if type(current) ~= "table" then
		return current
	end
	local profile = deepCopy(current)
	local version = math.max(1, math.floor(tonumber(profile.schemaVersion) or 1))

	if version < 2 then
		profile.ledgers = {
			paidReceipts = deepCopy(profile.purchaseReceipts or {}),
			grants = { rounds = {}, events = {}, quests = {}, mastery = {}, system = {} },
			spends = {},
		}
		if type(profile.grantedRounds) == "table" then
			local baseTime = math.floor(tonumber(profile.lastSeenAt) or os.time())
			local offset = 0
			for _, roundId in profile.grantedRounds do
				if type(roundId) == "string" then
					offset += 1
					profile.ledgers.grants.rounds[roundId] = baseTime + offset
				end
			end
		end
		profile.auraAtlasXp = { Color = 0, Texture = 0, Motion = 0, Camera = 0, SetDesign = 0 }
		profile.progression = {
			creativeRank = 1,
			creativeXp = 0,
			totalCreativeXp = math.max(0, math.floor(tonumber(profile.seasonProgress) or 0)),
			masteryUnlocks = 0,
		}
		profile.economyStats = { earned = 0, spent = 0 }
		normalizeSavedLooks(profile)
		version = 2
	end

	if version < 3 then
		profile.quests = {
			daily = { day = 0, items = {}, bank = {}, rerollsUsed = 0 },
			weekly = { week = 0, items = {} },
			streak = { count = 0, lastCompletedDay = 0, graceCredits = 1 },
			totals = { dailyCompleted = 0, weeklyCompleted = 0, glowDustEarned = 0 },
		}
		profile.liveOps = {
			contributions = {},
			dailyContributions = {},
			weeklyContributions = {},
			claimedMilestones = {},
		}
		profile.activationTokens = {}
		profile.pendingActivations = {}
		profile.postcards = {}
		profile.atelier = { id = "", role = "", joinedAt = 0 }
		profile.grantLedger = {}
		profile.firstMiracle = defaultFirstMiracleState()
		version = 3
	end

	if version < 4 then
		profile.remixCity = defaultRemixCityState()
		if type(profile.atelier) ~= "table" then
			profile.atelier = { id = "", role = "", joinedAt = 0, blockedInviters = {} }
		elseif type(profile.atelier.blockedInviters) ~= "table" then
			profile.atelier.blockedInviters = {}
		end
		version = 4
	end

	if version < 5 then
		if type(profile.firstMiracle) ~= "table" then
			profile.firstMiracle = defaultFirstMiracleState()
		end
		profile.firstMiracle.version =
			math.max(2, math.floor(tonumber(profile.firstMiracle.version) or 1))
		version = 5
	end

	profile.schemaVersion = math.max(version, targetSchemaVersion())
	return profile
end

local function reconcile(target: any, template: any): any
	if type(template) ~= "table" then
		if target == nil or type(target) ~= type(template) then
			return deepCopy(template)
		end
		return target
	end
	if type(target) ~= "table" then
		target = {}
	end
	for key, value in template do
		target[key] = reconcile(target[key], value)
	end
	return target
end

local function trimTimestampLedger(ledger: any, maximum: number): ()
	if type(ledger) ~= "table" then
		return
	end
	local values = {}
	for id, timestamp in ledger do
		if type(id) == "string" then
			local parsedTimestamp = if type(timestamp) == "number"
				then timestamp
				else if type(timestamp) == "string" then tonumber(timestamp) else nil
			table.insert(values, { id = id, timestamp = parsedTimestamp or 0 })
		else
			ledger[id] = nil
		end
	end
	if #values <= maximum then
		return
	end
	table.sort(values, function(left, right)
		if left.timestamp == right.timestamp then
			return left.id < right.id
		end
		return left.timestamp < right.timestamp
	end)
	for index = 1, #values - maximum do
		ledger[values[index].id] = nil
	end
end

local function normalizeProfile(profile: Profile): ()
	normalizeSavedLooks(profile)
	profile.schemaVersion = DataService.ResolveProfileSchemaVersion(profile.schemaVersion)

	local ledgers = profile.ledgers
	if type(ledgers) ~= "table" then
		ledgers = {}
		profile.ledgers = ledgers
	end
	if type(ledgers.grants) ~= "table" then
		ledgers.grants = {}
	end
	for _, key in { "rounds", "events", "quests", "mastery", "system" } do
		if type(ledgers.grants[key]) ~= "table" then
			ledgers.grants[key] = {}
		end
	end
	if type(ledgers.spends) ~= "table" then
		ledgers.spends = {}
	end
	if type(ledgers.paidReceipts) ~= "table" then
		ledgers.paidReceipts = {}
	end
	if type(profile.purchaseReceipts) == "table" then
		for receiptId, granted in profile.purchaseReceipts do
			if type(receiptId) == "string" and granted == true then
				ledgers.paidReceipts[receiptId] = true
			end
		end
	end
	-- Preserve the legacy PurchaseService contract while keeping paid receipts
	-- physically separate from free round/event grants.
	profile.purchaseReceipts = ledgers.paidReceipts
	if type(profile.grantLedger) ~= "table" then
		profile.grantLedger = {}
	end
	if type(profile.activationTokens) ~= "table" then
		profile.activationTokens = {}
	end
	if type(profile.pendingActivations) ~= "table" then
		profile.pendingActivations = {}
	end
	for tokenId, amount in profile.activationTokens do
		if type(tokenId) ~= "string" then
			profile.activationTokens[tokenId] = nil
		else
			profile.activationTokens[tokenId] = math.max(0, math.floor(tonumber(amount) or 0))
		end
	end
	if type(profile.postcards) ~= "table" then
		profile.postcards = {}
	end
	if type(profile.atelier) ~= "table" then
		profile.atelier = { id = "", role = "", joinedAt = 0, blockedInviters = {} }
	end
	profile.atelier.id = if type(profile.atelier.id) == "string" then profile.atelier.id else ""
	profile.atelier.role = if type(profile.atelier.role) == "string"
		then profile.atelier.role
		else ""
	profile.atelier.joinedAt = math.max(0, math.floor(tonumber(profile.atelier.joinedAt) or 0))
	if type(profile.atelier.blockedInviters) ~= "table" then
		profile.atelier.blockedInviters = {}
	end
	trimTimestampLedger(profile.atelier.blockedInviters, 64)

	if type(profile.remixCity) ~= "table" then
		profile.remixCity = defaultRemixCityState()
	end
	local remix = profile.remixCity
	remix.version = math.max(1, math.floor(tonumber(remix.version) or 1))
	local validRoles = { navigator = true, rhythmer = true, colorist = true, director = true }
	remix.preferredRole = if type(remix.preferredRole) == "string"
			and validRoles[remix.preferredRole]
		then remix.preferredRole
		else ""
	remix.replayConsent = remix.replayConsent == true
	if type(remix.savedReplays) ~= "table" then
		remix.savedReplays = {}
	end
	if type(remix.stats) ~= "table" then
		remix.stats = {}
	end
	for _, key in
		{
			"momentsCaptured",
			"guardiansCompleted",
			"encoresRequested",
			"remixesSaved",
			"cityContribution",
		}
	do
		remix.stats[key] = math.max(0, math.floor(tonumber(remix.stats[key]) or 0))
	end
	if type(remix.season) ~= "table" then
		remix.season = defaultRemixCityState().season
	end
	remix.season.id = "remix_city_s1"
	remix.season.xp = math.max(0, math.floor(tonumber(remix.season.xp) or 0))
	if type(remix.season.claimedFree) ~= "table" then
		remix.season.claimedFree = {}
	end
	if type(remix.season.claimedPremium) ~= "table" then
		remix.season.claimedPremium = {}
	end

	if type(profile.firstMiracle) ~= "table" then
		profile.firstMiracle = defaultFirstMiracleState()
	end
	local miracle = profile.firstMiracle
	miracle.version = math.max(2, math.floor(tonumber(miracle.version) or 1))
	miracle.status = if type(miracle.status) == "string"
			and FIRST_MIRACLE_STATUSES[miracle.status]
		then miracle.status
		else "NotStarted"
	miracle.sessionId = if type(miracle.sessionId) == "string"
		then string.sub(miracle.sessionId, 1, 80)
		else ""
	miracle.paletteId = if type(miracle.paletteId) == "string"
		then string.sub(miracle.paletteId, 1, 48)
		else ""
	local actionSequence = config and config.FirstMiracle and config.FirstMiracle.ActionSequence
	local maximumActions = if type(actionSequence) == "table"
		then math.max(1, #actionSequence)
		else 3
	miracle.actionIndex =
		math.clamp(math.floor(tonumber(miracle.actionIndex) or 0), 0, maximumActions)
	for _, key in
		{
			"startedAt",
			"choiceExpiresAt",
			"expiresAt",
			"bloomStartedAt",
			"completedAt",
		}
	do
		miracle[key] = math.max(0, math.floor(tonumber(miracle[key]) or 0))
	end
	miracle.completionReason = if type(miracle.completionReason) == "string"
		then string.sub(miracle.completionReason, 1, 32)
		else ""
	miracle.skipped = miracle.skipped == true
	miracle.rewardClaimed = miracle.rewardClaimed == true

	if type(profile.grantedRounds) ~= "table" then
		profile.grantedRounds = {}
	end
	local roundOffset = 0
	for _, roundId in profile.grantedRounds do
		if type(roundId) == "string" and ledgers.grants.rounds[roundId] == nil then
			roundOffset += 1
			ledgers.grants.rounds[roundId] = (tonumber(profile.lastSeenAt) or os.time())
				+ roundOffset
		end
	end

	if type(profile.auraAtlas) ~= "table" then
		profile.auraAtlas = {}
	end
	if type(profile.auraAtlasXp) ~= "table" then
		profile.auraAtlasXp = {}
	end
	for _, school in SCHOOL_NAMES do
		profile.auraAtlas[school] =
			math.clamp(math.floor(tonumber(profile.auraAtlas[school]) or 1), 1, 20)
		profile.auraAtlasXp[school] =
			math.max(0, math.floor(tonumber(profile.auraAtlasXp[school]) or 0))
	end

	profile.livingCityContribution =
		math.max(0, math.floor(tonumber(profile.livingCityContribution) or 0))
	if type(profile.fusedAuras) ~= "table" then
		profile.fusedAuras = {}
	end
	local normalizedPhotoUnlocks = {}
	local seenPhotoUnlocks: { [string]: boolean } = {}
	for _, unlockId in
		if type(profile.photoModeUnlocks) == "table" then profile.photoModeUnlocks else {}
	do
		if
			type(unlockId) == "string"
			and #unlockId > 0
			and #unlockId <= 64
			and not seenPhotoUnlocks[unlockId]
		then
			seenPhotoUnlocks[unlockId] = true
			table.insert(normalizedPhotoUnlocks, unlockId)
		end
	end
	profile.photoModeUnlocks = normalizedPhotoUnlocks
	if type(profile.raidStats) ~= "table" then
		profile.raidStats = { clears = 0, bestScore = 0 }
	end
	profile.raidStats.clears = math.max(0, math.floor(tonumber(profile.raidStats.clears) or 0))
	profile.raidStats.bestScore =
		math.max(0, math.floor(tonumber(profile.raidStats.bestScore) or 0))
end

local function trimProfile(profile: Profile): ()
	normalizeProfile(profile)
	local dataLimits = config and config.DataLimits
	local grantedLimit = if type(dataLimits) == "table"
		then (tonumber(dataLimits.MaximumGrantedRoundHistory) or 30)
		else 30
	local lookLimit = if type(dataLimits) == "table"
		then (tonumber(dataLimits.MaximumSavedLooks) or 8)
		else 8
	local postcardLimit = if type(dataLimits) == "table"
		then math.max(1, math.floor(tonumber(dataLimits.MaximumPostcards) or 24))
		else 24
	local grantLedgerLimit = if type(dataLimits) == "table"
		then math.max(1, math.floor(tonumber(dataLimits.MaximumGrantLedgerEntries) or 180))
		else 180
	local photoUnlockLimit = if type(dataLimits) == "table"
		then math.max(1, math.floor(tonumber(dataLimits.MaximumPhotoModeUnlocks) or 32))
		else 32
	while #profile.grantedRounds > grantedLimit do
		table.remove(profile.grantedRounds, 1)
	end
	while #profile.savedLooks > lookLimit do
		table.remove(profile.savedLooks, 1)
	end
	while #profile.postcards > postcardLimit do
		table.remove(profile.postcards, 1)
	end
	while #profile.photoModeUnlocks > photoUnlockLimit do
		table.remove(profile.photoModeUnlocks, 1)
	end
	local replayLimit = if type(dataLimits) == "table"
		then math.max(1, math.floor(tonumber(dataLimits.MaximumSavedReplays) or 8))
		else 8
	local eventLimit = if type(dataLimits) == "table"
		then math.max(4, math.floor(tonumber(dataLimits.MaximumReplayEvents) or 24))
		else 24
	while #profile.remixCity.savedReplays > replayLimit do
		table.remove(profile.remixCity.savedReplays, 1)
	end
	for _, replay in profile.remixCity.savedReplays do
		if type(replay) == "table" and type(replay.events) == "table" then
			while #replay.events > eventLimit do
				table.remove(replay.events, 1)
			end
		end
	end
	trimTimestampLedger(profile.ledgers.grants.rounds, math.max(grantedLimit, 256))
	trimTimestampLedger(profile.ledgers.grants.events, 256)
	trimTimestampLedger(profile.ledgers.grants.quests, 512)
	trimTimestampLedger(profile.ledgers.grants.mastery, 256)
	trimTimestampLedger(profile.ledgers.grants.system, 256)
	trimTimestampLedger(profile.ledgers.spends, 512)
	trimTimestampLedger(profile.grantLedger, grantLedgerLimit)
	profile.glowDust = math.max(0, math.floor(profile.glowDust))
	profile.economyStats.earned =
		math.max(0, math.floor(tonumber(profile.economyStats.earned) or 0))
	profile.economyStats.spent = math.max(0, math.floor(tonumber(profile.economyStats.spent) or 0))
	profile.lastSeenAt = os.time()
end

local function keyFor(player: Player): string
	return "player_" .. tostring(player.UserId)
end

function DataService.Init(context: any): ()
	shuttingDown = false
	autosaveEpoch += 1
	autosaveStarted = false
	for key in persistenceDiagnostics do
		persistenceDiagnostics[key] = 0
	end
	config = context.Config
	styleCatalog = context.StyleCatalog
	local storeName = "AuraRush_Profile_v1"
	if type(config.DataStoreName) == "string" then
		storeName = config.DataStoreName
	end
	-- GetDataStore itself throws for an unpublished local file. Keep the whole
	-- persistence adapter dormant in that environment; Load() will create the
	-- explicit read-only fallback profile before any store method is needed.
	if RunService:IsStudio() and game.GameId == 0 then
		store = nil
	else
		store = DataStoreService:GetDataStore(storeName)
	end

	context.Services.Remote.BindEvent("UpdateSettings", 4, function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.settings) ~= "table" then
			return
		end
		local allowedBoolean = {
			reducedMotion = true,
			lowVfx = true,
			noFlashes = true,
			highContrast = true,
			largeText = true,
			captions = true,
			haptics = true,
			onboardingComplete = true,
		}
		local allowedNumber = {
			cameraShake = true,
			musicVolume = true,
			sfxVolume = true,
			ambienceVolume = true,
		}
		local nextSettings: { [string]: boolean | number } = {}
		for key, value in payload.settings do
			if type(key) == "string" and allowedBoolean[key] and type(value) == "boolean" then
				nextSettings[key] = value
			elseif type(key) == "string" and allowedNumber[key] and type(value) == "number" then
				if value == value and value > -math.huge and value < math.huge then
					nextSettings[key] = math.clamp(value, 0, 1)
				end
			end
		end
		if next(nextSettings) == nil or DataService.IsReadOnly(player) then
			return
		end
		if
			DataService.Update(player, function(profile: Profile)
				for key, value in nextSettings do
					if key == "onboardingComplete" then
						local firstMiracleConfig = if type(config.FirstMiracle) == "table"
							then config.FirstMiracle
							else {}
						local firstMiracleRequired = firstMiracleConfig.Enabled ~= false
						local flags = context.Services.Flags
						if flags and type(flags.IsEnabled) == "function" then
							firstMiracleRequired = firstMiracleRequired
								and flags.IsEnabled("FirstMiracle")
						elseif type(config.FeatureFlags) == "table" then
							firstMiracleRequired = firstMiracleRequired
								and config.FeatureFlags.FirstMiracle == true
						end
						if
							value == true
							and DataService.CanClientCompleteOnboarding(
								profile,
								firstMiracleRequired
							)
						then
							profile.settings[key] = true
						end
					else
						profile.settings[key] = value
					end
				end
			end)
		then
			context.Services.Remote.FireClient("ProgressUpdate", player, {
				kind = "Profile",
				profile = DataService.GetClientView(player),
			})
		end
	end)
end

function DataService.Load(player: Player): boolean
	if shuttingDown then
		return false
	end
	if entries[player] then
		return true
	end

	local fallback = defaultProfile()
	normalizeProfile(fallback)
	-- Local files have no universe and Roblox can keep UpdateAsync waiting for a
	-- long internal retry window. Enter the same safe read-only mode immediately
	-- so Play Solo remains useful; published Studio sessions still test DataStore.
	if RunService:IsStudio() and game.GameId == 0 then
		entries[player] = {
			profile = fallback,
			readOnly = true,
			dirty = false,
			revision = 0,
			saving = false,
		}
		return false
	end

	local loaded: Profile? = nil
	local locked = false
	local success, result = updateAsyncWithRetry(keyFor(player), function(current: any)
		local now = os.time()
		if type(current) == "table" and type(current.session) == "table" then
			local owner = current.session.jobId
			local expiresAt = tonumber(current.session.expiresAt) or 0
			if owner ~= sessionId and expiresAt > now then
				locked = true
				return nil
			end
		end
		local profile = reconcile(migrateProfile(current), fallback) :: Profile
		normalizeProfile(profile)
		profile.session = { jobId = sessionId, expiresAt = now + sessionLockSeconds() }
		trimProfile(profile)
		return profile
	end)

	if success and type(result) == "table" and not locked then
		loaded = reconcile(migrateProfile(result), fallback) :: Profile
		normalizeProfile(loaded)
		entries[player] = {
			profile = loaded,
			readOnly = false,
			dirty = false,
			revision = 0,
			saving = false,
		}
		return true
	end

	if not RunService:IsStudio() then
		warn(
			string.format(
				"[AuraRush/Data] Read-only profile for %s (%s)",
				player.Name,
				if locked then "session locked" else tostring(result)
			)
		)
	end
	entries[player] = {
		profile = fallback,
		readOnly = true,
		dirty = false,
		revision = 0,
		saving = false,
	}
	return false
end

function DataService.IsLoaded(player: Player): boolean
	return entries[player] ~= nil
end

function DataService.IsReadOnly(player: Player): boolean
	local entry = entries[player]
	return if entry then entry.readOnly else true
end

function DataService.GetProfile(player: Player): Profile?
	local entry = entries[player]
	return if entry then entry.profile else nil
end

function DataService.GetClientView(player: Player): any
	local entry = entries[player]
	if not entry then
		return nil
	end
	local profile = entry.profile
	return {
		schemaVersion = profile.schemaVersion,
		glowDust = profile.glowDust,
		unlocks = deepCopy(profile.unlocks),
		equipped = deepCopy(profile.equipped),
		savedLooks = deepCopy(profile.savedLooks),
		auraAtlas = deepCopy(profile.auraAtlas),
		auraAtlasXp = deepCopy(profile.auraAtlasXp),
		progression = deepCopy(profile.progression),
		quests = deepCopy(profile.quests),
		liveOps = deepCopy(profile.liveOps),
		activationTokens = deepCopy(profile.activationTokens),
		postcards = deepCopy(profile.postcards),
		atelier = deepCopy(profile.atelier),
		firstMiracle = deepCopy(profile.firstMiracle),
		remixCity = deepCopy(profile.remixCity),
		photoModeUnlocks = deepCopy(profile.photoModeUnlocks),
		meta = {
			activationTokens = deepCopy(profile.activationTokens),
			postcards = deepCopy(profile.postcards),
			atelier = deepCopy(profile.atelier),
			remixCity = deepCopy(profile.remixCity),
		},
		seasonProgress = profile.seasonProgress,
		economyStats = deepCopy(profile.economyStats),
		stats = deepCopy(profile.stats),
		settings = deepCopy(profile.settings),
		readOnly = entry.readOnly,
	}
end

function DataService.GetSchemaVersion(): number
	return targetSchemaVersion()
end

function DataService.GetPersistenceDiagnostics(): any
	return table.clone(persistenceDiagnostics)
end

function DataService.HasGrant(player: Player, grantKind: string, grantId: string): boolean
	local entry = entries[player]
	if not entry then
		return false
	end
	local grants = entry.profile.ledgers.grants
	local ledger = if type(grants) == "table" then grants[grantKind] else nil
	return type(ledger) == "table" and ledger[grantId] ~= nil
end

function DataService.Update(player: Player, mutator: (Profile) -> ()): boolean
	if shuttingDown then
		return false
	end
	local entry = entries[player]
	if not entry then
		return false
	end
	local before = deepCopy(entry.profile) :: Profile
	local ok, message = xpcall(function()
		mutator(entry.profile)
		trimProfile(entry.profile)
	end, debug.traceback)
	if not ok then
		entry.profile = before
		warn("[AuraRush/Data] Update rejected: " .. tostring(message))
		return false
	end
	entry.revision += 1
	entry.dirty = true
	return true
end

function DataService.Transact(player: Player, mutator: (Profile) -> any): (boolean, any)
	local result: any = nil
	local updated = DataService.Update(player, function(profile: Profile)
		result = mutator(profile)
	end)
	return updated, result
end

function DataService.Save(player: Player): boolean
	local entry = entries[player]
	if not entry or entry.readOnly then
		return entry ~= nil
	end

	local waitStartedAt = os.clock()
	while entry.saving do
		if os.clock() - waitStartedAt >= 30 or entries[player] ~= entry then
			return false
		end
		task.wait(0.05)
	end
	if not entry.dirty then
		return true
	end

	entry.saving = true
	local savedRevision = entry.revision
	trimProfile(entry.profile)
	entry.profile.session = if shuttingDown
		then nil
		else { jobId = sessionId, expiresAt = os.time() + sessionLockSeconds() }
	local snapshot = deepCopy(entry.profile)

	local lockRejected = false
	local success, message = updateAsyncWithRetry(keyFor(player), function(current: any)
		if type(current) == "table" and type(current.session) == "table" then
			if
				current.session.jobId ~= sessionId
				and (tonumber(current.session.expiresAt) or 0) > os.time()
			then
				lockRejected = true
				return nil
			end
		end
		return snapshot
	end)
	if success and lockRejected then
		success = false
		message = "profile session ownership changed during save"
	end
	entry.saving = false
	if success then
		-- Mutations can occur while UpdateAsync yields. Only clear dirty when the
		-- exact captured revision was persisted.
		entry.dirty = entry.revision ~= savedRevision
	else
		warn(
			string.format("[AuraRush/Data] Save failed for %s: %s", player.Name, tostring(message))
		)
	end
	return success
end

function DataService.Release(player: Player): ()
	local entry = entries[player]
	if not entry then
		return
	end
	local fullySaved = entry.readOnly
	if not entry.readOnly then
		local deadline = os.clock() + 8
		repeat
			local saved = DataService.Save(player)
			fullySaved = saved and not entry.dirty
			if not fullySaved then
				task.wait(0.1)
			end
		until fullySaved or os.clock() >= deadline or entries[player] ~= entry
	end
	if not entry.readOnly and not shuttingDown and fullySaved then
		local released, releaseMessage = updateAsyncWithRetry(keyFor(player), function(current: any)
			if
				type(current) == "table"
				and type(current.session) == "table"
				and current.session.jobId == sessionId
			then
				current.session = nil
			end
			return current
		end)
		if not released then
			warn(
				string.format(
					"[AuraRush/Data] Session release failed for %s: %s",
					player.Name,
					tostring(releaseMessage)
				)
			)
		end
	elseif not entry.readOnly and not fullySaved then
		warn(`[AuraRush/Data] Release save remained dirty for {player.Name}; session lock kept`)
	end
	entries[player] = nil
end

function DataService.StartAutosave(): ()
	if autosaveStarted or shuttingDown then
		return
	end
	autosaveStarted = true
	autosaveEpoch += 1
	local epoch = autosaveEpoch
	task.spawn(function()
		while not shuttingDown and autosaveEpoch == epoch do
			task.wait(autosaveIntervalSeconds())
			if shuttingDown or autosaveEpoch ~= epoch then
				break
			end
			for player in entries do
				DataService.Save(player)
			end
		end
		if autosaveEpoch == epoch then
			autosaveStarted = false
		end
	end)
end

function DataService.Shutdown(): ()
	if shuttingDown then
		return
	end
	shuttingDown = true
	autosaveEpoch += 1
	autosaveStarted = false
	local pending = 0
	local budget = math.clamp(tonumber(config.ShutdownSaveBudgetSeconds) or 25, 2, 29)
	local deadline = os.clock() + budget
	for player, entry in entries do
		if not entry.readOnly then
			entry.dirty = true
			entry.revision += 1
			pending += 1
			task.spawn(function()
				while os.clock() < deadline do
					if entries[player] ~= entry then
						break
					end
					if DataService.Save(player) and not entry.dirty then
						break
					end
					task.wait(0.15)
				end
				pending -= 1
			end)
		end
	end
	while pending > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
	if pending > 0 then
		warn(
			string.format(
				"[AuraRush/Data] Shutdown save budget ended with %d profile(s) pending",
				pending
			)
		)
	end
end

return DataService
