--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local GameplayMechanics = require(script.Parent.GameplayMechanics)

local ChallengeService = {}

export type PlayerProgress = {
	threads: number,
	beatHits: number,
	beatPerfects: number,
	prismSteps: number,
	prismComplete: boolean,
	prismAttempts: number,
	actId: string,
	threadTarget: number,
	beatTarget: number,
	prismTarget: number,
	participationRatio: number,
	backstageApprentice: boolean,
	mechanicId: string,
	mechanicIds: { string },
	mechanicVerbs: { string },
	mechanicScore: number,
	mechanicCombo: number,
	mechanicAssists: number,
	mechanicSteps: number,
	teamContribution: number,
}

local config: any = nil
local remoteService: any = nil
local worldService: any = nil
local remixService: any = nil
local activePhase = "Waiting"
local activeRoundId = ""
local activeActId = "thread_run"
local activeActIndex = 1
local activeActSeed = 1
local activeTargetScale = 1
local activeTeamCompletionRatio = 0.65
local activeModifierId = ""
local activeLaneTransform = ""
local activeMovementStyle = ""
local activeMechanicProfile: GameplayMechanics.MechanicProfile = GameplayMechanics.Resolve({})
local activeParticipants: { [Player]: boolean } = {}
local progress: { [Player]: PlayerProgress } = {}
local threadCollected: { [Player]: { [number]: boolean } } = {}
local threadLastTouchAt: { [Player]: number } = {}
local beatSchedule: any = {
	startTime = 0,
	interval = 1.15,
	count = 12,
	lanes = {} :: { number },
	encodedLanes = {} :: { number },
}
local beatHits: { [Player]: { [number]: boolean } } = {}
local prismSequences: { [Player]: { number } } = {}
local prismEncodedSequences: { [Player]: { number } } = {}
local prismPositions: { [Player]: number } = {}
local prismAttempts: { [Player]: number } = {}
local touchConnections: { RBXScriptConnection } = {}
local humanoidDefaults: { [Humanoid]: any } = {}
local sharedMechanicState: any = {}
local playerRemovingConnection: RBXScriptConnection? = nil

local function resetSharedMechanicState(): ()
	sharedMechanicState = {
		combo = 0,
		stability = 0,
		lastContributor = nil,
		lastActionAt = 0,
		seenTokens = {},
		repairPosition = 0,
		weaveLanes = {},
		weaveCycles = 0,
		signalPhase = 1,
		duetHits = {},
		duetPairs = 0,
		tempoCharge = 0,
	}
end

resetSharedMechanicState()

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function newProgress(joinedActIndex: number?, backstageApprentice: boolean?): PlayerProgress
	local joinIndex = math.clamp(math.floor(joinedActIndex or 1), 1, 5)
	return {
		threads = 0,
		beatHits = 0,
		beatPerfects = 0,
		prismSteps = 0,
		prismComplete = false,
		prismAttempts = 0,
		actId = activeActId,
		threadTarget = 0,
		beatTarget = 0,
		prismTarget = 0,
		participationRatio = math.clamp((6 - joinIndex) / 5, 0.2, 1),
		backstageApprentice = backstageApprentice == true,
		mechanicId = activeMechanicProfile.primaryId,
		mechanicIds = table.clone(activeMechanicProfile.ids),
		mechanicVerbs = table.clone(activeMechanicProfile.verbs),
		mechanicScore = 0,
		mechanicCombo = 0,
		mechanicAssists = 0,
		mechanicSteps = 0,
		teamContribution = 0,
	}
end

local function challengeValue(name: string, fallback: number): number
	local challenge = config and config.Challenge
	local value = if type(challenge) == "table" then tonumber(challenge[name]) else nil
	return if value then value else fallback
end

local function isParticipant(player: Player): boolean
	return activeParticipants[player] == true and progress[player] ~= nil
end

local function participantCount(): number
	local count = 0
	for player in activeParticipants do
		if progress[player] then
			count += 1
		end
	end
	return count
end

