--!strict

local RobloxAnalytics = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AnalyticsService = {}

local enabled = true
local flagService: any = nil
local studioEvents = 0
local sessions: { [Player]: any } = {}
local SESSION_MILESTONES = table.freeze({
	{ seconds = 5 * 60, bucket = "5m" },
	{ seconds = 15 * 60, bucket = "15m" },
	{ seconds = 30 * 60, bucket = "30m" },
})
local FORBIDDEN_CUSTOM_FIELD_KEYS = table.freeze({
	activationid = true,
	atelierid = true,
	contentid = true,
	grantid = true,
	lookid = true,
	playerid = true,
	postcardid = true,
	purchaseid = true,
	receiptid = true,
	roundid = true,
	sessionid = true,
	targetuserid = true,
	userid = true,
})

local function isEnabled(): boolean
	return enabled
		and (
			not flagService
			or type(flagService.IsEnabled) ~= "function"
			or flagService.IsEnabled("Analytics")
		)
end

local function safeText(value: any, maximum: number): string
	return string.sub(tostring(value or ""), 1, maximum)
end

local function sanitizeFields(fields: { [string]: any }?): { [string]: string }?
	if type(fields) ~= "table" then
		return nil
	end
	local keys = {}
	for key in fields do
		local normalizedKey = if type(key) == "string" then string.lower(key) else ""
		if
			type(key) == "string"
			and not FORBIDDEN_CUSTOM_FIELD_KEYS[normalizedKey]
			and string.sub(normalizedKey, -6) ~= "userid"
		then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local result: { [string]: string } = {}
	for index = 1, math.min(#keys, 3) do
		local key = keys[index]
		result[safeText(key, 50)] = safeText(fields[key], 100)
	end
	return if next(result) then result else nil
end

local function submit(label: string, callback: () -> ()): ()
	if not isEnabled() then
		return
	end
	if RunService:IsStudio() then
		studioEvents += 1
		print(string.format("[AuraRush/Analytics] %04d %s", studioEvents, label))
		return
	end
	local ok, message = pcall(callback)
	if not ok then
		warn("[AuraRush/Analytics] " .. tostring(message))
	end
end

function AnalyticsService.Init(context: any): ()
	flagService = context.Services and context.Services.Flags or nil
	local configured = context.Config.AnalyticsEnabled
	if type(context.Config.FeatureFlags) == "table" then
		configured = context.Config.FeatureFlags.Analytics
	end
	if type(configured) == "boolean" then
		enabled = configured
	end
end

function AnalyticsService.Log(
	player: Player,
	eventName: string,
	value: number?,
	fields: { [string]: any }?
): ()
	local safeValue = if type(value) == "number"
			and value == value
			and value > -math.huge
			and value < math.huge
		then value
		else 1
	local safeEventName = safeText(eventName, 50)
	local safeFields = sanitizeFields(fields)
	submit(string.format("%s custom:%s %.2f", player.Name, safeEventName, safeValue), function()
		RobloxAnalytics:LogCustomEvent(player, safeEventName, safeValue, safeFields)
	end)
end

function AnalyticsService.LogOnce(
	player: Player,
	eventName: string,
	value: number?,
	fields: { [string]: any }?,
	dedupeKey: string?
): boolean
	local session = sessions[player]
	if not session then
		session = {
			startedAt = os.clock(),
			onboardingRequired = false,
			onboardingCompleted = false,
			once = {},
		}
		sessions[player] = session
	end
	local key = safeText(dedupeKey or eventName, 100)
	if session.once[key] == true then
		return false
	end
	session.once[key] = true
	AnalyticsService.Log(player, eventName, value, fields)
	return true
end

function AnalyticsService.BeginSession(
	player: Player,
	onboardingRequired: boolean,
	fields: { [string]: any }?
): ()
	local previous = sessions[player]
	if previous and previous.active == true then
		return
	end
	local session = {
		active = true,
		startedAt = os.clock(),
		onboardingRequired = onboardingRequired,
		onboardingCompleted = not onboardingRequired,
		once = {},
	}
	sessions[player] = session
	AnalyticsService.LogOnce(player, "join", 1, fields, "session_join")
	if onboardingRequired then
		AnalyticsService.LogOnce(player, "onboarding_start", 1, nil, "onboarding_start")
	end

	task.spawn(function()
		local previousSeconds = 0
		for _, milestone in SESSION_MILESTONES do
			task.wait(milestone.seconds - previousSeconds)
			previousSeconds = milestone.seconds
			if
				sessions[player] ~= session
				or session.active ~= true
				or player.Parent ~= Players
			then
				return
			end
			AnalyticsService.LogOnce(
				player,
				"session_milestone",
				milestone.seconds,
				{ milestone = milestone.bucket },
				"session_" .. milestone.bucket
			)
		end
	end)
end

function AnalyticsService.CompleteOnboarding(player: Player, fields: { [string]: any }?): ()
	local session = sessions[player]
	if session then
		session.onboardingCompleted = true
	end
	AnalyticsService.LogOnce(player, "onboarding_complete", 1, fields, "onboarding_complete")
end

function AnalyticsService.EndSession(player: Player, stage: string?): ()
	local session = sessions[player]
	if not session then
		return
	end
	if session.onboardingRequired == true and session.onboardingCompleted ~= true then
		AnalyticsService.LogOnce(player, "tutorial_abandonment", 1, {
			stage = safeText(stage or "unknown", 32),
		}, "tutorial_abandonment")
	end
	session.active = false
	sessions[player] = nil
end

function AnalyticsService.Destroy(): ()
	for _, session in sessions do
		session.active = false
	end
	table.clear(sessions)
	flagService = nil
end

function AnalyticsService.Onboarding(
	player: Player,
	step: number,
	stepName: string,
	fields: { [string]: any }?
): ()
	local normalizedStep = math.clamp(math.floor(step), 1, 20)
	local safeStepName = safeText(stepName, 50)
	local safeFields = sanitizeFields(fields)
	submit(
		string.format("%s onboarding:%02d:%s", player.Name, normalizedStep, safeStepName),
		function()
			RobloxAnalytics:LogOnboardingFunnelStepEvent(
				player,
				normalizedStep,
				safeStepName,
				safeFields
			)
		end
	)
end

function AnalyticsService.Funnel(
	player: Player,
	funnelName: string,
	sessionId: string,
	step: number,
	stepName: string,
	fields: { [string]: any }?
): ()
	local normalizedStep = math.clamp(math.floor(step), 1, 100)
	local safeFunnelName = safeText(funnelName, 50)
	local safeSessionId = safeText(sessionId, 100)
	local safeStepName = safeText(stepName, 50)
	local safeFields = sanitizeFields(fields)
	submit(
		string.format(
			"%s funnel:%s:%s:%02d:%s",
			player.Name,
			safeFunnelName,
			safeSessionId,
			normalizedStep,
			safeStepName
		),
		function()
			RobloxAnalytics:LogFunnelStepEvent(
				player,
				safeFunnelName,
				safeSessionId,
				normalizedStep,
				safeStepName,
				safeFields
			)
		end
	)
end

function AnalyticsService.Economy(
	player: Player,
	isSource: boolean,
	amount: number,
	endingBalance: number,
	transactionType: string,
	itemSku: string,
	fields: { [string]: any }?
): ()
	local safeAmount = math.max(0, math.floor(amount))
	local safeBalance = math.max(0, math.floor(endingBalance))
	local safeTransactionType = safeText(transactionType, 50)
	local safeItemSku = safeText(itemSku, 100)
	local safeFields = sanitizeFields(fields)
	local flow = if isSource
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	submit(
		string.format(
			"%s economy:%s:%d:%s",
			player.Name,
			if isSource then "source" else "sink",
			safeAmount,
			safeItemSku
		),
		function()
			RobloxAnalytics:LogEconomyEvent(
				player,
				flow,
				"GlowDust",
				safeAmount,
				safeBalance,
				safeTransactionType,
				safeItemSku,
				safeFields
			)
		end
	)
end

function AnalyticsService.ProgressionComplete(
	player: Player,
	pathName: string,
	level: number,
	levelName: string,
	fields: { [string]: any }?
): ()
	local safeLevel = math.max(1, math.floor(level))
	local safePathName = safeText(pathName, 50)
	local safeLevelName = safeText(levelName, 50)
	local safeFields = sanitizeFields(fields)
	submit(
		string.format(
			"%s progression:%s:%d:%s",
			player.Name,
			safePathName,
			safeLevel,
			safeLevelName
		),
		function()
			RobloxAnalytics:LogProgressionCompleteEvent(
				player,
				safePathName,
				safeLevel,
				safeLevelName,
				safeFields
			)
		end
	)
end

function AnalyticsService.GetStudioEventCount(): number
	return studioEvents
end

return AnalyticsService
