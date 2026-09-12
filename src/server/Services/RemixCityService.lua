--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RemixCityService = {}

local config: any = nil
local services: any = nil
local styleCatalog: any = nil
local remixCatalog: any = nil
local styleChemistry: any = nil

local activeRoundId = ""
local activePhase = "Waiting"
local activeStartedAt = 0
local activePlan: any = nil
local activeChemistry: any = nil
local activeParticipants: { Player } = {}
local participantSet: { [Player]: boolean } = {}
local roles: { [Player]: string } = {}
local roleContributions: { [Player]: number } = {}
local moments: { any } = {}
local lastMomentKind = ""
local guardian: any = nil
local pendingReplays: { [Player]: any } = {}
local actionCooldowns: { [Player]: { [string]: number } } = {}
local playerRemovingConnection: RBXScriptConnection? = nil

local VALID_MOMENT_KINDS = table.freeze({
	route = true,
	role = true,
	thread = true,
	beat = true,
	prism = true,
	assist = true,
	guardian = true,
	bloom = true,
})

local function remixConfig(name: string, fallback: number): number
	local section = config and config.RemixCity
	local value = if type(section) == "table" then tonumber(section[name]) else nil
	return if value then value else fallback
end

local function enabled(): boolean
	local flags = services and services.Flags
	if flags and type(flags.IsEnabled) == "function" then
		return flags.IsEnabled("RemixCity")
	end
	return config ~= nil and config.FeatureFlags.RemixCity == true
end

local function roleDefinition(roleId: string): any
	return if remixCatalog then remixCatalog.GetRole(roleId) else nil
end

local function participantSlot(player: Player): number
	return table.find(activeParticipants, player) or 0
end

local function safeId(value: any, maximum: number?): string
	if type(value) ~= "string" then
		return ""
	end
	return string.sub(value, 1, maximum or 64)
end

local function contains(values: { string }, target: string): boolean
	return table.find(values, target) ~= nil
end

local function chemistryName(chemistryId: string): string
	if styleChemistry and type(styleChemistry.GetRecipes) == "function" then
		for _, recipe in styleChemistry.GetRecipes() do
			if recipe.id == chemistryId then
				return tostring(recipe.nameRu or "Новый микс")
			end
		end
	end
	return "Сохранённый микс"
end

local function seasonNode(nodeId: string): any
	if not remixCatalog or type(remixCatalog.SeasonNodes) ~= "table" then
		return nil
	end
	for _, node in remixCatalog.SeasonNodes do
		if node.id == nodeId then
			return node
		end
	end
	return nil
end

local function rewardLabel(reward: any): string
	if type(reward) ~= "table" then
		return "Награда"
	end
	if reward.kind == "glow_dust" then
		return `+{math.max(0, math.floor(tonumber(reward.amount) or 0))} Искр`
	elseif reward.kind == "style_item" and type(reward.itemId) == "string" then
		local item = styleCatalog and styleCatalog.GetById(reward.itemId)
		return if item
			then tostring(item.Name or "Новая деталь")
			else "Новая деталь"
	end
	return "Награда"
end

local function clonePublicMoment(moment: any): any
	return {
		index = moment.index,
		kind = moment.kind,
		at = moment.at,
		actorSlot = moment.actorSlot,
		actId = moment.actId,
		mechanicId = moment.mechanicId,
		quality = moment.quality,
		roleId = moment.roleId,
		value = moment.value,
	}
end

