--!strict

-- Adaptive, deterministic round composition. The director deliberately maps new
-- acts onto the three legacy gameplay phases so older clients remain playable.
local GameplayMechanics = require(script.Parent.GameplayMechanics)

local RunDirectorService = {}

local HISTORY_LIMIT = 8
local CANDIDATE_COUNT = 18

local recentSignatures: { string } = {}
local runCatalog: any = nil
local remixCatalog: any = nil

local ACT_SLOTS = {
	{
		legacyPhase = "ThreadRun",
		acts = {
			{
				id = "thread_run",
				sceneId = "ThreadRun",
				title = "Погоня",
				semantic = "collect",
				objective = "Собери нити на маршруте",
				affinity = "precision",
			},
			{
				id = "material_surf",
				sceneId = "MaterialSurf",
				title = "Сёрф по фактурам",
				semantic = "surf_collect",
				objective = "Поймай образцы на волне",
				affinity = "kinetic",
			},
		},
	},
	{
		legacyPhase = "BeatLab",
		acts = {
			{
				id = "beat_lab",
				sceneId = "BeatLab",
				title = "Бит-челлендж",
				semantic = "rhythm",
				objective = "Попади в общий ритм",
				affinity = "kinetic",
			},
			{
				id = "light_loom",
				sceneId = "LightLoom",
				title = "Световой узор",
				semantic = "weave_rhythm",
				objective = "Собери узор из четырёх дорожек",
				affinity = "precision",
			},
		},
	},
	{
		legacyPhase = "PrismPuzzle",
		acts = {
			{
				id = "prism_puzzle",
				sceneId = "PrismPuzzle",
				title = "Цветовой код",
				semantic = "memory",
				objective = "Повтори цветовой сигнал",
				affinity = "precision",
			},
			{
				id = "bloom_rescue",
				sceneId = "BloomRescue",
				title = "Спаси район",
				semantic = "restore_sequence",
				objective = "Верни свет узлам по порядку",
				affinity = "kinetic",
			},
		},
	},
}

local ROUTES = {
	{
		id = "kinetic_cascade",
		title = "Разгон",
		description = "Больше движения и быстрых решений.",
		affinity = "kinetic",
		accent = "motion",
	},
	{
		id = "precision_atelier",
		title = "Точный маршрут",
		description = "Чёткие сигналы и ставка на точность.",
		affinity = "precision",
		accent = "pattern",
	},
	{
		id = "wild_remix",
		title = "Смелый микс",
		description = "Разные типы испытаний в одном забеге.",
		affinity = "mixed",
		accent = "contrast",
	},
}

local MODIFIERS = {
	{
		id = "mirror_current",
		title = "Зеркальный ритм",
		description = "Дорожки отражаются по горизонтали.",
		rhythmScale = 0.96,
		laneTransform = "mirror",
	},
	{
		id = "soft_gravity",
		title = "Лёгкий шаг",
		description = "Прыжки становятся выше, темп — спокойнее.",
		rhythmScale = 1.04,
		movementStyle = "float",
	},
	{
		id = "chromatic_echo",
		title = "Цветовое эхо",
		description = "Каждый третий сигнал повторяет предыдущий.",
		rhythmScale = 1,
		laneTransform = "echo",
	},
	{
		id = "living_runway",
		title = "Живая дорожка",
		description = "Сигнал идёт волной от края к краю.",
		rhythmScale = 1.02,
		laneTransform = "wave",
	},
}

-- Brief axes are not cosmetic labels: every axis contributes a bounded gameplay
-- treatment. These values tune the server-authoritative targets and Beat Lab
-- cadence, while the semantic fields let presentation systems mirror the same
-- direction without having to infer it from prose.
local OCCASION_TREATMENTS = {
	rescue_rehearsal = {
		affinity = "precision",
		mechanicTag = "shared_stabilization",
		objectiveCue = "удержи общий сигнал",
		targetScale = 1.03,
		completionDelta = -0.04,
		rhythmScale = 1.02,
	},
	midnight_festival = {
		affinity = "kinetic",
		mechanicTag = "festival_combo",
		objectiveCue = "не сбей ночную серию",
		targetScale = 1.04,
		completionDelta = 0,
		rhythmScale = 0.94,
	},
	mystery_premiere = {
		affinity = "precision",
		mechanicTag = "hidden_signal",
		objectiveCue = "найди скрытый сигнал",
		targetScale = 1,
		completionDelta = 0.02,
		rhythmScale = 1.03,
	},
	friendship_parade = {
		affinity = "mixed",
		mechanicTag = "friend_chain",
		objectiveCue = "свяжи действия команды",
		targetScale = 0.94,
		completionDelta = -0.06,
		rhythmScale = 1.02,
	},
	open_occasion = {
		affinity = "mixed",
		mechanicTag = "open_collaboration",
		objectiveCue = "собери общую сцену",
		targetScale = 1,
		completionDelta = 0,
		rhythmScale = 1,
	},
}

