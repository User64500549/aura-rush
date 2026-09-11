--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RunDirectorService = require(script.Parent:WaitForChild("RunDirectorService"))
local AuraGenomeService = require(script.Parent:WaitForChild("AuraGenomeService"))

local RoundService = {}

local DEFAULT_DURATIONS: { [string]: number } = {
	Intermission = 20,
	BriefChoice = 25,
	ThreadRun = 100,
	BeatLab = 70,
	PrismPuzzle = 70,
	MixLab = 110,
	Finale = 45,
	Results = 30,
	Cleanup = 4,
}

local PHASE_FUNNEL_STEPS: { [string]: number } = {
	Intermission = 1,
	BriefChoice = 2,
	ThreadRun = 3,
	BeatLab = 4,
	PrismPuzzle = 5,
	MixLab = 6,
	Finale = 7,
	Results = 8,
}

local STUDIO_DURATIONS: { [string]: number } = {
	Intermission = 5,
	BriefChoice = 7,
	ThreadRun = 32,
	BeatLab = 20,
	PrismPuzzle = 24,
	MixLab = 35,
	Finale = 18,
	Results = 12,
	Cleanup = 2,
}

local config: any = nil
local briefCatalog: any = nil
local services: any = nil
local runDirector: any = RunDirectorService
local auraGenomeService: any = AuraGenomeService

local state = "Waiting"
local stateVersion = 0
local roundId = ""
local roundSeed = 0
local startedAt = 0
local endsAt = 0
local participants: { Player } = {}
local participantSet: { [Player]: boolean } = {}
local briefChoices: { any } = {}
local selectedBrief: any = nil
local votes: { [Player]: string } = {}
local results: { [Player]: any } = {}
local nominations: { [Player]: boolean } = {}
local routeVotes: { [Player]: string } = {}
local requeueRequests: { [Player]: boolean } = {}
local backstageApprentices: { [Player]: any } = {}
local runPlan: any = nil
local currentAct: any = nil
local currentActIndex = 0
local teamAuraGenome: any = nil
local bloomRecipe: any = nil
local remixSummary: any = nil
local running = false
local roundActive = false
local tryEnrollLateJoin: ((Player) -> boolean)? = nil

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function participantBucket(count: number): string
	if count <= 1 then
		return "solo"
	elseif count <= 4 then
		return "small_party"
	elseif count <= 8 then
		return "crowd"
	end
	return "full_server"
end

local FALLBACK_BRIEFS = {
	{
		Id = "metro_biolume_zero_g",
		WorldId = "prism_metro",
		Title = "Ночной свет в метро",
		Occasion = "Ночное спасение",
		Aesthetic = "Призматический панк",
		Twist = "Невесомость",
		AccentHex = "28E6FF",
	},
	{
		Id = "cloud_gothic_eclipse",
		WorldId = "cloud_bazaar",
		Title = "Готический облачный квартал",
		Occasion = "Большое открытие",
		Aesthetic = "Ботаническая готика",
		Twist = "Цветовое затмение",
		AccentHex = "FF4EAE",
	},
	{
		Id = "metro_retro_clone",
		WorldId = "prism_metro",
		Title = "Ретро-бал детективов",
		Occasion = "Таинственный вечер",
		Aesthetic = "Ретрофутуризм",
		Twist = "Танец двойников",
		AccentHex = "FFD25C",
	},
}

local function getDuration(phase: string): number
	local configured = config.RoundDurations or config.Durations
	local studioFast = RunService:IsStudio() and (config.StudioFastMode ~= false)
	if studioFast then
		local fast = config.StudioDurations or config.FastDurations
		if type(fast) == "table" and type(fast[phase]) == "number" then
			return math.max(1, fast[phase])
		end
		return STUDIO_DURATIONS[phase] or 5
	end
	if type(configured) == "table" and type(configured[phase]) == "number" then
		return math.max(1, configured[phase])
	end
	return DEFAULT_DURATIONS[phase] or 10
end

local function getBriefId(brief: any): string
	if type(brief) ~= "table" then
		return ""
	end
	return tostring(brief.Id or brief.id or "")
end

local function getWorldId(brief: any): string
	if type(brief) ~= "table" then
		return "prism_metro"
	end
	local value = brief.WorldId or brief.worldId or brief.World or brief.world
	if type(value) == "table" then
		value = value.Id or value.id
	end
	if
		value == "prism_metro"
		or value == "cloud_bazaar"
		or value == "moonlit_greenhouse"
		or value == "orbital_boardwalk"
		or value == "velvet_archive"
		or value == "solar_cathedral"
	then
		return value
	end
	return "prism_metro"
end

local function chooseBriefOptions(seed: number): { any }
	if type(briefCatalog.GetChoices) == "function" then
		local ok, choices = pcall(briefCatalog.GetChoices, seed, 3)
		if ok and type(choices) == "table" and #choices >= 3 then
			return choices
		end
	end
	return table.clone(FALLBACK_BRIEFS)
end

local function compactParticipants(): ()
	local nextList = {}
	table.clear(participantSet)
	for _, player in participants do
		if player.Parent == Players then
			table.insert(nextList, player)
			participantSet[player] = true
		end
	end
	participants = nextList