local function publicMechanicState(player: Player): any
	local state = progress[player]
	return {
		id = activeMechanicProfile.primaryId,
		ids = table.clone(activeMechanicProfile.ids),
		verbs = table.clone(activeMechanicProfile.verbs),
		score = if state then state.mechanicScore else 0,
		combo = if state then state.mechanicCombo else 0,
		assists = if state then state.mechanicAssists else 0,
		steps = if state then state.mechanicSteps else 0,
		teamContribution = if state then state.teamContribution else 0,
		teamCombo = sharedMechanicState.combo,
		stability = sharedMechanicState.stability,
		weaveCycles = sharedMechanicState.weaveCycles,
		signalPhase = sharedMechanicState.signalPhase,
		duetPairs = sharedMechanicState.duetPairs,
		tempoCharge = sharedMechanicState.tempoCharge,
	}
end

local function recordMechanicAction(
	player: Player,
	token: string,
	quality: string?,
	channel: string,
	lane: number?
): ()
	local state = progress[player]
	if not state then
		return
	end
	local now = os.clock()
	local score = if quality == "perfect" then 2 else 1
	state.mechanicSteps += 1
	state.mechanicScore += score
	state.teamContribution += 1
	if activeMechanicProfile.discoveryChain then
		state.mechanicCombo += 1
		state.mechanicScore += math.min(state.mechanicCombo, 5)
	end

	local teamSize = participantCount()
	local previousContributor = sharedMechanicState.lastContributor
	local alternated = previousContributor ~= nil and previousContributor ~= player
	local soloFallback = teamSize <= 1

	if activeMechanicProfile.relayChain then
		if soloFallback or previousContributor == nil or alternated then
			sharedMechanicState.combo += 1
			if alternated then
				state.mechanicAssists += 1
				state.mechanicScore += 1
			end
		else
			sharedMechanicState.combo = 1
		end
	end

	if activeMechanicProfile.teamCombo and not sharedMechanicState.seenTokens[token] then
		sharedMechanicState.seenTokens[token] = true
		if soloFallback or previousContributor == nil or alternated then
			sharedMechanicState.combo += 1
		else
			sharedMechanicState.combo = math.max(1, sharedMechanicState.combo - 1)
		end
	end

	if activeMechanicProfile.sharedStabilization then
		local gain = if quality == "perfect" then 12 else 8
		if alternated and now - sharedMechanicState.lastActionAt <= 4 then
			gain += 4
			state.mechanicAssists += 1
		end
		sharedMechanicState.stability = math.clamp(sharedMechanicState.stability + gain, 0, 100)
	end

	if activeMechanicProfile.duetLock and channel == "BeatHit" then
		local duetHit = sharedMechanicState.duetHits[token]
		if soloFallback then
			sharedMechanicState.duetPairs += 1
			state.mechanicScore += 2
		elseif duetHit and duetHit.player ~= player and now - duetHit.at <= 1.2 then
			sharedMechanicState.duetPairs += 1
			state.mechanicAssists += 1
			state.mechanicScore += 3
			local partnerState = progress[duetHit.player]
			if partnerState then
				partnerState.mechanicAssists += 1
				partnerState.mechanicScore += 2
			end
			sharedMechanicState.duetHits[token] = nil
		else
			sharedMechanicState.duetHits[token] = { player = player, at = now }
		end
	end

	if activeMechanicProfile.tempoCharge and channel == "BeatHit" then
		local gain = if quality == "perfect" then 12 else 7
		if alternated and now - sharedMechanicState.lastActionAt <= 2 then
			gain += 3
		end
		sharedMechanicState.tempoCharge = math.clamp(sharedMechanicState.tempoCharge + gain, 0, 100)
		state.mechanicScore += math.floor(gain / 4)
	end

	if activeMechanicProfile.roleSpotlight and remixService then
		local roleId = remixService.GetRole(player)
		local roleMatched = (roleId == "navigator" and channel == "Touch")
			or (roleId == "rhythmer" and channel == "BeatHit")
			or (roleId == "colorist" and channel == "SubmitPrism")
			or (roleId == "director" and quality == "perfect")
		if roleMatched then
			state.mechanicScore += 2
			state.teamContribution += 1
		end
	end

	if activeMechanicProfile.inertiaFlow and channel == "Touch" then
		local previousTouch = threadLastTouchAt[player]
		if previousTouch and now - previousTouch <= 4 then
			state.mechanicCombo += 1
			state.mechanicScore += state.mechanicCombo
		else
			state.mechanicCombo = 1
		end
		threadLastTouchAt[player] = now
	elseif activeMechanicProfile.lightWeave and channel == "BeatHit" and lane then
		sharedMechanicState.weaveLanes[lane] = true
		local laneCount = 0
		for _lane in sharedMechanicState.weaveLanes do
			laneCount += 1
		end
		if laneCount >= 4 then
			sharedMechanicState.weaveCycles += 1
			table.clear(sharedMechanicState.weaveLanes)
			state.mechanicScore += 4
		end
	end

	state.mechanicCombo = math.max(state.mechanicCombo, sharedMechanicState.combo)
	sharedMechanicState.lastContributor = player
	sharedMechanicState.lastActionAt = now
	if remixService and type(remixService.RecordChallengeAction) == "function" then
		remixService.RecordChallengeAction(
			player,
			channel,
			quality,
			activeActId,
			activeMechanicProfile.primaryId,
			state.mechanicScore
		)
	end
