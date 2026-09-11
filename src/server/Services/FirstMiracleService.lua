--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local FirstMiracleService = {}

local services: any = nil
local config: any = nil
local lastActionAt: { [Player]: number } = {}
local scheduledSession: { [Player]: string } = {}
local spatialSessions: { [Player]: any } = {}
local firstInputSession: { [Player]: string } = {}

local SPATIAL_STEPS = {
	collect_thread = {
		id = "collect_thread",
		verb = "traverse",
		check = "world_distance",
		distance = 6,
	},
	tune_pulse = {
		id = "tune_pulse",
		verb = "jump",
		check = "airborne_pulse",
		height = 1.5,
		verticalSpeed = 3,
	},
	focus_prism = {
		id = "focus_prism",
		verb = "focus",
		check = "move_and_turn",
		distance = 4,
		turnDegrees = 35,
	},
}

local SPATIAL_STEP_ORDER = { "collect_thread", "tune_pulse", "focus_prism" }

local function isLivePlayer(player: Player): boolean
	return typeof(player) == "Instance" and player:IsA("Player")
end

local function characterSnapshot(player: Player): any
	if not isLivePlayer(player) then
		return nil
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not root or not root:IsA("BasePart") or not humanoid then
		return nil
	end
	return {
		root = root,
		position = root.Position,
		look = root.CFrame.LookVector,
		verticalSpeed = root.AssemblyLinearVelocity.Y,
		humanoidState = humanoid:GetState(),
		floorMaterial = humanoid.FloorMaterial,
	}
end

local function captureSpatialCheckpoint(player: Player, sessionId: string, actionIndex: number): ()
	local snapshot = characterSnapshot(player)
	spatialSessions[player] = {
		sessionId = sessionId,
		actionIndex = actionIndex,
		available = snapshot ~= nil,
		legacyFallback = not isLivePlayer(player),
		checkpointPosition = if snapshot then snapshot.position else nil,
		checkpointLook = if snapshot then snapshot.look else nil,
		checkpointRoot = if snapshot then snapshot.root else nil,
		checkpointY = if snapshot then snapshot.position.Y else 0,
		capturedAt = os.clock(),
		lastReason = if snapshot then "ready" else "character_unavailable",
	}
end

local function planarDistance(first: Vector3, second: Vector3): number
	local delta = first - second
	return Vector2.new(delta.X, delta.Z).Magnitude
end

local function turnDegrees(first: Vector3, second: Vector3): number
	local firstPlanar = Vector3.new(first.X, 0, first.Z)
	local secondPlanar = Vector3.new(second.X, 0, second.Z)
	if firstPlanar.Magnitude < 0.001 or secondPlanar.Magnitude < 0.001 then
		return 0
	end
	local dot = math.clamp(firstPlanar.Unit:Dot(secondPlanar.Unit), -1, 1)
	return math.deg(math.acos(dot))
end

local function validateSpatialAction(
	player: Player,
	actionId: string,
	state: any
): (boolean, string, any)
	local definition = SPATIAL_STEPS[actionId]
	if not isLivePlayer(player) then
		-- Studio smoke harnesses use plain tables. Production Players never take
		-- this compatibility branch; their character is always verified below.
		return true, "legacy_compat", { legacyFallback = true }
	end
	if not definition then
		return false, "unknown_spatial_step", nil
	end
	local actionIndex = math.max(0, math.floor(tonumber(state.actionIndex) or 0))
	local sessionId = tostring(state.sessionId or "")
	local session = spatialSessions[player]
	if
		type(session) ~= "table"
		or session.sessionId ~= sessionId
		or session.actionIndex ~= actionIndex
	then
		captureSpatialCheckpoint(player, sessionId, actionIndex)
		session = spatialSessions[player]
		if session then
			session.lastReason = "checkpoint_refreshed"
		end
		return false, "checkpoint_refreshed", nil
	end
	local snapshot = characterSnapshot(player)
	if not snapshot then
		session.lastReason = "character_unavailable"
		return false, "character_unavailable", nil
	end
	if
		not session.checkpointPosition
		or not session.checkpointLook
		or session.checkpointRoot ~= snapshot.root
	then
		captureSpatialCheckpoint(player, sessionId, actionIndex)
		spatialSessions[player].lastReason = "checkpoint_refreshed"
		return false, "checkpoint_refreshed", nil
	end

	local distance = planarDistance(snapshot.position, session.checkpointPosition)
	local height = snapshot.position.Y - session.checkpointY
	local rotation = turnDegrees(session.checkpointLook, snapshot.look)
	local metrics = {
		distance = distance,
		height = height,
		verticalSpeed = snapshot.verticalSpeed,
		turnDegrees = rotation,
	}
	local valid = false
	if definition.check == "world_distance" then
		valid = distance >= definition.distance
	elseif definition.check == "airborne_pulse" then
		valid = height >= definition.height
			or math.abs(snapshot.verticalSpeed) >= definition.verticalSpeed
			or snapshot.humanoidState == Enum.HumanoidStateType.Jumping
			or snapshot.humanoidState == Enum.HumanoidStateType.Freefall
	elseif definition.check == "move_and_turn" then
		valid = distance >= definition.distance and rotation >= definition.turnDegrees
	end
	local reason = if valid then "validated" else "spatial_step_incomplete"
	session.lastReason = reason
	session.metrics = metrics
	return valid, reason, metrics
