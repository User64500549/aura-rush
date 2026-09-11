--!strict

local RewardService = {}

local dataService: any = nil
local analyticsService: any = nil
local economyService: any = nil
local progressionService: any = nil
local questService: any = nil
local config: any = nil

local function participationAnalytics(ratioValue: any): { [string]: string }
	local ratio = math.clamp(tonumber(ratioValue) or 1, 0.2, 1)
	local bucket = if ratio >= 0.95
		then "full"
		elseif ratio >= 0.7 then "high"
		elseif ratio >= 0.45 then "mid"
		else "low"
	return {
		participationBucket = bucket,
		participationRole = if ratio >= 0.95 then "full_runner" else "backstage_apprentice",
	}
end

local function challengeAnalytics(normalized: any): { [string]: string }
	local threads = math.max(0, math.floor(tonumber(normalized.threads) or 0))
	local beats = math.max(0, math.floor(tonumber(normalized.beats) or 0))
	return {
		beatBucket = if beats >= 10 then "excellent" elseif beats > 0 then "active" else "none",
		prism = tostring(normalized.prismComplete == true),
		threadBucket = if threads >= 8 then "all" elseif threads > 0 then "some" else "none",
	}
end

local function qualificationFor(progress: any, normalized: any): any
	local prismSteps = math.clamp(math.floor(tonumber(progress.prismSteps) or 0), 0, 8)
	local prismAttempts = math.clamp(math.floor(tonumber(progress.prismAttempts) or 0), 0, 10)
	local intentionalActions = normalized.threads
		+ normalized.beats
		+ prismSteps
		+ prismAttempts
		+ (if normalized.prismComplete == true then 1 else 0)
		+ (if progress.styleReady == true then 1 else 0)
	local backstageApprentice = progress.backstageApprentice == true
	local qualified = intentionalActions > 0 or backstageApprentice
	return {
		qualified = qualified,
		reason = if qualified
			then (if backstageApprentice and intentionalActions == 0 then "late_join" else "active")
			else "no_server_validated_activity",
		intentionalActions = intentionalActions,
		backstageApprentice = backstageApprentice,
	}
end

local function wasGranted(profile: any, roundId: string): boolean
	if
		type(profile.ledgers) == "table"
		and type(profile.ledgers.grants) == "table"
		and type(profile.ledgers.grants.rounds) == "table"
		and profile.ledgers.grants.rounds[roundId] ~= nil
	then
		return true
	end
	for _, grantedRound in profile.grantedRounds do
		if grantedRound == roundId then
			return true
		end
	end
	return false
end

local function computeReward(progress: any): (number, any, { string }, any)
	local threads = math.clamp(tonumber(progress.threads) or 0, 0, 8)
	local beats = math.clamp(tonumber(progress.beatHits) or 0, 0, 12)
	local perfects = math.clamp(tonumber(progress.beatPerfects) or 0, 0, beats)
	local prismComplete = progress.prismComplete == true
	local rewardConfig = config.Rewards or {}
	local completionReward = tonumber(rewardConfig.RoundCompletion) or 50
	local participationRatio = math.clamp(tonumber(progress.participationRatio) or 1, 0.2, 1)
	completionReward = math.floor(completionReward * participationRatio + 0.5)
	local threadReward = tonumber(rewardConfig.ThreadCollectible) or 2
	local goodReward = tonumber(rewardConfig.BeatGood) or 2
	local perfectReward = tonumber(rewardConfig.BeatPerfect) or 3
	local prismReward = tonumber(rewardConfig.PrismSolved) or 15
	local readyReward = if progress.styleReady == true
		then (tonumber(rewardConfig.StyleReady) or 5)
		else 0
	local maximumReward = tonumber(rewardConfig.MaximumPerRound) or 150
	local reward = math.floor(
		math.min(
			maximumReward,
			completionReward
				+ threads * threadReward
				+ (beats - perfects) * goodReward
				+ perfects * perfectReward
				+ (if prismComplete then prismReward else 0)
				+ readyReward
		)
	)
	local medals = {}
	if threads >= 8 then
		table.insert(medals, "thread_master")
	end
	if beats >= 10 then
		table.insert(medals, "beat_star")
	end
	if prismComplete then
		table.insert(medals, "prism_mind")
	end
	if #medals >= 3 then
		table.insert(medals, "full_bloom")
	end
	local normalized = {
		threads = math.floor(threads),
		beats = math.floor(beats),
		perfects = math.floor(perfects),
		prismComplete = prismComplete,
	}
	local qualification = qualificationFor(progress, normalized)
	return if qualification.qualified then reward else 0, normalized, medals, qualification
end

function RewardService.Init(context: any): ()
	dataService = context.Services.Data
	analyticsService = context.Services.Analytics
	economyService = context.Services.Economy
	progressionService = context.Services.Progression
	questService = context.Services.Quest
	config = context.Config
end