end

local function scaledTarget(base: number, minimum: number): number
	return math.clamp(math.floor(base * activeTargetScale + 0.5), minimum, base)
end

local function transformLane(lane: number, index: number, previous: number?): number
	if activeLaneTransform == "mirror" then
		return 5 - lane
	elseif activeLaneTransform == "echo" and index % 3 == 0 and previous then
		return previous
	elseif activeLaneTransform == "wave" then
		return ((index + activeActSeed) % 4) + 1
	end
	return lane
end

local function restoreMovement(): ()
	for humanoid, defaults in humanoidDefaults do
		if humanoid.Parent then
			humanoid.UseJumpPower = defaults.useJumpPower
			humanoid.JumpPower = defaults.jumpPower
			humanoid.JumpHeight = defaults.jumpHeight
		end
	end
	table.clear(humanoidDefaults)
end

local function applyMovement(player: Player): ()
	if activeMovementStyle ~= "float" then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoidDefaults[humanoid] then
		return
	end
	humanoidDefaults[humanoid] = {
		useJumpPower = humanoid.UseJumpPower,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
	}
	if humanoid.UseJumpPower then
		humanoid.JumpPower = math.clamp(humanoid.JumpPower * 1.2, 20, 90)
	else
		humanoid.JumpHeight = math.clamp(humanoid.JumpHeight * 1.2, 4, 16)
	end
end

local function fireProgress(player: Player, payload: any): ()
	remoteService.FireClient("ProgressUpdate", player, payload)
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

local function handleThreadTouch(collectible: BasePart, hit: BasePart): ()
	if activePhase ~= "ThreadRun" then
		return
	end
	local player = playerFromHit(hit)
	if not player or not isParticipant(player) then
		return
	end
	local collectibleAct = collectible:GetAttribute("ChallengeAct")
	if type(collectibleAct) == "string" and collectibleAct ~= activeActId then
		return
	end
	local collectibleId = collectible:GetAttribute("CollectibleId")
	if type(collectibleId) ~= "number" then
		return
	end
	local collected = threadCollected[player]
	if not collected or collected[collectibleId] then
		return
	end
	local state = progress[player]
	local target = state.threadTarget > 0 and state.threadTarget
		or math.floor(challengeValue("ThreadCollectibleCount", 8))
	local expectedCollectibleId = state.threads + 1
	if activeMechanicProfile.signalGate then
		local signalLane = collectible:GetAttribute("SignalLane")
		local expectedSignalLane = (state.mechanicSteps % 2) + 1
		if type(signalLane) == "number" and signalLane ~= expectedSignalLane then
			fireProgress(player, {
				kind = "Thread",
				value = state.threads,
				target = target,
				actId = activeActId,
				rejected = "signal_gate",
				expectedSignalLane = expectedSignalLane,
				mechanic = publicMechanicState(player),
			})
			return
		end
		sharedMechanicState.signalPhase = if expectedSignalLane == 1 then 2 else 1
	end
	if activeMechanicProfile.orderedTouch and collectibleId ~= expectedCollectibleId then
		fireProgress(player, {
			kind = "Thread",
			value = state.threads,
			target = target,
			actId = activeActId,
			rejected = "sequence",
			nextCollectibleId = expectedCollectibleId,
			discovery = activeMechanicProfile.discoveryChain,
			mechanic = publicMechanicState(player),
		})
		return
	end
	collected[collectibleId] = true
	state.threads = math.min(target, state.threads + 1)
	recordMechanicAction(player, `thread:{collectibleId}`, nil, "Touch", nil)
	fireProgress(player, {
		kind = "Thread",
		value = state.threads,
		target = target,
		actId = activeActId,
		modifierId = activeModifierId,
		semantic = if activeActId == "material_surf" then "surf_collect" else "collect",
		nextCollectibleId = if activeMechanicProfile.orderedTouch
				and state.threads < target
			then state.threads + 1
			else nil,
		discovery = activeMechanicProfile.discoveryChain,
		mechanic = publicMechanicState(player),
	})