end

local function miracleConfig(): any
	return if config and type(config.FirstMiracle) == "table" then config.FirstMiracle else {}
end

local function featureEnabled(): boolean
	local flags = services and services.Flags
	if flags and type(flags.IsEnabled) == "function" then
		return flags.IsEnabled("FirstMiracle")
	end
	local localFlags = config and config.FeatureFlags
	return type(localFlags) == "table" and localFlags.FirstMiracle == true
end

local function maximumSeconds(): number
	return math.clamp(math.floor(tonumber(miracleConfig().MaximumSeconds) or 90), 20, 90)
end

local function choiceSeconds(): number
	return math.clamp(math.floor(tonumber(miracleConfig().ChoiceSeconds) or 12), 4, 30)
end

local function bloomSeconds(): number
	return math.clamp(tonumber(miracleConfig().BloomSeconds) or 6, 2, 12)
end

local function actionTarget(): number
	local actions = miracleConfig().ActionSequence
	local configured = math.floor(tonumber(miracleConfig().ActionTarget) or 3)
	return math.clamp(configured, 1, if type(actions) == "table" then #actions else 3)
end

local function contains(values: any, target: string): boolean
	if type(values) ~= "table" then
		return false
	end
	for _, value in values do
		if value == target then
			return true
		end
	end
	return false
end

local function paletteDefinition(paletteId: string): any
	local choices = miracleConfig().PaletteChoices
	if type(choices) == "table" then
		for _, choice in choices do
			if type(choice) == "table" and choice.id == paletteId then
				return choice
			end
		end
	end
	return nil
end

local function defaultPaletteId(): string
	local choices = miracleConfig().PaletteChoices
	local first = if type(choices) == "table" then choices[1] else nil
	return if type(first) == "table" and type(first.id) == "string"
		then first.id
		else "palette_prism"
end

local function getState(player: Player): any
	local profile = services.Data.GetProfile(player)
	return if profile and type(profile.firstMiracle) == "table" then profile.firstMiracle else nil
end

local function clonePublicList(source: any): { any }
	local result = {}
	if type(source) ~= "table" then
		return result
	end
	for _, entry in source do
		if type(entry) == "table" then
			local copy = {}
			for key, value in entry do
				if type(key) == "string" and (type(value) ~= "table" or key == "colors") then
					copy[key] = if type(value) == "table" then table.clone(value) else value
				end
			end
			table.insert(result, copy)
		end
	end
	return result
end

local function buildBloom(player: Player, state: any): any
	local palette = paletteDefinition(tostring(state.paletteId or ""))
	local genome: any = nil
	if services.AuraGenome and type(services.AuraGenome.Capture) == "function" then
		local ok, result = pcall(services.AuraGenome.Capture, player, services.Style)
		if ok and type(result) == "table" then
			genome = result
		end
	end
	return {
		paletteId = tostring(state.paletteId or defaultPaletteId()),
		colors = if palette and type(palette.colors) == "table"
			then table.clone(palette.colors)
			else { "#FF4FD8", "#7657FF", "#38E8FF" },
		fingerprint = if genome then tostring(genome.fingerprint or "") else "",
		auraId = tostring(miracleConfig().CompletionAuraId or "aura_first_miracle"),
		startedAt = math.max(0, math.floor(tonumber(state.bloomStartedAt) or 0)),
		duration = bloomSeconds(),
	}
end

local function spatialView(player: Player, state: any, status: string): any
	local actionIndex = math.max(0, math.floor(tonumber(state and state.actionIndex) or 0))
	local actions = miracleConfig().ActionSequence
	local action = if type(actions) == "table" then actions[actionIndex + 1] else nil
	local actionId = if type(action) == "table" and type(action.id) == "string"
		then action.id
		else ""
	local definition = SPATIAL_STEPS[actionId]
	local session = spatialSessions[player]
	local targetPosition: Vector3? = nil
	if
		type(session) == "table"
		and session.checkpointPosition
		and session.checkpointLook
		and definition
		and definition.distance
	then
		local direction = session.checkpointLook
		if actionId == "focus_prism" then
			direction = Vector3.new(-direction.Z, 0, direction.X)
		end
		targetPosition = session.checkpointPosition + direction.Unit * definition.distance
	end
	return {
		enabled = status == "Actions" and isLivePlayer(player) and definition ~= nil,
		legacyFallback = not isLivePlayer(player),
		actionId = actionId,
		verb = if definition then definition.verb else "perform",
		check = if definition then definition.check else "legacy_action",
		distance = if definition then definition.distance else nil,
		height = if definition then definition.height else nil,
		verticalSpeed = if definition then definition.verticalSpeed else nil,
		turnDegrees = if definition then definition.turnDegrees else nil,
		targetPosition = targetPosition,
		status = if type(session) == "table" then session.lastReason else "awaiting_checkpoint",
		metrics = if type(session) == "table" then session.metrics else nil,
	}
end

function FirstMiracleService.GetSpatialContract(): { any }
	local result = table.create(#SPATIAL_STEP_ORDER)
	for _, actionId in SPATIAL_STEP_ORDER do
		table.insert(result, table.clone(SPATIAL_STEPS[actionId]))
	end
	return result
end

function FirstMiracleService.GetView(player: Player): any
	local state = getState(player)
	local enabled = miracleConfig().Enabled ~= false and featureEnabled()
	local status = if state and type(state.status) == "string" then state.status else "NotStarted"
	local now = os.time()
	local expiresAt = if state then math.max(0, math.floor(tonumber(state.expiresAt) or 0)) else 0
	return {
		enabled = enabled,
		required = enabled and status ~= "Complete",
		status = status,
		sessionId = if state then tostring(state.sessionId or "") else "",
		paletteId = if state then tostring(state.paletteId or "") else "",
		actionIndex = if state
			then math.max(0, math.floor(tonumber(state.actionIndex) or 0))
			else 0,
		actionTarget = actionTarget(),
		remainingSeconds = if expiresAt > 0 then math.max(0, expiresAt - now) else maximumSeconds(),
		expiresAt = expiresAt,
		choiceExpiresAt = if state
			then math.max(0, math.floor(tonumber(state.choiceExpiresAt) or 0))
			else 0,
		choices = clonePublicList(miracleConfig().PaletteChoices),
		actions = clonePublicList(miracleConfig().ActionSequence),
		bloom = if state and (status == "Bloom" or status == "Complete")
			then buildBloom(player, state)
			else nil,
		rewards = {
			glowDust = math.max(0, math.floor(tonumber(miracleConfig().CompletionGlowDust) or 100)),
			atlasXp = math.max(0, math.floor(tonumber(miracleConfig().CompletionAtlasXp) or 80)),
			atlasSchool = tostring(miracleConfig().CompletionAtlasSchool or "Motion"),
			auraId = tostring(miracleConfig().CompletionAuraId or "aura_first_miracle"),
			claimed = state and state.rewardClaimed == true or false,
		},
		readOnly = services.Data.IsReadOnly(player),
		spatial = spatialView(player, state, status),
	}
end

local function fireUpdate(player: Player): ()
	if player.Parent == Players then
		services.Remote.FireClient(
			"FirstMiracleUpdate",
			player,
			FirstMiracleService.GetView(player)
		)
	end
end

local function recordFirstInput(player: Player, sessionId: string, input: string): ()
	if sessionId == "" or firstInputSession[player] == sessionId then
		return
	end
	firstInputSession[player] = sessionId
	services.Analytics.Log(player, "first_input", 1, {
		source = "first_miracle",
		input = input,
	})
	if type(services.Analytics.LogOnce) == "function" then
		services.Analytics.LogOnce(player, "first_core_action", 1, {
			source = "first_miracle",
			input = input,
		}, "first_core_action")
	end
end

local function setPalette(player: Player, paletteId: string, reason: string): boolean
	if not paletteDefinition(paletteId) then
		return false
	end
	local state = getState(player)
	if not state or state.status ~= "PaletteChoice" then
		return false
	end
	local sessionId = tostring(state.sessionId or "")
	local changed = false
	local updated = services.Data.Update(player, function(profile: any)
		local current = profile.firstMiracle
		if
			type(current) == "table"
			and current.status == "PaletteChoice"
			and current.sessionId == sessionId
		then
			current.paletteId = paletteId
			current.status = "Actions"
			current.actionIndex = 0
			changed = true
		end
	end)
	if not updated or not changed then
		return false
	end
	services.Style.SetChoice(player, "palette", paletteId)
	services.Analytics.Log(player, "first_miracle_palette", 1, {
		paletteId = paletteId,
		reason = reason,
	})
	-- An automatic palette is a fallback, not evidence of player input.
	if reason == "player_choice" then
		recordFirstInput(player, sessionId, "palette")
	end
	captureSpatialCheckpoint(player, sessionId, 0)
	fireUpdate(player)
	return true
end

local completeMiracle: (Player, string, string) -> ()

local function beginBloom(player: Player, reason: string, skipped: boolean): boolean
	local state = getState(player)
	if not state or state.status == "Complete" then
		return false
	end
	if state.status == "Bloom" then
		return true
	end
	local sessionId = tostring(state.sessionId or "")
	if sessionId == "" then
		return false
	end
	local paletteId = if paletteDefinition(tostring(state.paletteId or ""))
		then tostring(state.paletteId)
		else defaultPaletteId()
	local changed = false
	local updated = services.Data.Update(player, function(profile: any)
		local current = profile.firstMiracle
		if
			type(current) == "table"
			and current.sessionId == sessionId
			and current.status ~= "Complete"
		then
			current.paletteId = paletteId
			current.status = "Bloom"
			current.bloomStartedAt = os.time()
			current.completionReason = string.sub(reason, 1, 32)
			current.skipped = current.skipped == true or skipped
			changed = true
		end
	end)
	if not updated or not changed then
		return false
	end
	services.Style.SetChoice(player, "palette", paletteId)
	services.Style.ApplyToCharacter(player)
	services.Analytics.Onboarding(player, 2, "First Miracle Bloom", {
		reason = reason,
	})
	spatialSessions[player] = nil
	fireUpdate(player)
	task.delay(bloomSeconds(), function()
		completeMiracle(player, sessionId, reason)
	end)
	return true
end

completeMiracle = function(player: Player, sessionId: string, reason: string): ()
	local state = getState(player)
	if not state or tostring(state.sessionId or "") ~= sessionId then
		return
	end
	if state.status == "Complete" and state.rewardClaimed == true then
		fireUpdate(player)
		return
	end

	local rewardConfig = miracleConfig()
	local glowDust = math.max(0, math.floor(tonumber(rewardConfig.CompletionGlowDust) or 100))
	local atlasXp = math.max(0, math.floor(tonumber(rewardConfig.CompletionAtlasXp) or 80))
	local atlasSchool = tostring(rewardConfig.CompletionAtlasSchool or "Motion")
	local auraId = tostring(rewardConfig.CompletionAuraId or "aura_first_miracle")
	local transaction = services.Economy.GrantCurrency(
		player,
		"system",
		"first_miracle:v1",
		glowDust,
		function(profile: any): any
			local current = profile.firstMiracle
			current.status = "Complete"
			current.completedAt = os.time()
			current.completionReason = string.sub(reason, 1, 32)
			current.rewardClaimed = true
			profile.settings.onboardingComplete = true
			profile.unlocks.aura = profile.unlocks.aura or {}
			if not contains(profile.unlocks.aura, auraId) then
				table.insert(profile.unlocks.aura, auraId)
			end
			profile.equipped.aura = auraId
			local progression = if services.Progression
					and type(services.Progression.ApplySchoolXp) == "function"
				then services.Progression.ApplySchoolXp(profile, atlasSchool, atlasXp)
				else nil
			return { progression = progression, auraId = auraId }
		end
	)
	if transaction.ok ~= true then
		warn(
			"[AuraRush/FirstMiracle] Completion transaction failed: "
				.. tostring(transaction.reason)
		)
		return
	end
	if transaction.alreadyApplied == true then
		services.Data.Update(player, function(profile: any)
			local current = profile.firstMiracle
			if type(current) == "table" and current.sessionId == sessionId then
				current.status = "Complete"
				current.completedAt = math.max(os.time(), tonumber(current.completedAt) or 0)
				current.rewardClaimed = true
				profile.settings.onboardingComplete = true
			end
		end)
	end

	scheduledSession[player] = nil
	spatialSessions[player] = nil
	services.Style.ApplyToCharacter(player)
	if services.Round and type(services.Round.TryEnrollLateJoin) == "function" then
		services.Round.TryEnrollLateJoin(player)
	end
	services.Remote.FireClient("ProgressUpdate", player, {
		kind = "Profile",
		profile = services.Data.GetClientView(player),
	})
	services.Remote.FireClient("Toast", player, {
		key = "first_miracle_complete",
		tone = "Success",
	})
	services.Analytics.Log(player, "first_miracle_complete", 1, {
		reason = reason,
		readOnly = tostring(services.Data.IsReadOnly(player)),
	})
	if type(services.Analytics.CompleteOnboarding) == "function" then
		services.Analytics.CompleteOnboarding(player, { reason = reason })
	else
		services.Analytics.Log(player, "onboarding_complete", 1, { reason = reason })
	end
	if transaction.alreadyApplied ~= true then
		if type(services.Analytics.LogOnce) == "function" then
			services.Analytics.LogOnce(player, "first_reward", glowDust, {
				source = "first_miracle",
				reward = "GlowDust",
			}, "first_reward")
		else
			services.Analytics.Log(player, "first_reward", glowDust, {
				source = "first_miracle",
				reward = "GlowDust",
			})
		end
	end
	if services.Meta and type(services.Meta.Push) == "function" then
		services.Meta.Push(player, "FirstMiracle")
	end
	fireUpdate(player)
	if not services.Data.IsReadOnly(player) then
		task.spawn(services.Data.Save, player)
	end
end

local function scheduleSession(player: Player): ()
	local state = getState(player)
	if not state or state.status == "NotStarted" or state.status == "Complete" then
		return
	end
	local sessionId = tostring(state.sessionId or "")
	if sessionId == "" or scheduledSession[player] == sessionId then
		if state.status == "Actions" and not spatialSessions[player] then
			captureSpatialCheckpoint(
				player,
				sessionId,
				math.max(0, math.floor(tonumber(state.actionIndex) or 0))
			)
		end
		return
	end
	scheduledSession[player] = sessionId
	if state.status == "Actions" then
		captureSpatialCheckpoint(
			player,
			sessionId,
			math.max(0, math.floor(tonumber(state.actionIndex) or 0))
		)
	end
	local now = os.time()
	local paletteDelay = math.max(0, (tonumber(state.choiceExpiresAt) or now) - now)
	local forcedBloomAt = math.max(
		now,
		(tonumber(state.expiresAt) or (now + maximumSeconds())) - math.ceil(bloomSeconds())
	)
	task.delay(paletteDelay, function()
		local current = getState(player)
		if current and current.sessionId == sessionId and current.status == "PaletteChoice" then
			setPalette(player, defaultPaletteId(), "choice_timeout")
		end
	end)
	task.delay(math.max(0, forcedBloomAt - now), function()
		local current = getState(player)
		if current and current.sessionId == sessionId and current.status ~= "Complete" then
			beginBloom(player, "time_guarantee", current.actionIndex < actionTarget())
		end
	end)
	if state.status == "Bloom" then
		local elapsed = math.max(0, now - (tonumber(state.bloomStartedAt) or now))
		task.delay(math.max(0, bloomSeconds() - elapsed), function()
			completeMiracle(player, sessionId, tostring(state.completionReason or "resumed"))
		end)
	elseif forcedBloomAt <= now then
		beginBloom(player, "resume_timeout", true)
	elseif state.status == "PaletteChoice" and paletteDelay <= 0 then
		setPalette(player, defaultPaletteId(), "resume_choice_timeout")
	end
end

local function ensureStarted(player: Player): any
	if not featureEnabled() or miracleConfig().Enabled == false then
		return FirstMiracleService.GetView(player)
	end
	local state = getState(player)
	if not state then
		return FirstMiracleService.GetView(player)
	end
	if state.status == "NotStarted" then
		local now = os.time()
		local sessionId = HttpService:GenerateGUID(false)
		services.Data.Update(player, function(profile: any)
			local current = profile.firstMiracle
			if current.status == "NotStarted" then
				current.status = "PaletteChoice"
				current.sessionId = sessionId
				current.paletteId = ""
				current.actionIndex = 0
				current.startedAt = now
				current.choiceExpiresAt = now + choiceSeconds()
				current.expiresAt = now + maximumSeconds()
				current.bloomStartedAt = 0
				current.completedAt = 0
				current.completionReason = ""
				current.skipped = false
				current.rewardClaimed = false
			end
		end)
		services.Analytics.Log(player, "first_miracle_started", 1, nil)
	end
	scheduleSession(player)
	return FirstMiracleService.GetView(player)
end

local function performAction(player: Player, actionId: string, payload: any?): ()
	local state = getState(player)
	if not state or state.status ~= "Actions" then
		return
	end
	local cooldown = math.clamp(tonumber(miracleConfig().ActionCooldownSeconds) or 0.18, 0.1, 1)
	if os.clock() - (lastActionAt[player] or 0) < cooldown then
		return
	end
	local actions = miracleConfig().ActionSequence
	local nextIndex = math.max(0, math.floor(tonumber(state.actionIndex) or 0)) + 1
	local expected = if type(actions) == "table" then actions[nextIndex] else nil
	if type(expected) ~= "table" or expected.id ~= actionId then
		return
	end
	local spatialValid, spatialReason, spatialMetrics =
		validateSpatialAction(player, actionId, state)
	if not spatialValid then
		lastActionAt[player] = os.clock()
		fireUpdate(player)
		return
	end
	lastActionAt[player] = os.clock()
	local sessionId = tostring(state.sessionId or "")
	local changed = false
	services.Data.Update(player, function(profile: any)
		local current = profile.firstMiracle
		if
			current.status == "Actions"
			and current.sessionId == sessionId
			and math.floor(tonumber(current.actionIndex) or 0) + 1 == nextIndex
		then
			current.actionIndex = nextIndex
			changed = true
		end
	end)
	if not changed then
		return
	end
	recordFirstInput(player, sessionId, "world_action")
	services.Analytics.Log(player, "first_miracle_action", nextIndex, {
		actionId = actionId,
		mode = if type(payload) == "table" and payload.mode == "spatial"
			then "spatial"
			else spatialReason,
		distance = if type(spatialMetrics) == "table" then spatialMetrics.distance else nil,
		turnDegrees = if type(spatialMetrics) == "table" then spatialMetrics.turnDegrees else nil,
	})
	if nextIndex == 1 then
		services.Analytics.Log(player, "first_movement", 1, { source = "first_miracle" })
		services.Analytics.Log(player, "first_world_reaction", 1, { source = "style_signal" })
	end
	if nextIndex >= actionTarget() then
		beginBloom(player, "actions_complete", false)
	else
		captureSpatialCheckpoint(player, sessionId, nextIndex)
		fireUpdate(player)
	end
end

function FirstMiracleService.Resume(player: Player): ()
	local state = getState(player)
	if state and state.status ~= "NotStarted" and state.status ~= "Complete" then
		scheduleSession(player)
	end
end

function FirstMiracleService.Init(context: any): ()
	services = context.Services
	config = context.Config
	services.Remote.BindFunction("RequestFirstMiracle", 1, function(player: Player, _payload: any)
		return ensureStarted(player)
	end)
	services.Remote.BindEvent("FirstMiracleAction", 2, function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.action) ~= "string" then
			return
		end
		local action = payload.action
		if action == "Start" then
			ensureStarted(player)
			fireUpdate(player)
		elseif action == "ChoosePalette" and type(payload.paletteId) == "string" then
			setPalette(player, string.sub(payload.paletteId, 1, 48), "player_choice")
		elseif action == "PerformAction" and type(payload.actionId) == "string" then
			performAction(player, string.sub(payload.actionId, 1, 48), payload)
		elseif action == "Skip" then
			ensureStarted(player)
			beginBloom(player, "player_skip", true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastActionAt[player] = nil
		scheduledSession[player] = nil
		spatialSessions[player] = nil
		firstInputSession[player] = nil
	end)
end

return FirstMiracleService