local AESTHETIC_TREATMENTS = {
	retro_future = {
		affinity = "kinetic",
		visualProfile = "chrome_grid",
		modifierAffinity = "chromatic_echo",
		targetScale = 1,
		rhythmScale = 0.98,
	},
	soft_gothic = {
		affinity = "precision",
		visualProfile = "velvet_silhouette",
		modifierAffinity = "mirror_current",
		targetScale = 0.98,
		rhythmScale = 1.03,
	},
	bioluminescent = {
		affinity = "mixed",
		visualProfile = "living_glow",
		modifierAffinity = "living_runway",
		targetScale = 1.02,
		rhythmScale = 1,
	},
	toybox_editorial = {
		affinity = "kinetic",
		visualProfile = "graphic_toybox",
		modifierAffinity = "soft_gravity",
		targetScale = 0.96,
		rhythmScale = 0.97,
	},
	open_aesthetic = {
		affinity = "mixed",
		visualProfile = "open_canvas",
		modifierAffinity = "living_runway",
		targetScale = 1,
		rhythmScale = 1,
	},
}

local TWIST_TREATMENTS = {
	zero_gravity = {
		affinity = "kinetic",
		mechanicTag = "low_gravity_flow",
		modifierAffinity = "soft_gravity",
		objectiveCue = "используй инерцию",
		targetScale = 0.92,
		completionDelta = -0.02,
		rhythmScale = 1.05,
	},
	color_eclipse = {
		affinity = "precision",
		mechanicTag = "eclipse_palette",
		modifierAffinity = "chromatic_echo",
		objectiveCue = "читай сцену по цвету",
		targetScale = 1.06,
		completionDelta = 0.02,
		rhythmScale = 0.96,
	},
	open_twist = {
		affinity = "mixed",
		mechanicTag = "open_rule",
		modifierAffinity = "living_runway",
		objectiveCue = "меняйте правило вместе",
		targetScale = 1,
		completionDelta = 0,
		rhythmScale = 1,
	},
}

local function catalogList(key: string, fallback: any): any
	if type(runCatalog) == "table" then
		local value = runCatalog[key]
		if type(value) == "table" and #value > 0 then
			return value
		end
	end
	return fallback
end

local function normalizedSeed(seed: number): number
	local value = math.floor(math.abs(seed)) % 2147483646
	return math.max(value, 1)
end

local function stableHash(value: string): number
	local hash = 5381
	for index = 1, #value do
		hash = (hash * 33 + string.byte(value, index)) % 2147483646
	end
	return hash
end

local function briefValue(brief: any, upper: string, lower: string, fallback: string): string
	if type(brief) ~= "table" then
		return fallback
	end
	local value = brief[upper] or brief[lower]
	return if type(value) == "string" and value ~= "" then value else fallback
end