end

local function clearPlayerState(player: Player): ()
	activeParticipants[player] = nil
	progress[player] = nil
	threadCollected[player] = nil
	threadLastTouchAt[player] = nil
	beatHits[player] = nil
	prismSequences[player] = nil
	prismEncodedSequences[player] = nil
	prismPositions[player] = nil
	prismAttempts[player] = nil
end

local function disconnectTouchConnections(): ()
	for _, connection in touchConnections do
		connection:Disconnect()
	end
	table.clear(touchConnections)
end

function ChallengeService.Destroy(): ()
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	disconnectTouchConnections()
	restoreMovement()
	table.clear(activeParticipants)
	table.clear(progress)
	table.clear(threadCollected)
	table.clear(threadLastTouchAt)
	table.clear(beatHits)
	table.clear(prismSequences)
	table.clear(prismEncodedSequences)
	table.clear(prismPositions)
	table.clear(prismAttempts)
	activePhase = "Waiting"
	activeRoundId = ""
	activeActId = "thread_run"
	activeActIndex = 1
	activeActSeed = 1
	activeTargetScale = 1
	activeTeamCompletionRatio = 0.65
	activeModifierId = ""
	activeLaneTransform = ""
	activeMovementStyle = ""
	activeMechanicProfile = GameplayMechanics.Resolve({})
	resetSharedMechanicState()
	config = nil
	remoteService = nil
	worldService = nil
	remixService = nil
end

function ChallengeService.Init(context: any): ()
	ChallengeService.Destroy()
	config = context.Config
	remoteService = context.Services.Remote
	worldService = context.Services.World
	remixService = context.Services.Remix

	remoteService.BindEvent("BeatHit", 15, function(player: Player, payload: any)
		ChallengeService.HandleBeat(player, payload)
	end)
	remoteService.BindEvent("SubmitPrism", 8, function(player: Player, payload: any)
		ChallengeService.SubmitPrism(player, payload)
	end)

	playerRemovingConnection = Players.PlayerRemoving:Connect(clearPlayerState)
end

function ChallengeService.BindWorld(): ()
	disconnectTouchConnections()
	local worldCollectibles = if type(worldService.GetAllCollectibles) == "function"
		then worldService.GetAllCollectibles()
		else worldService.GetCollectibles()
	for _, collectible in worldCollectibles do
		table.insert(
			touchConnections,
			collectible.Touched:Connect(function(hit: BasePart)
				handleThreadTouch(collectible, hit)
			end)
		)
	end
end

local function setupThreadPlayer(player: Player): ()
	threadCollected[player] = {}
	local state = progress[player]
	-- Keep the legacy eight-thread mastery threshold stable; team scaling is
	-- handled by completion ratio while rhythm and memory scale per player.
	local target = math.floor(challengeValue("ThreadCollectibleCount", 8))
	state.threadTarget = target
	state.actId = activeActId
	fireProgress(player, {
		kind = "Thread",
		value = state.threads,
		target = target,
		actId = activeActId,
		modifierId = activeModifierId,
		laneTransform = activeLaneTransform,
		semantic = if activeActId == "material_surf" then "surf_collect" else "collect",
		nextCollectibleId = if activeMechanicProfile.orderedTouch then 1 else nil,
		discovery = activeMechanicProfile.discoveryChain,
		mechanic = publicMechanicState(player),
	})
end