function RewardService.GrantRound(
	player: Player,
	roundId: string,
	progress: any,
	_seed: number
): any
	local profile = dataService.GetProfile(player)
	if not profile or wasGranted(profile, roundId) then
		return {
			alreadyGranted = true,
			glowDust = 0,
			totalGlowDust = if profile then profile.glowDust else 0,
		}
	end
	local creativeRankBefore = if type(profile.progression) == "table"
		then math.max(1, math.floor(tonumber(profile.progression.creativeRank) or 1))
		else 1

	local reward, normalized, medals, qualification = computeReward(progress)
	local transaction = economyService.GrantCurrency(
		player,
		"round",
		roundId,
		reward,
		function(editable: any)
			if qualification.qualified ~= true then
				return qualification
			end
			editable.stats.roundsPlayed = math.max(
				0,
				math.floor(tonumber(editable.stats.roundsPlayed) or 0)
			) + 1
			editable.stats.finalesCompleted = math.max(
				0,
				math.floor(tonumber(editable.stats.finalesCompleted) or 0)
			) + 1
			editable.stats.bestBeatScore =
				math.max(math.floor(tonumber(editable.stats.bestBeatScore) or 0), normalized.beats)
			editable.stats.threadsCollected = math.max(
				0,
				math.floor(tonumber(editable.stats.threadsCollected) or 0)
			) + normalized.threads
			editable.ledgers = editable.ledgers or {}
			editable.ledgers.grants = editable.ledgers.grants or {}
			editable.ledgers.grants.system = editable.ledgers.grants.system or {}
			editable.ledgers.grants.system["qualified_round:" .. roundId] = os.time()
			-- Saved looks are now created only by an explicit StyleService.SaveLook call.
			return progressionService.ApplyRoundProgress(editable, progress)
		end
	)
	if transaction.ok ~= true or transaction.alreadyApplied == true then
		local current = dataService.GetProfile(player)
		return {
			alreadyGranted = transaction.alreadyApplied == true,
			grantFailed = transaction.ok ~= true,
			reason = transaction.reason,
			glowDust = 0,
			totalGlowDust = if current then current.glowDust else 0,
		}
	end

	local progressionResult = transaction.result or {}
	local questTransaction: any = nil
	if
		qualification.qualified == true
		and questService
		and type(questService.RecordRound) == "function"
	then
		questTransaction = questService.RecordRound(player, roundId, progress)
	end
	local questResult = if questTransaction and type(questTransaction.result) == "table"
		then questTransaction.result
		else {}
	local questGlowDust = math.max(0, math.floor(tonumber(questResult.glowDust) or 0))
	local updated = dataService.GetProfile(player)
	local endingBalance = if updated then updated.glowDust else reward + questGlowDust
	if type(analyticsService.Economy) == "function" and reward > 0 then
		analyticsService.Economy(
			player,
			true,
			reward,
			endingBalance,
			"RoundReward",
			"round_completion",
			participationAnalytics(progress.participationRatio)
		)
		if questGlowDust > 0 then
			analyticsService.Economy(
				player,
				true,
				questGlowDust,
				endingBalance,
				"QuestReward",
				"round_quests",
				nil
			)
		end
	end
	local creativeRank =
		math.max(1, math.floor(tonumber(progressionResult.creativeRank) or creativeRankBefore))
	if
		creativeRank > creativeRankBefore
		and type(analyticsService.ProgressionComplete) == "function"
	then
		analyticsService.ProgressionComplete(
			player,
			"CreativeRank",
			creativeRank,
			"Creative Rank " .. tostring(creativeRank),
			{ phase = "Results" }
		)
	end
	if
		type(progressionResult.schoolLevels) == "table"
		and type(progressionResult.schoolLevelsBefore) == "table"
		and type(analyticsService.ProgressionComplete) == "function"
	then
		for school, levelValue in progressionResult.schoolLevels do
			local level = math.max(1, math.floor(tonumber(levelValue) or 1))
			local previous =
				math.max(1, math.floor(tonumber(progressionResult.schoolLevelsBefore[school]) or 1))
			if level > previous then
				analyticsService.ProgressionComplete(
					player,
					"AuraAtlas_" .. tostring(school),
					level,
					tostring(school) .. " " .. tostring(level),
					{ phase = "Results" }
				)
			end
		end
	end

	if qualification.qualified == true then
		analyticsService.Log(player, "finale_completed", reward, challengeAnalytics(normalized))
	else
		analyticsService.Log(player, "round_unqualified", 1, {
			reason = qualification.reason,
			participationRole = "full_runner",
		})
	end

	local unlockedItemIds = if type(progressionResult.unlockedItemIds) == "table"
		then progressionResult.unlockedItemIds
		else {}
	return {
		alreadyGranted = false,
		qualified = qualification.qualified,
		qualificationReason = qualification.reason,
		glowDust = reward,
		questGlowDust = questGlowDust,
		totalGlowDust = if updated then updated.glowDust else reward + questGlowDust,
		medals = medals,
		unlockedItemId = unlockedItemIds[1],
		unlockedItemIds = unlockedItemIds,
		creativeXp = progressionResult.creativeXp or 0,
		creativeRank = creativeRank,
		schoolGains = progressionResult.schoolGains or {},
		schoolLevels = progressionResult.schoolLevels or {},
		quests = questResult.quests,
	}
end

return RewardService