local function briefTreatment(brief: any): any
	local worldId = briefValue(brief, "WorldId", "worldId", "prism_metro")
	local occasionId = briefValue(brief, "OccasionId", "occasionId", "open_occasion")
	local aestheticId = briefValue(brief, "AestheticId", "aestheticId", "open_aesthetic")
	local twistId = briefValue(brief, "TwistId", "twistId", "open_twist")
	local occasion = OCCASION_TREATMENTS[occasionId] or OCCASION_TREATMENTS.open_occasion
	local aesthetic = AESTHETIC_TREATMENTS[aestheticId] or AESTHETIC_TREATMENTS.open_aesthetic
	local twist = TWIST_TREATMENTS[twistId] or TWIST_TREATMENTS.open_twist
	return {
		id = table.concat({ worldId, occasionId, aestheticId, twistId }, ":"),
		worldId = worldId,
		occasionId = occasionId,
		aestheticId = aestheticId,
		twistId = twistId,
		occasionAffinity = occasion.affinity,
		aestheticAffinity = aesthetic.affinity,
		twistAffinity = twist.affinity,
		visualProfile = aesthetic.visualProfile,
		occasionMechanic = occasion.mechanicTag,
		twistMechanic = twist.mechanicTag,
		modifierAffinities = { aesthetic.modifierAffinity, twist.modifierAffinity },
		objectiveCues = { occasion.objectiveCue, twist.objectiveCue },
		targetScale = occasion.targetScale * aesthetic.targetScale * twist.targetScale,
		completionDelta = occasion.completionDelta + twist.completionDelta,
		rhythmScale = occasion.rhythmScale * aesthetic.rhythmScale * twist.rhythmScale,
	}
end

local function cloneDictionary(source: any): any
	local result = {}
	for key, value in source do
		if type(value) == "table" then
			result[key] = cloneDictionary(value)
		else
			result[key] = value
		end
	end
	return result
end

local function applyEncounterCell(act: any, worldId: string, slotIndex: number): ()
	if not remixCatalog or type(remixCatalog.GetCellsForWorld) ~= "function" then
		return
	end
	local cells = remixCatalog.GetCellsForWorld(worldId)
	local cell = if type(cells) == "table" then cells[slotIndex] else nil
	if type(cell) ~= "table" then
		return
	end
	act.cellId = cell.id
	act.cellTitle = cell.titleRu
	act.cellShape = cell.shape
	act.cellVariant = cell.variant
	act.cellMechanicTag = cell.mechanicTag
	act.mechanicTags = { cell.mechanicTag }
	act.objective = `{cell.titleRu}: {act.objective}`
end

local function semanticAffinityScore(route: any, treatment: any): number
	local affinity = if type(route) == "table" then route.affinity else nil
	local score = 0
	if affinity == treatment.occasionAffinity then
		score += 3
	end
	if affinity == treatment.aestheticAffinity then
		score += 2
	end
	if affinity == treatment.twistAffinity then
		score += 1
	end
	return score
end