local function setupBeatPlayer(player: Player): ()
	beatHits[player] = beatHits[player] or {}
	local state = progress[player]
	state.beatTarget = beatSchedule.count
	state.actId = activeActId
	fireProgress(player, {
		kind = "BeatSetup",
		startTime = beatSchedule.startTime,
		interval = beatSchedule.interval,
		count = beatSchedule.count,
		lanes = table.clone(beatSchedule.lanes),
		actId = activeActId,
		modifierId = activeModifierId,
		laneTransform = activeLaneTransform,
		semantic = if activeActId == "light_loom" then "weave_rhythm" else "rhythm",
		encodedLanes = if activeMechanicProfile.eclipseDecode
			then table.clone(beatSchedule.encodedLanes)
			else nil,
		inputTransform = if activeMechanicProfile.eclipseDecode then "complement" else nil,
		mechanic = publicMechanicState(player),
	})
end

local function createPrismSequence(seed: number): ({ number }, { number })
	local random = Random.new(seed)
	local sequence: { number } = {}
	local encodedSequence: { number } = {}
	local baseLength = math.floor(challengeValue("PrismSequenceLength", 5))
	local sequenceLength = scaledTarget(baseLength, math.min(4, baseLength))
	local colorCount = math.clamp(math.floor(challengeValue("PrismColorCount", 4)), 2, 4)
	for index = 1, sequenceLength do
		local rawLane = random:NextInteger(1, colorCount)
		local encodedLane = transformLane(rawLane, index, encodedSequence[index - 1])
		table.insert(encodedSequence, encodedLane)
		local expectedLane = encodedLane
		if activeMechanicProfile.paletteShift then
			expectedLane = ((encodedLane + index - 2) % colorCount) + 1
		elseif activeMechanicProfile.eclipseDecode then
			expectedLane = 5 - encodedLane
		end
		table.insert(sequence, expectedLane)
	end
	return sequence, encodedSequence
end

local function setupPrismPlayer(player: Player): ()
	local sequence: { number }
	local encodedSequence: { number }
	if activeMechanicProfile.sharedRepair then
		sequence = table.clone(sharedMechanicState.repairSequence)
		encodedSequence = table.clone(sharedMechanicState.repairEncodedSequence)
	else
		sequence, encodedSequence = createPrismSequence(activeActSeed + (player.UserId % 1000003))
	end
	prismSequences[player] = sequence
	prismEncodedSequences[player] = encodedSequence
	prismPositions[player] = 0
	prismAttempts[player] = 0
	local state = progress[player]
	state.prismTarget = #sequence
	state.actId = activeActId
	fireProgress(player, {
		kind = "PrismSetup",
		sequence = if activeMechanicProfile.paletteShift
			then table.clone(encodedSequence)
			else table.clone(sequence),
		maxAttempts = math.floor(challengeValue("PrismMaximumAttempts", 5)),
		actId = activeActId,
		modifierId = activeModifierId,
		laneTransform = activeLaneTransform,
		semantic = if activeActId == "bloom_rescue" then "restore_sequence" else "memory",
		encodedSequence = if activeMechanicProfile.eclipseDecode
				or activeMechanicProfile.paletteShift
			then table.clone(encodedSequence)
			else nil,
		inputTransform = if activeMechanicProfile.paletteShift
			then "rotate"
			elseif activeMechanicProfile.eclipseDecode then "complement"
			else nil,
		shared = activeMechanicProfile.sharedRepair,
		mechanic = publicMechanicState(player),
	})
end