end

local function snapshotFor(player: Player): any
	local challengeProgress = services.Challenge.GetProgress(player)
	local apprentice = backstageApprentices[player]
	local participantUserIds = {}
	for _, participant in participants do
		if participant.Parent == Players then
			table.insert(participantUserIds, participant.UserId)
		end
	end
	table.sort(participantUserIds)
	return {
		state = state,
		stateVersion = stateVersion,
		roundId = roundId,
		startedAt = startedAt,
		endsAt = endsAt,
		briefChoices = briefChoices,
		brief = selectedBrief,
		isParticipant = participantSet[player] == true,
		profile = services.Data.GetClientView(player),
		progress = challengeProgress,
		result = results[player],
		serverNow = Workspace:GetServerTimeNow(),
		seed = roundSeed,
		participantCount = #participants,
		participantUserIds = participantUserIds,
		participationRole = if apprentice
			then "BackstageApprentice"
			elseif participantSet[player] then "Runner"
			else "Spectator",
		backstageApprentice = apprentice,
		runPlan = runPlan,
		currentAct = currentAct,
		currentActIndex = currentActIndex,
		routeChoices = if type(runPlan) == "table" then runPlan.routeOptions else {},
		modifier = if type(runPlan) == "table" then runPlan.modifier else nil,
		auraGenome = teamAuraGenome,
		bloomRecipe = bloomRecipe,
		requeueRequested = requeueRequests[player] == true,
		remix = if services.Remix then services.Remix.GetSnapshot(player) else nil,
	}
end

local function broadcastSnapshot(): ()
	for _, player in Players:GetPlayers() do
		services.Remote.FireClient("RoundSnapshot", player, snapshotFor(player))
	end
end