local function publicMoments(): { any }
	local result = table.create(#moments)
	for _, moment in moments do
		table.insert(result, clonePublicMoment(moment))
	end
	return result
end

local function publicRoles(): { any }
	local result = {}
	for index, player in activeParticipants do
		if player.Parent == Players then
			local roleId = roles[player] or "navigator"
			local definition = roleDefinition(roleId)
			table.insert(result, {
				slot = index,
				roleId = roleId,
				nameRu = if definition then definition.nameRu else roleId,
				contribution = roleContributions[player] or 0,
			})
		end
	end
	return result
end

local function publicGuardian(): any
	if type(guardian) ~= "table" then
		return nil
	end
	return {
		id = guardian.id,
		nameRu = guardian.nameRu,
		verbRu = guardian.verbRu,
		worldId = guardian.worldId,
		progress = guardian.progress,
		target = guardian.target,
		complete = guardian.complete,
		requiredRoleId = guardian.requiredRoleId,
		sequenceIndex = guardian.sequenceIndex,
		accentHex = guardian.accentHex,
	}
end

local function push(player: Player, reason: string): ()
	if not services or not services.Remote or player.Parent ~= Players then
		return
	end
	services.Remote.FireClient("RemixUpdate", player, {
		kind = reason,
		data = RemixCityService.GetSnapshot(player),
	})
end

local function pushAll(reason: string): ()
	for _, player in activeParticipants do
		push(player, reason)
	end
end

local function cooldownReady(player: Player, key: string, duration: number): boolean
	local now = os.clock()
	local playerCooldowns = actionCooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		actionCooldowns[player] = playerCooldowns
	end
	local availableAt = playerCooldowns[key] or 0
	if now < availableAt then
		return false
	end
	playerCooldowns[key] = now + duration
	return true
end

local function assignRole(player: Player, index: number): ()
	local preferred = ""
	local profile = services.Data.GetProfile(player)
	if profile and type(profile.remixCity) == "table" then
		preferred = safeId(profile.remixCity.preferredRole, 24)
	end
	local selected = if roleDefinition(preferred)
		then preferred
		else remixCatalog.Roles[((index - 1) % #remixCatalog.Roles) + 1].id
	roles[player] = selected
	roleContributions[player] = roleContributions[player] or 0
end

local function recordMoment(player: Player?, kind: string, data: any?): boolean
	if not enabled() or activeRoundId == "" or not VALID_MOMENT_KINDS[kind] then
		return false
	end
	if player and not participantSet[player] then
		return false
	end
	local maximum = math.max(4, math.floor(remixConfig("MaximumStoryboardMoments", 12)))
	local detail = if type(data) == "table" then data else {}
	local important = detail.important == true or detail.quality == "perfect" or kind == "guardian"
	if #moments >= maximum and not important then
		return false
	end
	if #moments >= maximum then
		table.remove(moments, 1)
	end
	local elapsed = math.max(0, Workspace:GetServerTimeNow() - activeStartedAt)
	local moment = {
		index = #moments + 1,
		kind = kind,
		at = math.floor(elapsed * 100 + 0.5) / 100,
		actorSlot = if player then participantSlot(player) else 0,
		actId = safeId(detail.actId, 48),
		mechanicId = safeId(detail.mechanicId, 48),
		quality = safeId(detail.quality, 16),
		roleId = if player then roles[player] or "" else safeId(detail.roleId, 24),
		value = math.clamp(math.floor(tonumber(detail.value) or 0), 0, 10000),
	}
	table.insert(moments, moment)
	lastMomentKind = kind
	if player then
		roleContributions[player] = (roleContributions[player] or 0) + 1
	end
	pushAll("Storyboard")
	return true
end

local function setReplayConsent(player: Player, consent: boolean): boolean
	if not services.Data.IsLoaded(player) or services.Data.IsReadOnly(player) then
		return false
	end
	local updated = services.Data.Update(player, function(profile: any)
		profile.remixCity.replayConsent = consent
	end)
	if updated then
		push(player, "Consent")
	end
	return updated
end

local function savePendingReplay(player: Player): boolean
	local replay = pendingReplays[player]
	if activePhase ~= "Results" or type(replay) ~= "table" then
		return false
	end
	if services.Data.IsReadOnly(player) then
		return false
	end
	local maximum = math.max(1, math.floor(remixConfig("MaximumSavedReplays", 8)))
	local saved = services.Data.Update(player, function(profile: any)
		profile.remixCity.replayConsent = true
		table.insert(profile.remixCity.savedReplays, replay)
		while #profile.remixCity.savedReplays > maximum do
			table.remove(profile.remixCity.savedReplays, 1)
		end
		profile.remixCity.stats.remixesSaved += 1
	end)
	if saved then
		pendingReplays[player] = nil
		push(player, "ReplaySaved")
	end
	return saved
end

local function claimSeasonNode(player: Player, nodeId: string): boolean
	if services.Data.IsReadOnly(player) then
		return false
	end
	local node = seasonNode(nodeId)
	local profile = services.Data.GetProfile(player)
	local season = if profile and type(profile.remixCity) == "table"
		then profile.remixCity.season
		else nil
	if
		type(node) ~= "table"
		or type(season) ~= "table"
		or math.floor(tonumber(season.xp) or 0) < math.floor(tonumber(node.xpTarget) or 0)
		or (type(season.claimedFree) == "table" and season.claimedFree[node.id] == true)
	then
		return false
	end
	local reward = node.freeReward
	local currencyAmount = if type(reward) == "table" and reward.kind == "glow_dust"
		then math.max(0, math.floor(tonumber(reward.amount) or 0))
		else 0
	local transaction = services.Economy.GrantCurrency(
		player,
		"system",
		"season_free:" .. node.id,
		currencyAmount,
		function(editable: any)
			editable.remixCity.season.claimedFree[node.id] = true
			if type(reward) == "table" and reward.kind == "style_item" then
				local itemId = safeId(reward.itemId, 48)
				local item = styleCatalog.GetById(itemId)
				if item then
					local unlocked = editable.unlocks[item.category]
					if type(unlocked) ~= "table" then
						unlocked = {}
						editable.unlocks[item.category] = unlocked
					end
					if not contains(unlocked, itemId) then
						table.insert(unlocked, itemId)
					else
						local duplicateBonus = 75
						editable.glowDust += duplicateBonus
						editable.economyStats.earned += duplicateBonus
					end
				end
			end
		end
	)
	if transaction.ok ~= true then
		return false
	end
	services.Remote.FireClient("ProgressUpdate", player, {
		kind = "Profile",
		profile = services.Data.GetClientView(player),
	})
	if services.Meta and type(services.Meta.Push) == "function" then
		services.Meta.Push(player, "Season")
	end
	if services.Analytics and type(services.Analytics.Log) == "function" then
		services.Analytics.Log(player, "season_node_claimed", 1, { nodeId = node.id })
	end
	push(player, "SeasonClaimed")
	return true
end

local function playSavedReplay(player: Player, replayId: string): boolean
	if activeRoundId ~= "" and activePhase ~= "Results" then
		return false
	end
	local profile = services.Data.GetProfile(player)
	local saved = if profile and type(profile.remixCity) == "table"
		then profile.remixCity.savedReplays
		else nil
	if type(saved) ~= "table" then
		return false
	end
	for _, replay in saved do
		if type(replay) == "table" and replay.id == replayId then
			local chemistryId = safeId(replay.chemistryId, 48)
			services.Remote.FireClient("RemixUpdate", player, {
				kind = "ReplayPlayback",
				data = {
					version = 6,
					enabled = true,
					roundId = "archive:" .. safeId(replay.id, 80),
					phase = "Replay",
					roleId = "",
					roles = remixCatalog.Roles,
					teamRoles = {},
					chemistry = {
						primary = {
							id = chemistryId,
							nameRu = safeId(replay.chemistryNameRu, 64) ~= ""
									and safeId(replay.chemistryNameRu, 64)
								or chemistryName(chemistryId),
						},
						resonance = 1,
					},
					storyboard = if type(replay.events) == "table" then replay.events else {},
					guardian = nil,
					replayConsent = true,
					hasPendingReplay = false,
				},
			})
			return true
		end
	end
	return false
end

local function deleteSavedReplay(player: Player, replayId: string): boolean
	if services.Data.IsReadOnly(player) then
		return false
	end
	local removed = false
	local updated = services.Data.Update(player, function(profile: any)
		for index = #profile.remixCity.savedReplays, 1, -1 do
			if profile.remixCity.savedReplays[index].id == replayId then
				table.remove(profile.remixCity.savedReplays, index)
				removed = true
				break
			end
		end
	end)
	if updated and removed then
		services.Remote.FireClient("ProgressUpdate", player, {
			kind = "Profile",
			profile = services.Data.GetClientView(player),
		})
		if services.Meta and type(services.Meta.Push) == "function" then
			services.Meta.Push(player, "ReplayDeleted")
		end
	end
	return updated and removed
end

local function selectRole(player: Player, roleId: string): boolean
	local roleChangePhase = activePhase == "BriefChoice"
		or activePhase == "ThreadRun"
		or activePhase == "BeatLab"
		or activePhase == "PrismPuzzle"
		or activePhase == "MixLab"
	if not participantSet[player] or not roleDefinition(roleId) or not roleChangePhase then
		return false
	end
	if roles[player] == roleId then
		return false
	end
	if
		not cooldownReady(
			player,
			"role",
			math.max(0.2, remixConfig("RoleChangeCooldownSeconds", 1))
		)
	then
		return false
	end
	roles[player] = roleId
	recordMoment(player, "role", { roleId = roleId })
	if not services.Data.IsReadOnly(player) then
		services.Data.Update(player, function(profile: any)
			profile.remixCity.preferredRole = roleId
		end)
	end
	pushAll("RoleChanged")
	return true
end

local function guardianDistanceAllowed(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return RunService:IsStudio() and game.GameId == 0
	end
	local anchor = if services.World
			and type(services.World.GetGuardianAnchor) == "function"
		then services.World.GetGuardianAnchor(guardian and guardian.worldId)
		else nil
	if not anchor then
		return true
	end
	return (root.Position - anchor.Position).Magnitude <= 120
end

local function guardianPulse(player: Player): boolean
	if
		activePhase ~= "Finale"
		or not participantSet[player]
		or type(guardian) ~= "table"
		or guardian.complete == true
		or not guardianDistanceAllowed(player)
	then
		return false
	end
	if
		not cooldownReady(
			player,
			"guardian",
			math.max(0.12, remixConfig("GuardianActionCooldownSeconds", 0.32))
		)
	then
		return false
	end
	local roleId = roles[player] or "navigator"
	local solo = #activeParticipants <= 1
	local matched = solo or roleId == guardian.requiredRoleId
	local gain = if matched then 2 else 1
	guardian.progress = math.min(guardian.target, guardian.progress + gain)
	guardian.sequenceIndex = (guardian.sequenceIndex % #remixCatalog.Roles) + 1
	guardian.requiredRoleId = remixCatalog.Roles[guardian.sequenceIndex].id
	guardian.complete = guardian.progress >= guardian.target
	roleContributions[player] = (roleContributions[player] or 0) + gain
	if services.World and type(services.World.PulseGuardian) == "function" then
		services.World.PulseGuardian(guardian.worldId, guardian.progress / guardian.target, matched)
	end
	recordMoment(player, "guardian", {
		mechanicId = "guardian_choreography",
		quality = if matched then "perfect" else "assist",
		value = guardian.progress,
		important = guardian.complete,
	})
	if guardian.complete then
		pushAll("GuardianComplete")
	else
		pushAll("GuardianProgress")
	end
	return true
end

function RemixCityService.Init(context: any): ()
	RemixCityService.Destroy()
	config = context.Config
	services = context.Services
	styleCatalog = context.StyleCatalog
	remixCatalog = context.RemixCatalog
	styleChemistry = context.StyleChemistry

	services.Remote.BindEvent("RemixAction", 12, function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.action) ~= "string" then
			return
		end
		local action = payload.action
		if action == "select_role" and type(payload.roleId) == "string" then
			selectRole(player, safeId(payload.roleId, 24))
		elseif action == "guardian_pulse" then
			guardianPulse(player)
		elseif action == "set_replay_consent" and type(payload.consent) == "boolean" then
			setReplayConsent(player, payload.consent)
		elseif action == "save_remix" then
			savePendingReplay(player)
		elseif action == "claim_season" and type(payload.nodeId) == "string" then
			claimSeasonNode(player, safeId(payload.nodeId, 80))
		elseif action == "play_saved" and type(payload.replayId) == "string" then
			playSavedReplay(player, safeId(payload.replayId, 80))
		elseif action == "delete_saved" and type(payload.replayId) == "string" then
			deleteSavedReplay(player, safeId(payload.replayId, 80))
		elseif action == "encore" then
			local roundService = services.Round
			if roundService and type(roundService.RequestRequeue) == "function" then
				if roundService.RequestRequeue(player) and not services.Data.IsReadOnly(player) then
					services.Data.Update(player, function(profile: any)
						profile.remixCity.stats.encoresRequested += 1
					end)
				end
			end
		end
	end)

	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		participantSet[player] = nil
		roles[player] = nil
		roleContributions[player] = nil
		pendingReplays[player] = nil
		actionCooldowns[player] = nil
	end)
end

function RemixCityService.BeginRound(
	roundId: string,
	players: { Player },
	plan: any,
	teamGenome: any
): ()
	activeRoundId = safeId(roundId, 80)
	activePhase = "BriefChoice"
	activeStartedAt = Workspace:GetServerTimeNow()
	activePlan = plan
	activeChemistry = styleChemistry.ResolveGenome(styleCatalog, teamGenome)
	guardian = nil
	table.clear(activeParticipants)
	table.clear(participantSet)
	table.clear(roles)
	table.clear(roleContributions)
	table.clear(moments)
	table.clear(pendingReplays)
	table.clear(actionCooldowns)
	lastMomentKind = ""
	for index, player in players do
		table.insert(activeParticipants, player)
		participantSet[player] = true
		assignRole(player, index)
	end
	recordMoment(nil, "route", {
		actId = safeId(plan and plan.selectedRouteId, 48),
		mechanicId = "seamless_route",
		important = true,
	})
	pushAll("RoundStarted")
end

function RemixCityService.AddParticipant(player: Player): ()
	if activeRoundId == "" or participantSet[player] then
		return
	end
	table.insert(activeParticipants, player)
	participantSet[player] = true
	assignRole(player, #activeParticipants)
	push(player, "LateJoin")
end

function RemixCityService.SetPhase(phase: string, act: any?): ()
	activePhase = safeId(phase, 24)
	if type(act) == "table" and type(act.id) == "string" then
		activePlan = activePlan or {}
		activePlan.currentAct = act
	end
	pushAll("Phase")
end

function RemixCityService.RecordChallengeAction(
	player: Player,
	channel: string,
	quality: string?,
	actId: string,
	mechanicId: string,
	value: number?
): ()
	if not participantSet[player] then
		return
	end
	local kind = if channel == "Touch"
		then "thread"
		elseif channel == "BeatHit" then "beat"
		else "prism"
	local contribution = roleContributions[player] or 0
	local shouldRecord = quality == "perfect"
		or contribution == 0
		or contribution % 3 == 0
		or lastMomentKind ~= kind
	roleContributions[player] = contribution + 1
	if shouldRecord then
		recordMoment(player, kind, {
			actId = actId,
			mechanicId = mechanicId,
			quality = quality,
			value = value,
		})
	end
end

function RemixCityService.BeginGuardian(worldId: string): any
	local definition = remixCatalog.GetGuardian(worldId)
	local target = math.max(
		8,
		math.floor(remixConfig("GuardianBaseTarget", 24) + math.max(#activeParticipants - 1, 0) * 4)
	)
	guardian = {
		id = definition.id,
		nameRu = definition.nameRu,
		verbRu = definition.verbRu,
		worldId = definition.worldId,
		accentHex = definition.accentHex,
		progress = 0,
		target = target,
		complete = false,
		sequenceIndex = 1,
		requiredRoleId = remixCatalog.Roles[1].id,
	}
	recordMoment(nil, "guardian", {
		actId = definition.id,
		mechanicId = "guardian_choreography",
		important = true,
	})
	pushAll("GuardianStarted")
	return publicGuardian()
end

function RemixCityService.IsGuardianComplete(): boolean
	return type(guardian) == "table" and guardian.complete == true
end

function RemixCityService.CompleteRound(worldId: string, routeId: string): any
	recordMoment(nil, "bloom", {
		actId = safeId(worldId, 48),
		mechanicId = "living_clip",
		value = if guardian then guardian.progress else 0,
		important = true,
	})
	local replayEvents = publicMoments()
	local maximumEvents = math.max(4, math.floor(remixConfig("MaximumReplayEvents", 24)))
	while #replayEvents > maximumEvents do
		table.remove(replayEvents, 1)
	end
	local summary = {
		version = 1,
		roundId = activeRoundId,
		worldId = safeId(worldId, 48),
		routeId = safeId(routeId, 48),
		chemistry = activeChemistry,
		guardian = publicGuardian(),
		moments = replayEvents,
		roles = publicRoles(),
	}
	for _, player in activeParticipants do
		if player.Parent == Players then
			pendingReplays[player] = {
				version = 1,
				id = `{os.time()}_{safeId(worldId, 24)}_{participantSlot(player)}`,
				createdAt = os.time(),
				worldId = summary.worldId,
				routeId = summary.routeId,
				chemistryId = if activeChemistry and activeChemistry.primary
					then activeChemistry.primary.id
					else "",
				chemistryNameRu = if activeChemistry and activeChemistry.primary
					then activeChemistry.primary.nameRu
					else "Сохранённый микс",
				guardianId = if guardian then guardian.id else "",
				events = replayEvents,
			}
			if not services.Data.IsReadOnly(player) then
				services.Data.Update(player, function(profile: any)
					profile.remixCity.stats.momentsCaptured += #replayEvents
					if guardian and guardian.complete then
						profile.remixCity.stats.guardiansCompleted += 1
					end
					profile.remixCity.season.xp += math.max(25, #replayEvents * 5)
					profile.remixCity.stats.cityContribution += math.max(
						0,
						math.floor(remixConfig("CityMemoryContributionPerRound", 12))
					)
				end)
			end
		end
	end
	pushAll("RoundComplete")
	return summary
end

function RemixCityService.GetSnapshot(player: Player): any
	local roleId = roles[player] or ""
	local profile = if services and services.Data then services.Data.GetProfile(player) else nil
	return {
		version = 6,
		enabled = enabled(),
		roundId = activeRoundId,
		phase = activePhase,
		roleId = roleId,
		role = roleDefinition(roleId),
		roles = remixCatalog and remixCatalog.Roles or {},
		teamRoles = publicRoles(),
		chemistry = activeChemistry,
		storyboard = publicMoments(),
		guardian = publicGuardian(),
		replayConsent = profile ~= nil
			and type(profile.remixCity) == "table"
			and profile.remixCity.replayConsent == true,
		hasPendingReplay = pendingReplays[player] ~= nil,
		readOnly = services and services.Data and services.Data.IsReadOnly(player) or false,
		cityPulse = if services
				and services.CityPulse
				and type(services.CityPulse.GetSnapshot) == "function"
			then services.CityPulse.GetSnapshot(player)
			else nil,
	}
end

function RemixCityService.GetSeasonView(player: Player): any
	local profile = services.Data.GetProfile(player)
	local season = if profile and type(profile.remixCity) == "table"
		then profile.remixCity.season
		else nil
	local xp = if type(season) == "table"
		then math.max(0, math.floor(tonumber(season.xp) or 0))
		else 0
	local claimed = if type(season) == "table" and type(season.claimedFree) == "table"
		then season.claimedFree
		else {}
	local nodes = {}
	for _, node in remixCatalog.SeasonNodes do
		table.insert(nodes, {
			id = node.id,
			week = node.week,
			position = node.position,
			xpTarget = node.xpTarget,
			claimed = claimed[node.id] == true,
			canClaim = xp >= node.xpTarget and claimed[node.id] ~= true,
			reward = node.freeReward,
			rewardLabelRu = rewardLabel(node.freeReward),
		})
	end
	return {
		id = "remix_city_s1",
		xp = xp,
		nodes = nodes,
		premiumAvailable = false,
	}
end

function RemixCityService.GetChemistry(): any
	return activeChemistry
end

function RemixCityService.GetRole(player: Player): string
	return roles[player] or ""
end

function RemixCityService.Reset(): ()
	activeRoundId = ""
	activePhase = "Waiting"
	activePlan = nil
	activeChemistry = nil
	guardian = nil
	table.clear(activeParticipants)
	table.clear(participantSet)
	table.clear(roles)
	table.clear(roleContributions)
	table.clear(moments)
	table.clear(pendingReplays)
	table.clear(actionCooldowns)
end

function RemixCityService.Destroy(): ()
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	RemixCityService.Reset()
	config = nil
	services = nil
	styleCatalog = nil
	remixCatalog = nil
	styleChemistry = nil
end

return RemixCityService