function ChallengeService.Begin(
	phase: string,
	roundId: string,
	players: { Player },
	seed: number,
	act: any?
): ()
	restoreMovement()
	activePhase = phase
	activeRoundId = roundId
	activeActId = if type(act) == "table" and type(act.id) == "string"
		then act.id
		else string.lower(phase)
	activeActIndex = if type(act) == "table" and type(act.index) == "number"
		then math.clamp(math.floor(act.index), 1, 5)
		else 1
	activeActSeed = if type(act) == "table" and type(act.seed) == "number" then act.seed else seed
	activeTargetScale = if type(act) == "table" and type(act.targetScale) == "number"
		then math.clamp(act.targetScale, 0.5, 1.5)
		else 1
	activeTeamCompletionRatio = if type(act) == "table"
			and type(act.teamCompletionRatio) == "number"
		then math.clamp(act.teamCompletionRatio, 0.4, 1)
		else 0.65
	activeModifierId = if type(act) == "table" and type(act.modifierId) == "string"
		then act.modifierId
		else ""
	activeLaneTransform = if type(act) == "table" and type(act.laneTransform) == "string"
		then act.laneTransform
		else ""
	activeMovementStyle = if type(act) == "table" and type(act.movementStyle) == "string"
		then act.movementStyle
		else ""
	activeMechanicProfile = GameplayMechanics.Resolve(act)
	if activeMechanicProfile.inertiaFlow then
		activeMovementStyle = "float"
	end
	resetSharedMechanicState()
	table.clear(activeParticipants)
	for _, player in players do
		activeParticipants[player] = true
		if not progress[player] or phase == "ThreadRun" then
			progress[player] = newProgress(1, false)
		end
		local state = progress[player]
		state.actId = activeActId
		state.mechanicId = activeMechanicProfile.primaryId
		state.mechanicIds = table.clone(activeMechanicProfile.ids)
		state.mechanicVerbs = table.clone(activeMechanicProfile.verbs)
		applyMovement(player)
	end

	if phase == "ThreadRun" then
		table.clear(threadCollected)
		table.clear(threadLastTouchAt)
		for _, player in players do
			setupThreadPlayer(player)
		end
	elseif phase == "BeatLab" then
		table.clear(beatHits)
		local count = scaledTarget(math.floor(challengeValue("BeatCount", 12)), 8)
		local lanes: { number } = table.create(count)
		local encodedLanes: { number } = table.create(count)
		local laneRandom = Random.new(activeActSeed + 104729)
		for index = 1, count do
			local rawLane = laneRandom:NextInteger(1, 4)
			local encodedLane = transformLane(rawLane, index, encodedLanes[index - 1])
			table.insert(encodedLanes, encodedLane)
			table.insert(
				lanes,
				if activeMechanicProfile.eclipseDecode then 5 - encodedLane else encodedLane
			)
		end
		local rhythmScale = if type(act) == "table" and type(act.rhythmScale) == "number"
			then math.clamp(act.rhythmScale, 0.85, 1.15)
			else 1
		beatSchedule = {
			startTime = Workspace:GetServerTimeNow() + 2.5,
			interval = challengeValue("BeatIntervalSeconds", 0.75) * rhythmScale,
			count = count,
			lanes = lanes,
			encodedLanes = encodedLanes,
		}
		for _, player in players do
			setupBeatPlayer(player)
		end
	elseif phase == "PrismPuzzle" then
		table.clear(prismSequences)
		table.clear(prismEncodedSequences)
		table.clear(prismPositions)
		table.clear(prismAttempts)
		if activeMechanicProfile.sharedRepair then
			local repairSequence, encodedSequence = createPrismSequence(activeActSeed + 32452843)
			sharedMechanicState.repairSequence = repairSequence
			sharedMechanicState.repairEncodedSequence = encodedSequence
		end
		for _, player in players do
			setupPrismPlayer(player)
		end
	end
end

function ChallengeService.AddParticipant(
	player: Player,
	roundId: string,
	joinedActIndex: number?,
	backstageApprentice: boolean?
): boolean
	if roundId ~= activeRoundId or activeParticipants[player] then
		return false
	end
	activeParticipants[player] = true
	if not progress[player] then
		progress[player] = newProgress(joinedActIndex or activeActIndex, backstageApprentice)
	else
		progress[player].backstageApprentice = backstageApprentice == true
	end
	progress[player].actId = activeActId
	progress[player].mechanicId = activeMechanicProfile.primaryId
	progress[player].mechanicIds = table.clone(activeMechanicProfile.ids)
	progress[player].mechanicVerbs = table.clone(activeMechanicProfile.verbs)
	applyMovement(player)
	if activePhase == "ThreadRun" then
		setupThreadPlayer(player)
	elseif activePhase == "BeatLab" then
		setupBeatPlayer(player)
	elseif activePhase == "PrismPuzzle" then
		setupPrismPlayer(player)
	end
	return true
end

