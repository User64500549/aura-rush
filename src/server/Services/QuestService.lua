--!strict

local QuestService = {}

local dataService: any = nil
local economyService: any = nil

local SECONDS_PER_DAY = 86_400
local DAILY_BANK_DAYS = 5
local DAILY_COUNT = 3

type QuestTemplate = {
	kind: string,
	target: number,
	reward: number,
}

local DAILY_TEMPLATES: { QuestTemplate } = {
	{ kind = "complete_round", target = 1, reward = 25 },
	{ kind = "collect_threads", target = 6, reward = 20 },
	{ kind = "hit_beats", target = 8, reward = 20 },
	{ kind = "hit_perfects", target = 3, reward = 20 },
	{ kind = "solve_prism", target = 1, reward = 25 },
	{ kind = "finish_style", target = 1, reward = 15 },
}

local WEEKLY_TEMPLATES: { QuestTemplate } = {
	{ kind = "complete_round", target = 5, reward = 100 },
	{ kind = "collect_threads", target = 30, reward = 80 },
	{ kind = "hit_beats", target = 50, reward = 80 },
	{ kind = "solve_prism", target = 3, reward = 75 },
}

local function utcDay(timestamp: number?): number
	return math.floor((timestamp or os.time()) / SECONDS_PER_DAY)
end

local function utcWeek(day: number): number
	return math.floor(day / 7)
end

local function cloneQuest(template: QuestTemplate, id: string): any
	return {
		id = id,
		kind = template.kind,
		target = template.target,
		progress = 0,
		reward = template.reward,
		completed = false,
		claimed = false,
	}
end

local function ensureQuestState(profile: any): ()
	if type(profile.quests) ~= "table" then
		profile.quests = {}
	end
	if type(profile.quests.daily) ~= "table" then
		profile.quests.daily = {}
	end
	if type(profile.quests.daily.items) ~= "table" then
		profile.quests.daily.items = {}
	end
	if type(profile.quests.daily.bank) ~= "table" then
		profile.quests.daily.bank = {}
	end
	profile.quests.daily.day = math.floor(tonumber(profile.quests.daily.day) or 0)
	profile.quests.daily.rerollsUsed =
		math.max(0, math.floor(tonumber(profile.quests.daily.rerollsUsed) or 0))
	profile.quests.daily.completed = profile.quests.daily.completed == true

	if type(profile.quests.weekly) ~= "table" then
		profile.quests.weekly = {}
	end
	if type(profile.quests.weekly.items) ~= "table" then
		profile.quests.weekly.items = {}
	end
	profile.quests.weekly.week = math.floor(tonumber(profile.quests.weekly.week) or 0)
	profile.quests.weekly.completed = profile.quests.weekly.completed == true

	if type(profile.quests.streak) ~= "table" then
		profile.quests.streak = {}
	end
	profile.quests.streak.count =
		math.max(0, math.floor(tonumber(profile.quests.streak.count) or 0))
	profile.quests.streak.lifetimeDays = math.max(
		profile.quests.streak.count,
		math.floor(tonumber(profile.quests.streak.lifetimeDays) or 0)
	)
	profile.quests.streak.lastCompletedDay =
		math.floor(tonumber(profile.quests.streak.lastCompletedDay) or 0)
	profile.quests.streak.graceCredits =
		math.clamp(math.floor(tonumber(profile.quests.streak.graceCredits) or 1), 0, 2)

	if type(profile.quests.totals) ~= "table" then
		profile.quests.totals = {}
	end
	for _, key in { "dailyCompleted", "weeklyCompleted", "glowDustEarned" } do
		profile.quests.totals[key] =
			math.max(0, math.floor(tonumber(profile.quests.totals[key]) or 0))
	end
end

