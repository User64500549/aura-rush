--!strict

local LiveOpsService = {}

local dataService: any = nil
local economyService: any = nil
local enabled = false
local flagService: any = nil
local manifestAllowed = true
local maximumDailyContribution = 150

local FALLBACK_MANIFEST = table.freeze({
	version = 1,
	events = table.freeze({}),
})

local manifest: any = FALLBACK_MANIFEST

local function isEnabled(): boolean
	if not enabled or not manifestAllowed then
		return false
	end
	return not flagService
		or type(flagService.IsEnabled) ~= "function"
		or flagService.IsEnabled("LiveOps")
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

local function getEvent(eventId: string): any
	if type(manifest.events) ~= "table" then
		return nil
	end
	for _, event in manifest.events do
		if type(event) == "table" and event.id == eventId then
			return event
		end
	end
	return nil
end

local function isActive(event: any, timestamp: number): boolean
	local startsAt = math.floor(tonumber(event.startsAt) or 0)
	local endsAt = math.floor(tonumber(event.endsAt) or 0)
	return startsAt <= timestamp and (endsAt == 0 or timestamp < endsAt)
end

local function weeklyDistrict(event: any, timestamp: number, personalContribution: number): any
	local rotation = event.districtRotation
	if type(rotation) ~= "table" or #rotation == 0 then
		return nil
	end
	local periodDays = math.clamp(math.floor(tonumber(event.rotationPeriodDays) or 7), 1, 31)
	local periodSeconds = periodDays * 86_400
	local rotationNumber = math.floor(timestamp / periodSeconds)
	local index = (rotationNumber % #rotation) + 1
	local worldId = rotation[index]
	if type(worldId) ~= "string" then
		return nil
	end
	local startsAt = rotationNumber * periodSeconds
	local goal = math.max(1, math.floor(tonumber(event.weeklyGoal) or 50))
	return {
		worldId = worldId,
		rotationIndex = index,
		startsAt = startsAt,
		endsAt = startsAt + periodSeconds,
		goal = goal,
		progress = math.clamp(math.floor(personalContribution), 0, goal),
		complete = personalContribution >= goal,
	}
end

function LiveOpsService.Init(context: any): ()
	dataService = context.Services.Data
	economyService = context.Services.Economy
	local flags = context.Config.FeatureFlags
	flagService = context.Services.Flags
	enabled = type(flags) == "table" and flags.LiveOps == true
	local liveOpsConfig = context.Config.LiveOps
	maximumDailyContribution = if type(liveOpsConfig) == "table"
		then math.max(1, math.floor(tonumber(liveOpsConfig.MaximumDailyContribution) or 150))
		else 150
	if
		type(context.LiveOpsManifest) == "table"
		and type(context.LiveOpsManifest.events) == "table"
	then
		manifest = deepCopy(context.LiveOpsManifest)
	else
		manifest = FALLBACK_MANIFEST
	end
	local minimumClientVersion =
		math.max(1, math.floor(tonumber(manifest.minimumClientVersion) or 1))
	local clientVersion = math.max(1, math.floor(tonumber(context.Config.ClientVersion) or 1))
	manifestAllowed = manifest.killSwitch ~= true and minimumClientVersion <= clientVersion
end

function LiveOpsService.IsEnabled(): boolean
	return isEnabled()
end

function LiveOpsService.GetManifest(): any
	return deepCopy(manifest)
end

function LiveOpsService.GetActiveEvents(timestamp: number?): { any }
	if not isEnabled() then
		return {}
	end
	local now = math.floor(timestamp or os.time())
	local active = {}
	for _, event in manifest.events do
		if type(event) == "table" and type(event.id) == "string" and isActive(event, now) then
			table.insert(active, deepCopy(event))
		end
	end
	return active
end

function LiveOpsService.Contribute(
	player: Player,
	eventId: string,
	contributionId: string,
	amountValue: number
): any
	if not isEnabled() then
		return { ok = false, reason = "liveops_disabled" }
	end
	local event = getEvent(eventId)
	if
		type(eventId) ~= "string"
		or type(contributionId) ~= "string"
		or #eventId > 80
		or #contributionId > 100
		or not event
		or not isActive(event, os.time())
	then
		return { ok = false, reason = "event_unavailable" }
	end
	local amount = math.clamp(math.floor(tonumber(amountValue) or 0), 0, 1_000)
	if amount <= 0 then
		return { ok = false, reason = "invalid_contribution" }
	end
	local dailyLimit = math.max(
		1,
		math.min(
			maximumDailyContribution,
			math.floor(tonumber(event.maximumDailyContribution) or maximumDailyContribution)
		)
	)
	return economyService.GrantCurrency(
		player,
		"event",
		string.format("%s:%s", eventId, contributionId),
		0,
		function(profile: any)
			local day = math.floor(os.time() / 86_400)
			if type(profile.liveOps.dailyContributions) ~= "table" then
				profile.liveOps.dailyContributions = {}
			end
			local daily = profile.liveOps.dailyContributions[eventId]
			if type(daily) ~= "table" or math.floor(tonumber(daily.day) or -1) ~= day then
				daily = { day = day, amount = 0 }
				profile.liveOps.dailyContributions[eventId] = daily
			end
			local usedToday = math.max(0, math.floor(tonumber(daily.amount) or 0))
			local appliedAmount = math.min(amount, math.max(0, dailyLimit - usedToday))
			local previous =
				math.max(0, math.floor(tonumber(profile.liveOps.contributions[eventId]) or 0))
			profile.liveOps.contributions[eventId] = previous + appliedAmount
			daily.amount = usedToday + appliedAmount
			if type(profile.liveOps.weeklyContributions) ~= "table" then
				profile.liveOps.weeklyContributions = {}
			end
			local periodDays =
				math.clamp(math.floor(tonumber(event.rotationPeriodDays) or 7), 1, 31)
			local period = math.floor(os.time() / (periodDays * 86_400))
			local weekly = profile.liveOps.weeklyContributions[eventId]
			if type(weekly) ~= "table" or math.floor(tonumber(weekly.period) or -1) ~= period then
				weekly = { period = period, amount = 0 }
				profile.liveOps.weeklyContributions[eventId] = weekly
			end
			weekly.amount = math.max(0, math.floor(tonumber(weekly.amount) or 0)) + appliedAmount
			return {
				eventId = eventId,
				contributed = appliedAmount,
				total = previous + appliedAmount,
				dailyTotal = daily.amount,
				dailyLimit = dailyLimit,
				dailyLimitReached = daily.amount >= dailyLimit,
				weeklyTotal = weekly.amount,
				weeklyGoal = math.max(1, math.floor(tonumber(event.weeklyGoal) or 50)),
			}
		end
	)
end

function LiveOpsService.ClaimMilestone(
	player: Player,
	eventId: string,
	milestoneId: string,
	progressOverride: number?
): any
	if not isEnabled() then
		return { ok = false, reason = "liveops_disabled" }
	end
	local event = getEvent(eventId)
	if not event or type(event.milestones) ~= "table" then
		return { ok = false, reason = "event_unavailable" }
	end
	local selected: any = nil
	for _, milestone in event.milestones do
		if type(milestone) == "table" and milestone.id == milestoneId then
			selected = milestone
			break
		end
	end
	if not selected then
		return { ok = false, reason = "milestone_unavailable" }
	end
	local profile = dataService.GetProfile(player)
	local contribution = if profile
		then math.max(0, math.floor(tonumber(profile.liveOps.contributions[eventId]) or 0))
		else 0
	if
		type(progressOverride) == "number"
		and progressOverride == progressOverride
		and progressOverride > -math.huge
		and progressOverride < math.huge
	then
		contribution = math.max(contribution, math.max(0, math.floor(progressOverride)))
	end
	local target = math.max(1, math.floor(tonumber(selected.target) or 1))
	if contribution < target then
		return { ok = false, reason = "milestone_locked" }
	end
	local reward = math.clamp(math.floor(tonumber(selected.glowDust) or 0), 0, 100_000)
	return economyService.GrantCurrency(
		player,
		"event",
		string.format("claim:%s:%s", eventId, milestoneId),
		reward,
		function(editable: any)
			local key = eventId .. ":" .. milestoneId
			editable.liveOps.claimedMilestones[key] = true
			return { eventId = eventId, milestoneId = milestoneId, glowDust = reward }
		end
	)
end

function LiveOpsService.GetPlayerView(player: Player): any
	local profile = dataService.GetProfile(player)
	if not profile then
		return nil
	end
	local contributions = deepCopy(profile.liveOps.contributions)
	local weeklyContributions = deepCopy(profile.liveOps.weeklyContributions or {})
	local activeEvents = LiveOpsService.GetActiveEvents(nil)
	local featuredDistrict: any = nil
	for _, event in activeEvents do
		local periodDays = math.clamp(math.floor(tonumber(event.rotationPeriodDays) or 7), 1, 31)
		local currentPeriod = math.floor(os.time() / (periodDays * 86_400))
		local weekly = weeklyContributions[event.id]
		local personal = if type(weekly) == "table"
				and math.floor(tonumber(weekly.period) or -1) == currentPeriod
			then math.max(0, math.floor(tonumber(weekly.amount) or 0))
			else 0
		local district = weeklyDistrict(event, os.time(), personal)
		if district then
			district.eventId = event.id
			featuredDistrict = district
			break
		end
	end
	return {
		enabled = isEnabled(),
		manifestVersion = tonumber(manifest.version) or 1,
		activeEvents = activeEvents,
		featuredDistrict = featuredDistrict,
		contributions = contributions,
		weeklyContributions = weeklyContributions,
		dailyContributions = deepCopy(profile.liveOps.dailyContributions or {}),
		claimedMilestones = deepCopy(profile.liveOps.claimedMilestones),
	}
end

return LiveOpsService