function ChallengeService.HandleBeat(player: Player, payload: any): ()
	if activePhase ~= "BeatLab" or not isParticipant(player) or type(payload) ~= "table" then
		return
	end
	local beatIndex = payload.beatIndex
	local sampleTime = payload.sampleTime
	local lane = payload.lane
	if
		not isFiniteNumber(beatIndex)
		or not isFiniteNumber(sampleTime)
		or not isFiniteNumber(lane)
	then
		return
	end
	beatIndex = math.floor(beatIndex)
	lane = math.floor(lane)
	if beatIndex < 1 or beatIndex > beatSchedule.count then
		return
	end
	if lane < 1 or lane > 4 or beatSchedule.lanes[beatIndex] ~= lane then
		return
	end
	local playerHits = beatHits[player]
	if not playerHits or playerHits[beatIndex] then
		return
	end

	local targetTime = beatSchedule.startTime + (beatIndex - 1) * beatSchedule.interval
	local now = Workspace:GetServerTimeNow()
	local clientDelta = math.abs(sampleTime - targetTime)
	local arrivalDelta = math.abs(now - targetTime)
	if clientDelta > 0.42 or arrivalDelta > 0.9 then
		return
	end

	playerHits[beatIndex] = true
	local state = progress[player]
	state.beatHits += 1
	-- The client timestamp is useful only as a sanity check. Scoring uses the
	-- server-observed arrival time so a forged sampleTime cannot guarantee perfect.
	local perfectWindow = math.max(challengeValue("BeatPerfectWindowSeconds", 0.14), 0.18)
	local quality = if arrivalDelta <= perfectWindow then "perfect" else "good"
	if quality == "perfect" then
		state.beatPerfects += 1
	end
	recordMechanicAction(player, `beat:{beatIndex}`, quality, "BeatHit", lane)
	fireProgress(player, {
		kind = "Beat",
		value = state.beatHits,
		target = beatSchedule.count,
		quality = quality,
		actId = activeActId,
		mechanic = publicMechanicState(player),
	})
end

function ChallengeService.SubmitPrism(player: Player, payload: any): ()
	if activePhase ~= "PrismPuzzle" or not isParticipant(player) or type(payload) ~= "table" then
		return
	end
	local index = payload.index
	if not isFiniteNumber(index) then
		return
	end
	index = math.floor(index)
	if index < 1 or index > 4 then
		return
	end
	local sequence = prismSequences[player]
	local state = progress[player]
	if not sequence or state.prismComplete then
		return
	end
	local maximumAttempts = math.floor(challengeValue("PrismMaximumAttempts", 5))
	if (prismAttempts[player] or 0) >= maximumAttempts then
		return
	end

	if activeMechanicProfile.sharedRepair then
		local nextPosition = sharedMechanicState.repairPosition + 1
		if sequence[nextPosition] == index then
			sharedMechanicState.repairPosition = nextPosition
			recordMechanicAction(player, `repair:{nextPosition}`, nil, "SubmitPrism", index)
			for participant in activeParticipants do
				local participantState = progress[participant]
				if participantState then
					prismPositions[participant] = nextPosition
					participantState.prismSteps =
						math.max(participantState.prismSteps, nextPosition)
					participantState.prismComplete = nextPosition >= #sequence
					fireProgress(participant, {
						kind = "Prism",
						value = nextPosition,
						target = #sequence,
						complete = participantState.prismComplete,
						shared = true,
						contributorUserId = player.UserId,
						actId = activeActId,
						mechanic = publicMechanicState(participant),
					})
				end
			end
		else
			prismAttempts[player] = (prismAttempts[player] or 0) + 1
			state.prismAttempts = prismAttempts[player]
			fireProgress(player, {
				kind = "Prism",
				value = sharedMechanicState.repairPosition,
				target = #sequence,
				complete = false,
				reset = false,
				rejected = "repair_order",
				attempts = state.prismAttempts,
				maxAttempts = maximumAttempts,
				shared = true,
				actId = activeActId,
				mechanic = publicMechanicState(player),
			})
		end
		return
	end

	local nextPosition = (prismPositions[player] or 0) + 1
	if sequence[nextPosition] == index then
		prismPositions[player] = nextPosition
		state.prismSteps = math.max(state.prismSteps, nextPosition)
		state.prismComplete = nextPosition >= #sequence
		recordMechanicAction(
			player,
			`prism:{player.UserId}:{nextPosition}`,
			nil,
			"SubmitPrism",
			index
		)
		fireProgress(player, {
			kind = "Prism",
			value = nextPosition,
			target = #sequence,
			complete = state.prismComplete,
			actId = activeActId,
			decoded = activeMechanicProfile.eclipseDecode,
			mechanic = publicMechanicState(player),
		})
	else
		prismPositions[player] = 0
		prismAttempts[player] = (prismAttempts[player] or 0) + 1
		state.prismAttempts = prismAttempts[player]
		fireProgress(player, {
			kind = "Prism",
			value = 0,
			target = #sequence,
			complete = false,
			reset = true,
			attempts = state.prismAttempts,
			maxAttempts = maximumAttempts,
			actId = activeActId,
			decoded = activeMechanicProfile.eclipseDecode,
			mechanic = publicMechanicState(player),
		})
	end