local function dailyIndexes(userId: number, day: number): { number }
	local seed = math.abs((userId * 1_103_515_245 + day * 12_345) % 2_147_483_647)
	local random = Random.new(seed)
	local available = {}
	for index = 1, #DAILY_TEMPLATES do
		table.insert(available, index)
	end
	local selected = {}
	for _ = 1, DAILY_COUNT do
		local sourceIndex = random:NextInteger(1, #available)
		table.insert(selected, table.remove(available, sourceIndex))
	end
	return selected
end

local function makeDaily(userId: number, day: number): { any }
	local items = {}
	for slot, templateIndex in dailyIndexes(userId, day) do
		table.insert(
			items,
			cloneQuest(DAILY_TEMPLATES[templateIndex], string.format("daily:%d:%d", day, slot))
		)
	end
	return items
end

local function makeWeekly(week: number): { any }
	local items = {}
	for slot, template in WEEKLY_TEMPLATES do
		table.insert(items, cloneQuest(template, string.format("weekly:%d:%d", week, slot)))
	end
	return items
end

local function hasUnclaimedProgress(items: { any }): boolean
	for _, item in items do
		if type(item) == "table" and item.claimed ~= true then
			return true
		end
	end
	return false
end

local function refreshProfile(profile: any, userId: number, now: number?): ()
	ensureQuestState(profile)
	local day = utcDay(now)
	local week = utcWeek(day)
	local daily = profile.quests.daily
	if daily.day ~= day then
		if daily.day > 0 and hasUnclaimedProgress(daily.items) then
			table.insert(daily.bank, {
				day = daily.day,
				expiresDay = daily.day + DAILY_BANK_DAYS,
				items = daily.items,
				completed = daily.completed == true,
			})
		end
		local validBank = {}
		for _, record in daily.bank do
			if
				type(record) == "table"
				and type(record.items) == "table"
				and math.floor(tonumber(record.expiresDay) or 0) >= day
				and hasUnclaimedProgress(record.items)
			then
				table.insert(validBank, record)
			end
		end
		while #validBank > DAILY_BANK_DAYS do
			table.remove(validBank, 1)
		end
		daily.day = day
		daily.items = makeDaily(userId, day)
		daily.bank = validBank
		daily.rerollsUsed = 0
		daily.completed = false
	end

	local weekly = profile.quests.weekly
	if weekly.week ~= week then
		weekly.week = week
		weekly.items = makeWeekly(week)
		weekly.completed = false
	end
end

local function questComplete(items: { any }): boolean
	if #items == 0 then
		return false
	end
	for _, item in items do
		if type(item) ~= "table" or item.completed ~= true then
			return false
		end
	end
	return true
end

local function grantQuestReward(profile: any, item: any): number
	if item.claimed == true or item.completed ~= true then
		return 0
	end
	local grantId = "reward:" .. tostring(item.id)
	local ledger = profile.ledgers.grants.quests
	if ledger[grantId] ~= nil then
		item.claimed = true
		return 0
	end
	local reward = math.clamp(math.floor(tonumber(item.reward) or 0), 0, 10_000)
	ledger[grantId] = os.time()
	item.claimed = true
	profile.glowDust += reward
	profile.economyStats.earned += reward
	profile.quests.totals.glowDustEarned += reward
	return reward
end

local function normalizedCounters(counters: any): { [string]: number }
	local result: { [string]: number } = {}
	if type(counters) ~= "table" then
		return result
	end
	for kind, amountValue in counters do
		if type(kind) == "string" then
			result[kind] = math.max(0, math.floor(tonumber(amountValue) or 0))
		end
	end
	return result
end

local function applyCountersToItems(
	profile: any,
	items: { any },
	counters: { [string]: number },
	consumeCounters: boolean
): number
	local reward = 0
	for _, item in items do
		if type(item) == "table" and item.completed ~= true then
			local available = math.max(0, math.floor(tonumber(counters[item.kind]) or 0))
			local target = math.max(1, math.floor(tonumber(item.target) or 1))
			local progress = math.max(0, math.floor(tonumber(item.progress) or 0))
			local amount = math.min(available, math.max(0, target - progress))
			if amount > 0 then
				item.progress = math.min(target, progress + amount)
				item.completed = item.progress >= item.target
				if consumeCounters then
					counters[item.kind] = available - amount
				end
			end
		end
		reward += grantQuestReward(profile, item)
	end
	return reward
end

local function completeDailySet(profile: any, record: any, completionDay: number): ()
	if record.completed == true or not questComplete(record.items) then
		return
	end
	record.completed = true
	profile.quests.totals.dailyCompleted += 1
	local streak = profile.quests.streak
	if streak.lastCompletedDay ~= completionDay then
		local gap = completionDay - streak.lastCompletedDay
		if streak.lastCompletedDay <= 0 then
			streak.count = 1
		elseif gap == 1 then
			streak.count += 1
		elseif gap == 2 and streak.graceCredits > 0 then
			streak.graceCredits -= 1
			streak.count += 1
		else
			-- Only the current momentum segment resets. Lifetime completion and all
			-- earned rewards remain intact.
			streak.count = 1
			streak.graceCredits = math.max(streak.graceCredits, 1)
		end
		streak.lifetimeDays += 1
		streak.lastCompletedDay = completionDay
		if streak.count % 7 == 0 then
			streak.graceCredits = math.min(2, streak.graceCredits + 1)
		end
	end
end

local function applyCounters(profile: any, userId: number, counters: any, now: number?): any
	refreshProfile(profile, userId, now)
	local day = utcDay(now)
	-- Daily-bank entries share one action budget. A single round may still advance
	-- weekly goals in parallel, but it can no longer be copied into every banked day.
	local dailyCounters = normalizedCounters(counters)
	local reward = applyCountersToItems(profile, profile.quests.daily.items, dailyCounters, true)
	completeDailySet(profile, profile.quests.daily, day)

	for _, record in profile.quests.daily.bank do
		reward += applyCountersToItems(profile, record.items, dailyCounters, true)
		completeDailySet(profile, record, day)
	end

	local weeklyCounters = normalizedCounters(counters)
	reward += applyCountersToItems(profile, profile.quests.weekly.items, weeklyCounters, false)
	if profile.quests.weekly.completed ~= true and questComplete(profile.quests.weekly.items) then
		profile.quests.weekly.completed = true
		profile.quests.totals.weeklyCompleted += 1
	end
	return { glowDust = reward, quests = profile.quests }
end

function QuestService.Init(context: any): ()
	dataService = context.Services.Data
	economyService = context.Services.Economy
end

function QuestService.RefreshPlayer(player: Player, now: number?): any
	local updated = dataService.Update(player, function(profile: any)
		refreshProfile(profile, player.UserId, now)
	end)
	return if updated then QuestService.GetPlayerView(player) else nil
end

function QuestService.RecordProgress(
	player: Player,
	eventId: string,
	counters: { [string]: number },
	now: number?
): any
	if type(counters) ~= "table" or eventId == "" or #eventId > 120 then
		return { ok = false, reason = "invalid_quest_event" }
	end
	return economyService.GrantCurrency(
		player,
		"quest",
		"progress:" .. eventId,
		0,
		function(profile: any)
			return applyCounters(profile, player.UserId, counters, now)
		end
	)
end

function QuestService.RecordRound(player: Player, roundId: string, progress: any): any
	local counters = {
		complete_round = 1,
		collect_threads = math.clamp(
			math.floor(tonumber(progress.threads or progress.threadCollectibles) or 0),
			0,
			8
		),
		hit_beats = math.clamp(math.floor(tonumber(progress.beatHits) or 0), 0, 12),
		hit_perfects = math.clamp(math.floor(tonumber(progress.beatPerfects) or 0), 0, 12),
		solve_prism = if progress.prismComplete == true or progress.prismSolved == true
			then 1
			else 0,
		finish_style = if progress.styleReady == true then 1 else 0,
	}
	return QuestService.RecordProgress(player, "round:" .. roundId, counters, nil)
end

function QuestService.RerollDaily(player: Player, questId: string): any
	local reason = "quest_not_found"
	local replacement: any = nil
	local updated = dataService.Update(player, function(profile: any)
		refreshProfile(profile, player.UserId, nil)
		local daily = profile.quests.daily
		if daily.rerollsUsed >= 1 then
			reason = "reroll_used"
			return
		end
		local replaceIndex: number? = nil
		local usedKinds = {}
		for index, item in daily.items do
			usedKinds[item.kind] = true
			if item.id == questId and item.completed ~= true then
				replaceIndex = index
			end
		end
		if not replaceIndex then
			return
		end
		local candidates = {}
		for _, template in DAILY_TEMPLATES do
			if not usedKinds[template.kind] then
				table.insert(candidates, template)
			end
		end
		if #candidates == 0 then
			reason = "no_reroll_available"
			return
		end
		local templateIndex = ((player.UserId + daily.day + replaceIndex) % #candidates) + 1
		replacement = cloneQuest(
			candidates[templateIndex],
			string.format("daily:%d:r%d", daily.day, replaceIndex)
		)
		daily.items[replaceIndex] = replacement
		daily.rerollsUsed += 1
		reason = "ok"
	end)
	return {
		ok = updated and replacement ~= nil,
		reason = reason,
		replacement = replacement,
		quests = QuestService.GetPlayerView(player),
	}
end

function QuestService.GetPlayerView(player: Player): any
	local clientView = dataService.GetClientView(player)
	return if clientView then clientView.quests else nil
end

return QuestService