local function chooseModifier(random: Random, modifiers: any, treatment: any): any
	local preferredIds: { [string]: boolean } = {}
	for _, modifierId in treatment.modifierAffinities do
		preferredIds[modifierId] = true
	end
	local preferred = {}
	for _, modifier in modifiers do
		if preferredIds[modifier.id] then
			table.insert(preferred, modifier)
		end
	end

	-- The preference makes the brief legible, while the open branch preserves
	-- every modifier as a reachable authored composition.
	local source = if #preferred > 0 and random:NextNumber() <= 0.6 then preferred else modifiers
	return cloneDictionary(source[random:NextInteger(1, #source)])
end

local function applyTreatmentToAct(
	act: any,
	treatment: any,
	targetScale: number,
	teamCompletionRatio: number,
	modifier: any
): ()
	act.briefVariantId =
		`{act.id}:{treatment.occasionId}:{treatment.aestheticId}:{treatment.twistId}`
	act.visualProfile = treatment.visualProfile
	local mechanicTags = if type(act.mechanicTags) == "table"
		then table.clone(act.mechanicTags)
		else {}
	table.insert(mechanicTags, treatment.occasionMechanic)
	table.insert(mechanicTags, treatment.twistMechanic)
	table.insert(mechanicTags, "role_spotlight")
	if act.index == 2 then
		table.insert(mechanicTags, "tempo_charge")
	end
	act.mechanicTags = mechanicTags
	act.objective = `{act.objective}: {treatment.objectiveCues[1]}, {treatment.objectiveCues[2]}.`
	act.modifierId = if type(modifier) == "table" then modifier.id else nil
	act.laneTransform = if type(modifier) == "table" then modifier.laneTransform else nil
	act.movementStyle = if type(modifier) == "table" then modifier.movementStyle else nil
	local mechanicProfile = GameplayMechanics.Resolve(act)
	act.mechanicId = mechanicProfile.primaryId
	act.mechanicIds = table.clone(mechanicProfile.ids)
	act.mechanicVerbs = table.clone(mechanicProfile.verbs)
	act.mechanicSignature = mechanicProfile.signature
	act.mechanicProfile = mechanicProfile
	act.targetScale = math.clamp(targetScale * treatment.targetScale, 0.72, 1.35)
	act.teamCompletionRatio =
		math.clamp(teamCompletionRatio + treatment.completionDelta, 0.45, 0.82)
	local modifierRhythmScale = if type(modifier) == "table"
			and type(modifier.rhythmScale) == "number"
		then modifier.rhythmScale
		else 1
	act.rhythmScale = math.clamp(modifierRhythmScale * treatment.rhythmScale, 0.85, 1.15)
end

local function historyPenalty(signature: string): number
	local penalty = 0
	for index, previous in recentSignatures do
		if previous == signature then
			penalty += index * 100
		else
			for actId in string.gmatch(signature, "[^|]+") do
				if string.find(previous, actId, 1, true) then
					penalty += 1
				end
			end
		end
	end
	return penalty
end

local function difficultyForPlayers(participantCount: number): (number, number)
	local count = math.clamp(math.floor(participantCount), 1, 12)
	-- Difficulty rises slightly with a larger team, while the team completion
	-- threshold falls so one absent player can never stall the run.
	local targetScale = 0.86 + ((count - 1) / 11) * 0.14
	local teamCompletionRatio = 0.72 - ((count - 1) / 11) * 0.17
	return targetScale, teamCompletionRatio
end

local function routeDifficulty(route: any): (number, number)
	local affinity = if type(route) == "table" then route.affinity else "mixed"
	if affinity == "kinetic" then
		return 1.03, 0
	elseif affinity == "precision" then
		return 1, 0.02
	end
	return 0.98, -0.02
end

local function buildCandidate(
	seed: number,
	candidateIndex: number,
	participantCount: number,
	brief: any,
	teamGenome: any
): any
	local genomeFingerprint = if type(teamGenome) == "table"
		then tostring(teamGenome.fingerprint or teamGenome.primaryPaletteId or "default")
		else "default"
	local actSlots = catalogList("ActSlots", ACT_SLOTS)
	local routes = catalogList("Routes", ROUTES)
	local modifiers = catalogList("Modifiers", MODIFIERS)
	local briefId = briefValue(brief, "Id", "id", "open_brief")
	local treatment = briefTreatment(brief)
	local worldId = treatment.worldId
	local random = Random.new(
		normalizedSeed(
			seed
				+ candidateIndex * 104729
				+ stableHash(genomeFingerprint)
				+ stableHash(treatment.id)
		)
	)
	local routeOffset = (stableHash(genomeFingerprint .. briefId) + candidateIndex - 1) % #routes
	local firstRoute = routes[routeOffset + 1]
	local secondRoute = routes[((routeOffset + 1) % #routes) + 1]
	local routeOptions = { cloneDictionary(firstRoute), cloneDictionary(secondRoute) }
	for _, route in routeOptions do
		route.briefAffinityScore = semanticAffinityScore(route, treatment)
		route.visualProfile = treatment.visualProfile
	end
	local routeChoice = (stableHash(genomeFingerprint .. tostring(seed)) % 2) + 1
	local selectedRoute = routeOptions[routeChoice]
	local baseTargetScale, baseTeamCompletionRatio = difficultyForPlayers(participantCount)
	local routeTargetScale, routeCompletionDelta = routeDifficulty(selectedRoute)
	local targetScale =
		math.clamp(baseTargetScale * routeTargetScale * treatment.targetScale, 0.72, 1.35)
	local teamCompletionRatio = math.clamp(
		baseTeamCompletionRatio + routeCompletionDelta + treatment.completionDelta,
		0.45,
		0.82
	)
	local modifier = chooseModifier(random, modifiers, treatment)
	modifier.briefResonance = table.clone(treatment.modifierAffinities)

	local acts = {}
	local signatureParts = {
		worldId,
		treatment.occasionId,
		treatment.aestheticId,
		treatment.twistId,
		selectedRoute.id,
	}
	for slotIndex, slot in actSlots do
		local actIndex: number
		if selectedRoute.affinity == "mixed" then
			actIndex = random:NextInteger(1, #slot.acts)
		else
			local preferredIndex = 1
			for index, act in slot.acts do
				if act.affinity == selectedRoute.affinity then
					preferredIndex = index
					break
				end
			end
			actIndex = if random:NextNumber() <= 0.72
				then preferredIndex
				else ((preferredIndex % #slot.acts) + 1)
		end
		local act = cloneDictionary(slot.acts[actIndex])
		act.index = slotIndex
		act.routeId = selectedRoute.id
		act.legacyPhase = slot.legacyPhase
		act.seed = normalizedSeed(
			seed + slotIndex * 65537 + candidateIndex * 313 + stableHash(treatment.id)
		)
		applyEncounterCell(act, worldId, slotIndex)
		applyTreatmentToAct(
			act,
			treatment,
			baseTargetScale * routeTargetScale,
			baseTeamCompletionRatio + routeCompletionDelta,
			modifier
		)
		table.insert(acts, act)
		table.insert(signatureParts, act.id)
		table.insert(signatureParts, tostring(act.cellId or "open_cell"))
		table.insert(signatureParts, act.mechanicSignature)
	end

	table.insert(signatureParts, modifier.id)
	local signature = table.concat(signatureParts, "|")
	return {
		version = 6,
		seamless = true,
		remixVersion = if remixCatalog then remixCatalog.Version else 6,
		seed = normalizedSeed(seed),
		worldId = worldId,
		briefId = briefId,
		occasionId = treatment.occasionId,
		aestheticId = treatment.aestheticId,
		twistId = treatment.twistId,
		briefTreatment = treatment,
		participantCount = math.clamp(math.floor(participantCount), 1, 12),
		routeOptions = routeOptions,
		selectedRouteId = selectedRoute.id,
		selectedRouteTitle = selectedRoute.title,
		selectionReason = "aura_synergy",
		acts = acts,
		modifier = modifier,
		guardian = if remixCatalog then remixCatalog.GetGuardian(worldId) else nil,
		targetScale = targetScale,
		teamCompletionRatio = teamCompletionRatio,
		baseTargetScale = baseTargetScale,
		baseTeamCompletionRatio = baseTeamCompletionRatio,
		signature = signature,
	}
end

function RunDirectorService.Init(context: any): ()
	runCatalog = if type(context) == "table" then context.RunCatalog else nil
	remixCatalog = if type(context) == "table" then context.RemixCatalog else nil
end

function RunDirectorService.Generate(
	seed: number,
	participantCount: number,
	brief: any,
	teamGenome: any
): any
	local bestPlan: any = nil
	local bestScore = math.huge
	for candidateIndex = 1, CANDIDATE_COUNT do
		local candidate = buildCandidate(seed, candidateIndex, participantCount, brief, teamGenome)
		local score = historyPenalty(candidate.signature)
		-- Stable tie-breaking keeps the same seed/history deterministic.
		score += stableHash(candidate.signature .. tostring(seed)) / 2147483646
		if score < bestScore then
			bestScore = score
			bestPlan = candidate
		end
	end

	if not bestPlan then
		error("RunDirector failed to compose a run")
	end
	table.insert(recentSignatures, bestPlan.signature)
	while #recentSignatures > HISTORY_LIMIT do
		table.remove(recentSignatures, 1)
	end
	return cloneDictionary(bestPlan)
end

function RunDirectorService.GetRecentSignatures(): { string }
	return table.clone(recentSignatures)
end

function RunDirectorService.GetCompositionSpace(briefCount: number?): any
	local resolvedBriefCount = math.max(math.floor(briefCount or 1), 1)
	local actLayouts = 1
	for _, slot in catalogList("ActSlots", ACT_SLOTS) do
		actLayouts *= math.max(#slot.acts, 1)
	end
	local routeCount = #catalogList("Routes", ROUTES)
	local modifierCount = #catalogList("Modifiers", MODIFIERS)
	return {
		semanticBriefs = resolvedBriefCount,
		routes = routeCount,
		actLayouts = actLayouts,
		modifiers = modifierCount,
		mechanics = GameplayMechanics.GetCount(),
		encounterCells = if remixCatalog and type(remixCatalog.EncounterCells) == "table"
			then #remixCatalog.EncounterCells
			else 0,
		seasonNodes = if remixCatalog and type(remixCatalog.SeasonNodes) == "table"
			then #remixCatalog.SeasonNodes
			else 0,
		distinctSignatures = resolvedBriefCount * routeCount * actLayouts * modifierCount,
	}
end

function RunDirectorService.GetMechanicCatalog(): { any }
	return GameplayMechanics.GetCatalog()
end

function RunDirectorService.ApplyRoute(plan: any, routeId: string, teamGenome: any?): any
	if type(plan) ~= "table" or type(plan.routeOptions) ~= "table" then
		return plan
	end
	local selectedRoute: any = nil
	for _, option in plan.routeOptions do
		if type(option) == "table" and option.id == routeId then
			selectedRoute = option
			break
		end
	end
	if not selectedRoute then
		return plan
	end

	local result = cloneDictionary(plan)
	result.selectedRouteId = selectedRoute.id
	result.selectedRouteTitle = selectedRoute.title
	result.selectionReason = "team_vote"
	local actSlots = catalogList("ActSlots", ACT_SLOTS)
	local treatment = if type(result.briefTreatment) == "table"
		then result.briefTreatment
		else briefTreatment({
			WorldId = result.worldId,
			OccasionId = result.occasionId,
			AestheticId = result.aestheticId,
			TwistId = result.twistId,
		})
	local genomeFingerprint = if type(teamGenome) == "table"
		then tostring(teamGenome.fingerprint or "default")
		else "default"
	local random = Random.new(
		normalizedSeed(
			result.seed + stableHash(routeId .. genomeFingerprint) + stableHash(treatment.id)
		)
	)
	local baseTargetScale = tonumber(result.baseTargetScale) or tonumber(result.targetScale) or 1
	local baseTeamCompletionRatio = tonumber(result.baseTeamCompletionRatio)
		or tonumber(result.teamCompletionRatio)
		or 0.65
	local routeTargetScale, routeCompletionDelta = routeDifficulty(selectedRoute)
	result.targetScale =
		math.clamp(baseTargetScale * routeTargetScale * treatment.targetScale, 0.72, 1.35)
	result.teamCompletionRatio = math.clamp(
		baseTeamCompletionRatio + routeCompletionDelta + treatment.completionDelta,
		0.45,
		0.82
	)
	local acts = {}
	local signatureParts = {
		tostring(result.worldId),
		tostring(treatment.occasionId),
		tostring(treatment.aestheticId),
		tostring(treatment.twistId),
		routeId,
	}
	for slotIndex, slot in actSlots do
		local preferredIndex = 1
		for index, act in slot.acts do
			if act.affinity == selectedRoute.affinity then
				preferredIndex = index
				break
			end
		end
		local actIndex = if result.newChallenges == false
			then 1
			elseif selectedRoute.affinity == "mixed" then random:NextInteger(1, #slot.acts)
			else if random:NextNumber() <= 0.78
				then preferredIndex
				else ((preferredIndex % #slot.acts) + 1)
		local act = cloneDictionary(slot.acts[actIndex])
		act.index = slotIndex
		act.routeId = selectedRoute.id
		act.legacyPhase = slot.legacyPhase
		act.seed = normalizedSeed(
			result.seed + slotIndex * 65537 + stableHash(routeId) + stableHash(treatment.id)
		)
		applyEncounterCell(act, tostring(result.worldId), slotIndex)
		applyTreatmentToAct(
			act,
			treatment,
			baseTargetScale * routeTargetScale,
			baseTeamCompletionRatio + routeCompletionDelta,
			result.modifier
		)
		table.insert(acts, act)
		table.insert(signatureParts, act.id)
		table.insert(signatureParts, tostring(act.cellId or "open_cell"))
		table.insert(signatureParts, act.mechanicSignature)
	end
	result.acts = acts
	table.insert(signatureParts, tostring(result.modifier and result.modifier.id or "open"))
	result.signature = table.concat(signatureParts, "|")
	if recentSignatures[#recentSignatures] == plan.signature then
		recentSignatures[#recentSignatures] = result.signature
	else
		table.insert(recentSignatures, result.signature)
		while #recentSignatures > HISTORY_LIMIT do
			table.remove(recentSignatures, 1)
		end
	end
	return result
end

function RunDirectorService.ResetHistory(): ()
	table.clear(recentSignatures)
end

return RunDirectorService