end

function ChallengeService.EndPhase(phase: string): ()
	if activePhase == phase then
		activePhase = "Inactive"
		restoreMovement()
	end
end

function ChallengeService.IsPhaseComplete(phase: string): boolean
	local playerCount = 0
	local completedCount = 0
	local terminalCount = 0
	for player in activeParticipants do
		local state = progress[player]
		if state then
			playerCount += 1
			if phase == "ThreadRun" and state.threads >= math.max(state.threadTarget, 1) then
				completedCount += 1
				terminalCount += 1
			elseif phase == "PrismPuzzle" then
				if state.prismComplete then
					completedCount += 1
				end
				if
					state.prismComplete
					or state.prismAttempts >= challengeValue("PrismMaximumAttempts", 5)
				then
					terminalCount += 1
				end
			end
		end
	end
	local hasPlayers = playerCount > 0
	if phase == "BeatLab" then
		local lastBeatAt = beatSchedule.startTime + (beatSchedule.count - 1) * beatSchedule.interval
		return hasPlayers and Workspace:GetServerTimeNow() >= lastBeatAt + 0.8
	end
	if phase == "ThreadRun" or phase == "PrismPuzzle" then
		local teamTarget = math.max(1, math.ceil(playerCount * activeTeamCompletionRatio))
		return hasPlayers
			and (
				completedCount >= teamTarget
				or (phase == "PrismPuzzle" and terminalCount >= playerCount)
			)
	end
	return hasPlayers
end

function ChallengeService.GetProgress(player: Player): PlayerProgress?
	return progress[player]
end

function ChallengeService.Finish(): { [Player]: PlayerProgress }
	local result: { [Player]: PlayerProgress } = {}
	for player, state in progress do
		if activeParticipants[player] then
			result[player] = {
				threads = state.threads,
				beatHits = state.beatHits,
				beatPerfects = state.beatPerfects,
				prismSteps = state.prismSteps,
				prismComplete = state.prismComplete,
				prismAttempts = state.prismAttempts,
				actId = state.actId,
				threadTarget = state.threadTarget,
				beatTarget = state.beatTarget,
				prismTarget = state.prismTarget,
				participationRatio = state.participationRatio,
				backstageApprentice = state.backstageApprentice,
				mechanicId = state.mechanicId,
				mechanicIds = table.clone(state.mechanicIds),
				mechanicVerbs = table.clone(state.mechanicVerbs),
				mechanicScore = state.mechanicScore,
				mechanicCombo = state.mechanicCombo,
				mechanicAssists = state.mechanicAssists,
				mechanicSteps = state.mechanicSteps,
				teamContribution = state.teamContribution,
			}
		end
	end
	activePhase = "Inactive"
	restoreMovement()
	table.clear(activeParticipants)
	return result
end

function ChallengeService.GetRoundId(): string
	return activeRoundId
end

function ChallengeService.GetActiveActId(): string
	return activeActId
end

function ChallengeService.GetActiveMechanicProfile(): GameplayMechanics.MechanicProfile
	return table.clone(activeMechanicProfile)
end

function ChallengeService.GetMechanicCatalog(): { any }
	return GameplayMechanics.GetCatalog()
end

return ChallengeService