local function setState(nextState: string, duration: number): ()
	local previousState = state
	local performance = services.Performance
	if performance and type(performance.EndPhase) == "function" then
		performance.EndPhase(previousState)
	end
	state = nextState
	stateVersion += 1
	startedAt = Workspace:GetServerTimeNow()
	endsAt = startedAt + duration
	services.World.SetPhase(nextState)
	if services.Remix and type(services.Remix.SetPhase) == "function" then
		services.Remix.SetPhase(nextState, currentAct)
	end
	if performance and type(performance.BeginPhase) == "function" then
		performance.BeginPhase(nextState)
	end
	broadcastSnapshot()
	if
		nextState == "BriefChoice"
		and services.CityPulse
		and type(services.CityPulse.OnRunStarted) == "function"
	then
		services.CityPulse.OnRunStarted(participants)
	end
	for _, player in participants do
		if previousState ~= nextState then
			services.Analytics.Log(
				player,
				"phase_" .. string.lower(nextState),
				1,
				{ phase = nextState }
			)
		end
		local funnelStep = PHASE_FUNNEL_STEPS[nextState]
		if
			funnelStep
			and previousState ~= nextState
			and type(services.Analytics.Funnel) == "function"
		then
			services.Analytics.Funnel(
				player,
				"RoundJourney",
				roundId,
				funnelStep,
				nextState,
				{ participantCount = tostring(#participants) }
			)
		end
		if type(services.Analytics.Onboarding) == "function" then
			local profile = services.Data.GetProfile(player)
			local roundsPlayed = if profile and type(profile.stats) == "table"
				then math.max(0, math.floor(tonumber(profile.stats.roundsPlayed) or 0))
				else 0
			if nextState == "ThreadRun" and roundsPlayed == 0 then
				services.Analytics.Onboarding(player, 3, "First Run Started", {
					phase = "ThreadRun",
				})
			elseif nextState == "Results" and roundsPlayed == 1 then
				services.Analytics.Onboarding(player, 4, "First Bloom Completed", {
					phase = "Results",
				})
			end
		end
	end
end

local function waitForDeadline(canSkipWhenReady: boolean?, challengePhase: string?): boolean
	while running and Workspace:GetServerTimeNow() < endsAt do
		compactParticipants()
		if #participants == 0 and state ~= "Intermission" and state ~= "BriefChoice" then
			return true
		end
		if canSkipWhenReady and Workspace:GetServerTimeNow() - startedAt >= 10 then
			local allReady = #participants > 0
			for _, player in participants do
				if not services.Style.IsReady(player) then
					allReady = false
					break
				end
			end
			if allReady then
				return true
			end
		end
		if challengePhase and Workspace:GetServerTimeNow() - startedAt >= 3 then
			local complete = if challengePhase == "Guardian" and services.Remix
				then services.Remix.IsGuardianComplete()
				else services.Challenge.IsPhaseComplete(challengePhase)
			if complete then
				return true
			end
		end
		if state == "Results" and Workspace:GetServerTimeNow() - startedAt >= 3 then
			local allRequeued = #participants > 0
			for _, player in participants do
				if not requeueRequests[player] then
					allRequeued = false
					break
				end
			end
			if allRequeued then
				return true
			end
		end
		task.wait(0.2)
	end
	return running
end

local function captureParticipants(): ()
	table.clear(participants)
	table.clear(participantSet)
	table.clear(backstageApprentices)
	for _, player in Players:GetPlayers() do
		if RoundService.IsPlayerEligible(player) then
			table.insert(participants, player)
			participantSet[player] = true
		end
	end
end

local function teleportPlayer(player: Player, baseCFrame: CFrame, index: number): ()
	local character = player.Character
	if not character then
		return
	end
	local row = math.floor((index - 1) / 4)
	local column = (index - 1) % 4
	local offset = CFrame.new((column - 1.5) * 5, 0, row * 5)
	local ok, message = pcall(function()
		character:PivotTo(baseCFrame * offset)
	end)
	if not ok then
		warn("[AuraRush/Round] Teleport failed: " .. tostring(message))
	end
end

local function teleportParticipants(phase: string): ()
	local worldId = getWorldId(selectedBrief)
	local spawnCFrame = services.World.GetSpawn(phase, worldId)
	for index, player in participants do
		teleportPlayer(player, spawnCFrame, index)
	end
end

local function joinActIndexForState(targetState: string): number?
	if targetState == "ThreadRun" then
		return 1
	elseif targetState == "BeatLab" then
		return 2
	elseif targetState == "PrismPuzzle" then
		return 3
	elseif targetState == "MixLab" then
		return 4
	elseif targetState == "Finale" then
		return 5
	end
	return nil
end

local function sceneForCurrentState(): string
	if
		(state == "ThreadRun" or state == "BeatLab" or state == "PrismPuzzle")
		and type(currentAct) == "table"
		and type(currentAct.sceneId) == "string"
	then
		return currentAct.sceneId
	end
	return state
end

tryEnrollLateJoin = function(player: Player): boolean
	if participantSet[player] or not RoundService.IsPlayerEligible(player) then
		return false
	end
	local preActJoin = state == "BriefChoice"
	local joinActIndex = joinActIndexForState(state)
	if
		not RoundService.CanJoinInState(state)
		or roundId == ""
		or #participants >= (config.MaximumPlayers or 12)
	then
		return false
	end

	if preActJoin then
		table.insert(participants, player)
		participantSet[player] = true
		services.Style.ApplyToCharacter(player)
		teleportPlayer(
			player,
			services.World.GetSpawn("Hub", getWorldId(selectedBrief)),
			#participants
		)
		services.Analytics.Log(player, "pre_act_join", 1, {
			phase = state,
			choice = if runPlan == nil then "brief" else "route",
		})
		broadcastSnapshot()
		return true
	end

	local resolvedActIndex = joinActIndex :: number
	local directorConfig = config.RunDirector
	local minimumRemaining = if type(directorConfig) == "table"
		then tonumber(directorConfig.LateJoinMinimumSeconds) or 10
		else 10
	if endsAt - Workspace:GetServerTimeNow() < minimumRemaining then
		return false
	end

	table.insert(participants, player)
	participantSet[player] = true
	local participationRatio = math.clamp((6 - resolvedActIndex) / 5, 0.2, 1)
	backstageApprentices[player] = {
		joinedAt = Workspace:GetServerTimeNow(),
		joinedState = state,
		joinedActIndex = resolvedActIndex,
		participationRatio = participationRatio,
	}
	services.Challenge.AddParticipant(player, roundId, resolvedActIndex, true)
	if services.Remix and type(services.Remix.AddParticipant) == "function" then
		services.Remix.AddParticipant(player)
	end
	services.Style.ApplyToCharacter(player)
	teleportPlayer(
		player,
		services.World.GetSpawn(sceneForCurrentState(), getWorldId(selectedBrief)),
		#participants
	)
	services.Remote.FireClient("ProgressUpdate", player, {
		kind = "BackstageSetup",
		roundId = roundId,
		joinedState = state,
		participationRatio = participationRatio,
		currentAct = currentAct,
	})
	services.Analytics.Log(player, "backstage_apprentice_join", participationRatio, {
		phase = state,
	})
	broadcastSnapshot()
	return true
end

local function selectVoteWinner(): any
	local counts: { [string]: number } = {}
	for _, choice in briefChoices do
		counts[getBriefId(choice)] = 0
	end
	for player, briefId in votes do
		if participantSet[player] and counts[briefId] ~= nil then
			counts[briefId] += 1
		end
	end

	local winner = briefChoices[1]
	local bestCount = -1
	for _, choice in briefChoices do
		local count = counts[getBriefId(choice)] or 0
		if count > bestCount then
			winner = choice
			bestCount = count
		end
	end
	return winner
end

local function applyRouteVoteWinner(): ()
	if type(runPlan) ~= "table" or type(runPlan.routeOptions) ~= "table" then
		return
	end
	local counts: { [string]: number } = {}
	for _, option in runPlan.routeOptions do
		if type(option) == "table" and type(option.id) == "string" then
			counts[option.id] = 0
		end
	end
	for player, routeId in routeVotes do
		if participantSet[player] and counts[routeId] ~= nil then
			counts[routeId] += 1
		end
	end
	local winnerId = tostring(runPlan.selectedRouteId or "")
	local bestCount = counts[winnerId] or 0
	for _, option in runPlan.routeOptions do
		local routeId = if type(option) == "table" then option.id else nil
		if type(routeId) == "string" then
			local count = counts[routeId] or 0
			if count > bestCount then
				winnerId = routeId
				bestCount = count
			end
		end
	end
	if type(runDirector.ApplyRoute) == "function" then
		runPlan = runDirector.ApplyRoute(runPlan, winnerId, teamAuraGenome)
	else
		runPlan.selectedRouteId = winnerId
	end
	if services.World and type(services.World.ApplyRunPlan) == "function" then
		services.World.ApplyRunPlan(runPlan)
		services.Challenge.BindWorld()
	end
end

local function fallbackRunPlan(): any
	return {
		version = 6,
		seamless = true,
		seed = roundSeed,
		worldId = getWorldId(selectedBrief),
		selectedRouteId = "classic_bloom",
		routeOptions = {
			{
				id = "classic_bloom",
				title = "Прямой маршрут",
				description = "Три базовых испытания.",
			},
			{
				id = "kinetic_cascade",
				title = "Разгон",
				description = "Больше движения и быстрых решений.",
			},
		},
		modifier = {
			id = "living_runway",
			title = "Живая дорожка",
			description = "Сигнал идёт волной от края к краю.",
			rhythmScale = 1,
			laneTransform = "wave",
		},
		acts = {
			{
				index = 1,
				id = "thread_run",
				legacyPhase = "ThreadRun",
				sceneId = "ThreadRun",
				targetScale = 1,
				teamCompletionRatio = 0.65,
				seed = roundSeed + 1,
				modifierId = "living_runway",
				laneTransform = "wave",
				cellId = "prism_metro:signal_gate",
				cellTitle = "Сигнальные ворота",
				cellShape = "gate",
				mechanicTags = { "signal_gate", "role_spotlight" },
			},
			{
				index = 2,
				id = "beat_lab",
				legacyPhase = "BeatLab",
				sceneId = "BeatLab",
				targetScale = 1,
				teamCompletionRatio = 0.65,
				seed = roundSeed + 2,
				modifierId = "living_runway",
				laneTransform = "wave",
				cellId = "prism_metro:duet_platform",
				cellTitle = "Дуэт-платформа",
				cellShape = "duet",
				mechanicTags = { "duet_lock", "tempo_charge", "role_spotlight" },
			},
			{
				index = 3,
				id = "prism_puzzle",
				legacyPhase = "PrismPuzzle",
				sceneId = "PrismPuzzle",
				targetScale = 1,
				teamCompletionRatio = 0.65,
				seed = roundSeed + 3,
				modifierId = "living_runway",
				laneTransform = "wave",
				cellId = "prism_metro:palette_switch",
				cellTitle = "Смена палитры",
				cellShape = "prism",
				mechanicTags = { "palette_shift", "role_spotlight" },
			},
		},
	}
end

local function composeRunPlan(): ()
	teamAuraGenome = auraGenomeService.CaptureTeam(participants, services.Style)
	local flags = services.Flags
	local adaptiveEnabled = true
	local newChallengesEnabled = true
	if flags and type(flags.Get) == "function" then
		local adaptiveValue = flags.Get("AdaptiveRuns")
		local challengeFlagValue = flags.Get("NewChallenges")
		if type(adaptiveValue) == "boolean" then
			adaptiveEnabled = adaptiveValue
		end
		if type(challengeFlagValue) == "boolean" then
			newChallengesEnabled = challengeFlagValue
		end
	end
	if not adaptiveEnabled then
		runPlan = fallbackRunPlan()
		runPlan.adaptive = false
		runPlan.newChallenges = false
		if services.World and type(services.World.ApplyRunPlan) == "function" then
			services.World.ApplyRunPlan(runPlan)
			services.Challenge.BindWorld()
		end
		return
	end
	local ok, generated =
		pcall(runDirector.Generate, roundSeed, #participants, selectedBrief, teamAuraGenome)
	if ok and type(generated) == "table" and type(generated.acts) == "table" then
		runPlan = generated
	else
		warn("[AuraRush/Round] Run Director fallback: " .. tostring(generated))
		runPlan = fallbackRunPlan()
		runPlan.adaptive = false
		runPlan.newChallenges = false
		if services.World and type(services.World.ApplyRunPlan) == "function" then
			services.World.ApplyRunPlan(runPlan)
			services.Challenge.BindWorld()
		end
		return
	end
	runPlan.adaptive = true
	runPlan.newChallenges = newChallengesEnabled
	if not newChallengesEnabled then
		local legacyActs = fallbackRunPlan().acts
		for index, legacyAct in legacyActs do
			runPlan.acts[index] = legacyAct
		end
	end
	local modifier = runPlan.modifier
	for _, act in runPlan.acts do
		if type(modifier) == "table" and type(modifier.rhythmScale) == "number" then
			act.rhythmScale = modifier.rhythmScale
		end
	end
	if services.World and type(services.World.ApplyRunPlan) == "function" then
		services.World.ApplyRunPlan(runPlan)
		services.Challenge.BindWorld()
	end
end

local function runChallengePhase(actIndex: number): boolean
	local act = if type(runPlan) == "table" and type(runPlan.acts) == "table"
		then runPlan.acts[actIndex]
		else nil
	if type(act) ~= "table" then
		act = fallbackRunPlan().acts[actIndex]
	end
	currentAct = act
	currentActIndex = actIndex
	local phase = tostring(act.legacyPhase)
	local sceneId = tostring(act.sceneId or phase)
	services.World.SetActiveAct(tostring(act.id), sceneId)
	if actIndex == 1 or type(runPlan) ~= "table" or runPlan.seamless ~= true then
		teleportParticipants(sceneId)
	end
	services.Challenge.Begin(phase, roundId, participants, tonumber(act.seed) or roundSeed, act)
	if actIndex == 1 then
		local modifierId = "none"
		if type(runPlan) == "table" and type(runPlan.modifier) == "table" then
			modifierId = tostring(runPlan.modifier.id or "none")
		end
		for _, player in participants do
			services.Analytics.Log(player, "round_start", 1, {
				modifier = modifierId,
				players = participantBucket(#participants),
			})
		end
	end
	setState(phase, getDuration(phase))
	if not waitForDeadline(false, phase) then
		return false
	end
	services.Challenge.EndPhase(phase)
	return true
end

local function buildPerformanceSummary(): any
	local completionTotal = 0
	local masteryTotal = 0
	local teamworkTotal = 0
	local activePlayers = 0
	for _, player in participants do
		local playerProgress = services.Challenge.GetProgress(player)
		if type(playerProgress) == "table" then
			local actions = math.max(0, tonumber(playerProgress.threads) or 0)
				+ math.max(0, tonumber(playerProgress.beatHits) or 0)
				+ math.max(0, tonumber(playerProgress.prismSteps) or 0)
			local targets = math.max(0, tonumber(playerProgress.threadTarget) or 0)
				+ math.max(0, tonumber(playerProgress.beatTarget) or 0)
				+ math.max(0, tonumber(playerProgress.prismTarget) or 0)
			local completion = if targets > 0 then math.clamp(actions / targets, 0, 1) else 0
			local beatHits = math.max(0, tonumber(playerProgress.beatHits) or 0)
			local precision = if beatHits > 0
				then math.clamp((tonumber(playerProgress.beatPerfects) or 0) / beatHits, 0, 1)
				else completion
			local assists = math.max(
				0,
				tonumber(playerProgress.mechanicAssists) or tonumber(playerProgress.assists) or 0
			)
			local mechanicSteps = math.max(0, tonumber(playerProgress.mechanicSteps) or 0)
			local teamContribution =
				math.max(0, tonumber(playerProgress.teamContribution) or mechanicSteps)
			local contributionRatio = if mechanicSteps > 0
				then math.clamp(teamContribution / mechanicSteps, 0, 1)
				else 0
			local teamwork = math.clamp(
				tonumber(playerProgress.teamworkRatio)
					or (completion * 0.62 + math.min(assists, 5) * 0.06 + contributionRatio * 0.08),
				0,
				1
			)
			completionTotal += completion
			masteryTotal += precision
			teamworkTotal += teamwork
			if actions > 0 then
				activePlayers += 1
			end
		end
	end
	local count = math.max(#participants, 1)
	return {
		completion = math.clamp(completionTotal / count, 0, 1),
		mastery = math.clamp(masteryTotal / count, 0, 1),
		teamwork = math.clamp(teamworkTotal / count, 0, 1),
		activeRatio = math.clamp(activePlayers / count, 0, 1),
		participantCount = #participants,
	}
end

local function beginFinale(): boolean
	currentAct = nil
	currentActIndex = 5
	services.World.SetActiveAct("world_bloom", "Finale")
	teleportParticipants("Finale")
	for _, player in participants do
		services.Style.ApplyToCharacter(player)
	end
	teamAuraGenome = auraGenomeService.CaptureTeam(participants, services.Style)
	local performance = buildPerformanceSummary()
	bloomRecipe = auraGenomeService.BuildBloomRecipe(
		roundId,
		roundSeed,
		selectedBrief,
		teamAuraGenome,
		runPlan,
		performance
	)
	local summary = services.Style.GetSummary(participants)
	summary.worldId = getWorldId(selectedBrief)
	summary.roundId = roundId
	summary.startTime = Workspace:GetServerTimeNow() + 1
	summary.startsAt = summary.startTime
	summary.duration = getDuration("Finale")
	summary.twistId = selectedBrief and (selectedBrief.TwistId or selectedBrief.twistId) or nil
	summary.aestheticId = selectedBrief and (selectedBrief.AestheticId or selectedBrief.aestheticId)
		or nil
	summary.occasionId = selectedBrief and (selectedBrief.OccasionId or selectedBrief.occasionId)
		or nil
	summary.accentHex = selectedBrief and (selectedBrief.AccentHex or selectedBrief.accentHex)
		or nil
	summary.recipe = bloomRecipe
	summary.bloomActs = bloomRecipe.bloomActs
	summary.performance = performance
	summary.auraGenome = teamAuraGenome
	summary.runPlan = runPlan
	summary.routeId = if type(runPlan) == "table" then runPlan.selectedRouteId else nil
	summary.modifier = if type(runPlan) == "table" then runPlan.modifier else nil
	services.World.BeginWorldBloom(bloomRecipe, summary.duration)
	services.Remote.FireAll("BloomStarted", summary)
	if services.Remix and type(services.Remix.BeginGuardian) == "function" then
		services.Remix.BeginGuardian(getWorldId(selectedBrief))
	end
	setState("Finale", getDuration("Finale"))
	return waitForDeadline(false, "Guardian")
end

local function grantResults(): ()
	table.clear(results)
	local challengeResults = services.Challenge.Finish()
	for _, player in participants do
		local playerProgress = challengeResults[player]
			or {
				threads = 0,
				beatHits = 0,
				beatPerfects = 0,
				prismSteps = 0,
				prismComplete = false,
				prismAttempts = 0,
			}
		playerProgress.styleReady = services.Style.IsReady(player)
		local apprentice = backstageApprentices[player]
		if apprentice then
			playerProgress.backstageApprentice = true
			playerProgress.participationRatio = apprentice.participationRatio
		end
		local result = services.Reward.GrantRound(player, roundId, playerProgress, roundSeed)
		result.participationRole = if apprentice then "BackstageApprentice" else "Runner"
		result.participationRatio = playerProgress.participationRatio or 1
		results[player] = result
		services.Analytics.Log(player, "round_complete", 1, {
			qualified = tostring(result.qualified == true),
			role = if apprentice then "apprentice" else "runner",
		})
		local liveOps = services.LiveOps
		local community = services.Community
		if
			(liveOps and type(liveOps.Contribute) == "function")
			or (community and type(community.Contribute) == "function")
		then
			local liveOpsConfig = config.LiveOps
			local eventId = if type(liveOpsConfig) == "table"
				then tostring(liveOpsConfig.CommunityEventId or "community_canvas_genesis")
				else "community_canvas_genesis"
			local contribution = if type(liveOpsConfig) == "table"
				then tonumber(liveOpsConfig.ContributionPerRound) or 10
				else 10
			local contribute = if community and type(community.Contribute) == "function"
				then community.Contribute
				else liveOps.Contribute
			local ok, message = pcall(contribute, player, eventId, roundId, contribution)
			if not ok then
				warn("[AuraRush/Round] LiveOps contribution failed: " .. tostring(message))
			end
		end
		local socialCreation = services.SocialCreation
		if socialCreation and type(socialCreation.RecordRoundContribution) == "function" then
			local ok, message = pcall(socialCreation.RecordRoundContribution, player)
			if not ok then
				warn("[AuraRush/Round] Social contribution failed: " .. tostring(message))
			end
		end
		services.Remote.FireClient("ProgressUpdate", player, {
			kind = "Result",
			result = result,
			profile = services.Data.GetClientView(player),
		})
	end
end

local function cleanupRound(): ()
	local hub = services.World.GetSpawn("Hub", nil)
	for index, player in participants do
		teleportPlayer(player, hub, index)
	end
	table.clear(participants)
	table.clear(participantSet)
	table.clear(votes)
	table.clear(nominations)
	table.clear(backstageApprentices)
	table.clear(routeVotes)
	table.clear(requeueRequests)
	briefChoices = {}
	selectedBrief = nil
	runPlan = nil
	currentAct = nil
	currentActIndex = 0
	teamAuraGenome = nil
	bloomRecipe = nil
	remixSummary = nil
	services.World.SetActiveAct(nil, nil)
	services.Style.ResetReady()
	if services.Remix and type(services.Remix.Reset) == "function" then
		services.Remix.Reset()
	end
end

local function runRound(): ()
	roundId = HttpService:GenerateGUID(false)
	roundSeed = os.time() + stateVersion * 7919
	table.clear(votes)
	table.clear(results)
	table.clear(nominations)
	table.clear(backstageApprentices)
	table.clear(routeVotes)
	table.clear(requeueRequests)
	selectedBrief = nil
	runPlan = nil
	currentAct = nil
	currentActIndex = 0
	teamAuraGenome = nil
	bloomRecipe = nil
	remixSummary = nil
	briefChoices = chooseBriefOptions(roundSeed)
	services.World.ResetRound(roundId)

	setState("Intermission", getDuration("Intermission"))
	if not waitForDeadline(false) then
		return
	end
	captureParticipants()
	if #participants == 0 then
		cleanupRound()
		return
	end
	for _, player in participants do
		services.Analytics.Log(player, "queue_start", 1, {
			players = participantBucket(#participants),
		})
	end

	setState("BriefChoice", getDuration("BriefChoice"))
	if not waitForDeadline(false) then
		return
	end
	selectedBrief = selectVoteWinner()
	composeRunPlan()
	if runPlan.adaptive ~= false then
		currentAct = {
			id = "route_choice",
			index = 0,
			legacyPhase = "BriefChoice",
			sceneId = "Hub",
			semantic = "branch_vote",
		}
		services.World.SetActiveAct("route_choice", "Hub")
		local directorConfig = config.RunDirector
		local branchVoteSeconds = if type(directorConfig) == "table"
			then tonumber(directorConfig.BranchVoteSeconds) or 8
			else 8
		setState("BriefChoice", math.max(branchVoteSeconds, 3))
		if not waitForDeadline(false) then
			return
		end
		applyRouteVoteWinner()
		currentAct = nil
		broadcastSnapshot()
	end
	if services.Remix and type(services.Remix.BeginRound) == "function" then
		services.Remix.BeginRound(roundId, participants, runPlan, teamAuraGenome)
	end

	if not runChallengePhase(1) then
		return
	end
	if #participants == 0 then
		cleanupRound()
		return
	end
	if not runChallengePhase(2) then
		return
	end
	if #participants == 0 then
		cleanupRound()
		return
	end
	if not runChallengePhase(3) then
		return
	end
	if #participants == 0 then
		cleanupRound()
		return
	end

	services.Style.ResetReady()
	currentAct = nil
	currentActIndex = 4
	services.World.SetActiveAct("mix_lab", "MixLab")
	teleportParticipants("MixLab")
	for _, player in participants do
		services.Style.ApplyToCharacter(player)
	end
	setState("MixLab", getDuration("MixLab"))
	if not waitForDeadline(true) then
		return
	end
	if not beginFinale() or not running then
		return
	end
	grantResults()
	if services.Remix and type(services.Remix.CompleteRound) == "function" then
		remixSummary = services.Remix.CompleteRound(
			getWorldId(selectedBrief),
			tostring(if type(runPlan) == "table" then runPlan.selectedRouteId or "" else "")
		)
		for _player, result in results do
			if type(result) == "table" then
				result.remix = remixSummary
			end
		end
	end
	setState("Results", getDuration("Results"))
	if not waitForDeadline(false) then
		return
	end

	setState("Cleanup", getDuration("Cleanup"))
	cleanupRound()
	waitForDeadline(false)
end

function RoundService.Init(context: any): ()
	config = context.Config
	briefCatalog = context.BriefCatalog
	services = context.Services
	runDirector = context.Services.RunDirector or RunDirectorService
	auraGenomeService = context.Services.AuraGenome or AuraGenomeService
	if type(runDirector.Init) == "function" then
		runDirector.Init(context)
	end
	if type(auraGenomeService.Init) == "function" then
		auraGenomeService.Init(context)
	end

	services.Remote.BindFunction("RequestSnapshot", 1, function(player: Player, _payload: any)
		local enroll = tryEnrollLateJoin
		if enroll then
			enroll(player)
		end
		return snapshotFor(player)
	end)
	services.Remote.BindEvent("VoteBrief", 2, function(player: Player, payload: any)
		if
			state ~= "BriefChoice"
			or runPlan ~= nil
			or not participantSet[player]
			or type(payload) ~= "table"
		then
			return
		end
		local requestedId = payload.briefId
		if isFiniteNumber(payload.index) then
			local choice = briefChoices[math.floor(payload.index)]
			requestedId = if choice then getBriefId(choice) else nil
		end
		if type(requestedId) ~= "string" or #requestedId > 100 then
			return
		end
		for _, choice in briefChoices do
			if getBriefId(choice) == requestedId then
				votes[player] = requestedId
				services.Remote.FireClient("Toast", player, { key = "vote_saved" })
				return
			end
		end
	end)
	services.Remote.BindEvent("Nominate", 1, function(player: Player, payload: any)
		if state ~= "Results" or nominations[player] or type(payload) ~= "table" then
			return
		end
		local targetUserId = payload.targetUserId
		if not isFiniteNumber(targetUserId) or targetUserId == player.UserId then
			return
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target or not participantSet[target] then
			return
		end
		nominations[player] = true
		local nominationXp = if type(config.Rewards) == "table"
			then math.max(0, math.floor(tonumber(config.Rewards.PositiveNominationXp) or 3))
			else 3
		if
			nominationXp > 0
			and services.Progression
			and type(services.Progression.GrantSchoolXp) == "function"
		then
			services.Progression.GrantSchoolXp(
				target,
				"Camera",
				nominationXp,
				`nomination:{roundId}:{player.UserId}`
			)
			services.Remote.FireClient("ProgressUpdate", target, {
				kind = "Profile",
				profile = services.Data.GetClientView(target),
			})
		end
		services.Analytics.Log(player, "positive_nomination_sent", 1, {
			phase = "Results",
			recipient = "participant",
		})
		services.Remote.FireClient(
			"Toast",
			target,
			{ key = "positive_nomination", from = player.DisplayName }
		)
	end)
	Players.PlayerRemoving:Connect(function(player)
		backstageApprentices[player] = nil
	end)
end

function RoundService.EvaluateProfileEligibility(
	profile: any,
	firstMiracleRequired: boolean
): (boolean, string)
	if type(profile) ~= "table" then
		return false, "profile_unavailable"
	end
	local settings = profile.settings
	if type(settings) == "table" and settings.onboardingComplete == true then
		return true, "onboarding_complete"
	end
	local miracle = profile.firstMiracle
	if type(miracle) == "table" and miracle.status == "Complete" then
		return true, "first_miracle_complete"
	end
	if not firstMiracleRequired then
		return true, "first_miracle_disabled"
	end
	return false, "first_miracle_incomplete"
end

function RoundService.IsPlayerEligible(player: Player): boolean
	if not services or not services.Data or not services.Data.IsLoaded(player) then
		return false
	end
	local miracleConfig = if type(config.FirstMiracle) == "table" then config.FirstMiracle else {}
	local firstMiracleRequired = miracleConfig.Enabled ~= false
	local flags = services.Flags
	if flags and type(flags.IsEnabled) == "function" then
		firstMiracleRequired = firstMiracleRequired and flags.IsEnabled("FirstMiracle")
	elseif type(config.FeatureFlags) == "table" then
		firstMiracleRequired = firstMiracleRequired and config.FeatureFlags.FirstMiracle == true
	end
	local eligible = RoundService.EvaluateProfileEligibility(
		services.Data.GetProfile(player),
		firstMiracleRequired
	)
	return eligible
end

function RoundService.CanJoinInState(targetState: string): boolean
	return targetState == "BriefChoice" or joinActIndexForState(targetState) ~= nil
end

function RoundService.GetEligiblePlayerCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if RoundService.IsPlayerEligible(player) then
			count += 1
		end
	end
	return count
end

function RoundService.Start(): ()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while running do
			local minimumPlayers = math.max(1, math.floor(tonumber(config.MinimumPlayers) or 1))
			while running and RoundService.GetEligiblePlayerCount() < minimumPlayers do
				if state ~= "Waiting" then
					state = "Waiting"
					stateVersion += 1
					startedAt = Workspace:GetServerTimeNow()
					endsAt = 0
				end
				task.wait(1)
			end
			if not running then
				break
			end
			roundActive = true
			local ok, message = xpcall(runRound, debug.traceback)
			roundActive = false
			if not ok then
				warn("[AuraRush/Round] Recovered from round error: " .. tostring(message))
				state = "Cleanup"
				stateVersion += 1
				cleanupRound()
				task.wait(2)
			end
		end
	end)
end

function RoundService.Stop(): ()
	running = false
	local deadline = os.clock() + 2
	while roundActive and os.clock() < deadline do
		task.wait(0.05)
	end
end

function RoundService.GetSnapshot(player: Player): any
	local enroll = tryEnrollLateJoin
	if enroll then
		enroll(player)
	end
	return snapshotFor(player)
end

function RoundService.TryEnrollLateJoin(player: Player): boolean
	local enroll = tryEnrollLateJoin
	return if enroll then enroll(player) else false
end

function RoundService.GetRunPlan(): any
	return runPlan
end

function RoundService.GetCurrentAct(): any
	return currentAct
end

function RoundService.GetAuraGenome(): any
	return teamAuraGenome
end

function RoundService.VoteRoute(player: Player, routeId: string): boolean
	if
		state ~= "BriefChoice"
		or type(runPlan) ~= "table"
		or not participantSet[player]
		or type(routeId) ~= "string"
		or #routeId > 80
	then
		return false
	end
	for _, option in runPlan.routeOptions or {} do
		if type(option) == "table" and option.id == routeId then
			routeVotes[player] = routeId
			services.Remote.FireClient("Toast", player, { key = "route_saved" })
			return true
		end
	end
	return false
end

function RoundService.RequestRequeue(player: Player): boolean
	if state ~= "Results" or not participantSet[player] then
		return false
	end
	requeueRequests[player] = true
	services.Remote.FireClient("Toast", player, { key = "requeue_saved" })
	return true
end

function RoundService.GetParticipantUserIds(): { number }
	local userIds = {}
	for _, player in participants do
		if player.Parent == Players then
			table.insert(userIds, player.UserId)
		end
	end
	table.sort(userIds)
	return userIds
end

function RoundService.IsParticipant(player: Player): boolean
	return participantSet[player] == true
end

function RoundService.HandleCharacter(player: Player, character: Model): ()
	task.defer(function()
		local root = character:WaitForChild("HumanoidRootPart", 8)
		if not root then
			return
		end
		if participantSet[player] then
			local phase = if state == "BriefChoice"
					or state == "Intermission"
					or state == "Results"
					or state == "Cleanup"
				then "Hub"
				elseif
					(state == "ThreadRun" or state == "BeatLab" or state == "PrismPuzzle")
					and type(currentAct) == "table"
					and type(currentAct.sceneId) == "string"
				then currentAct.sceneId
				else state
			local index = table.find(participants, player) or 1
			teleportPlayer(player, services.World.GetSpawn(phase, getWorldId(selectedBrief)), index)
			if state == "MixLab" or state == "Finale" or state == "Results" then
				services.Style.ApplyToCharacter(player)
			end
		else
			teleportPlayer(player, services.World.GetSpawn("Hub", nil), 1)
		end
	end)
end

return RoundService
