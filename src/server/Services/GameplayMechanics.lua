--!strict

-- Pure registry for the authoritative gameplay verbs used by ChallengeService.
-- A mechanic is not counted as a new verb merely because it has a different title:
-- every entry below maps to a distinct server rule in the challenge runtime.
local GameplayMechanics = {}

export type MechanicDefinition = {
	id: string,
	verb: string,
	channel: string,
	family: string,
	cooperative: boolean,
	implemented: boolean,
}

export type MechanicProfile = {
	primaryId: string,
	ids: { string },
	verbs: { string },
	signature: string,
	orderedTouch: boolean,
	discoveryChain: boolean,
	relayChain: boolean,
	inertiaFlow: boolean,
	teamCombo: boolean,
	lightWeave: boolean,
	sharedStabilization: boolean,
	sharedRepair: boolean,
	eclipseDecode: boolean,
	signalGate: boolean,
	duetLock: boolean,
	tempoCharge: boolean,
	paletteShift: boolean,
	roleSpotlight: boolean,
	guardianChoreography: boolean,
}

local definitions: { MechanicDefinition } = {
	{
		id = "collect_sprint",
		verb = "collect",
		channel = "Touch",
		family = "collection",
		cooperative = false,
		implemented = true,
	},
	{
		id = "ordered_surf",
		verb = "traverse",
		channel = "Touch",
		family = "route_order",
		cooperative = false,
		implemented = true,
	},
	{
		id = "hidden_signal_scan",
		verb = "discover",
		channel = "Touch",
		family = "discovery",
		cooperative = false,
		implemented = true,
	},
	{
		id = "friend_relay",
		verb = "relay",
		channel = "Any",
		family = "team_relay",
		cooperative = true,
		implemented = true,
	},
	{
		id = "inertia_flow",
		verb = "flow",
		channel = "Touch",
		family = "momentum",
		cooperative = false,
		implemented = true,
	},
	{
		id = "precision_rhythm",
		verb = "strike",
		channel = "BeatHit",
		family = "rhythm",
		cooperative = false,
		implemented = true,
	},
	{
		id = "light_weave",
		verb = "weave",
		channel = "BeatHit",
		family = "lane_weave",
		cooperative = true,
		implemented = true,
	},
	{
		id = "festival_combo",
		verb = "chain",
		channel = "BeatHit",
		family = "team_combo",
		cooperative = true,
		implemented = true,
	},
	{
		id = "shared_stabilization",
		verb = "stabilize",
		channel = "Any",
		family = "shared_meter",
		cooperative = true,
		implemented = true,
	},
	{
		id = "memory_code",
		verb = "recall",
		channel = "SubmitPrism",
		family = "memory",
		cooperative = false,
		implemented = true,
	},
	{
		id = "bloom_repair",
		verb = "repair",
		channel = "SubmitPrism",
		family = "shared_sequence",
		cooperative = true,
		implemented = true,
	},
	{
		id = "eclipse_decode",
		verb = "decode",
		channel = "SubmitPrism",
		family = "encoded_sequence",
		cooperative = false,
		implemented = true,
	},
	{
		id = "signal_gate",
		verb = "align",
		channel = "Touch",
		family = "alternating_signal",
		cooperative = false,
		implemented = true,
	},
	{
		id = "duet_lock",
		verb = "pair",
		channel = "BeatHit",
		family = "timed_duet",
		cooperative = true,
		implemented = true,
	},
	{
		id = "tempo_charge",
		verb = "charge",
		channel = "BeatHit",
		family = "tempo_meter",
		cooperative = true,
		implemented = true,
	},
	{
		id = "palette_shift",
		verb = "rotate",
		channel = "SubmitPrism",
		family = "rotating_palette",
		cooperative = false,
		implemented = true,
	},
	{
		id = "role_spotlight",
		verb = "direct",
		channel = "Any",
		family = "role_contribution",
		cooperative = true,
		implemented = true,
	},
	{
		id = "guardian_choreography",
		verb = "conduct",
		channel = "Any",
		family = "finale_guardian",
		cooperative = true,
		implemented = true,
	},
}

local byId: { [string]: MechanicDefinition } = {}
for _, definition in definitions do
	assert(byId[definition.id] == nil, `Duplicate gameplay mechanic: {definition.id}`)
	byId[definition.id] = definition
end

local baseBySemantic = table.freeze({
	collect = "collect_sprint",
	surf_collect = "ordered_surf",
	rhythm = "precision_rhythm",
	weave_rhythm = "light_weave",
	memory = "memory_code",
	restore_sequence = "bloom_repair",
})

local mechanicByTag = table.freeze({
	shared_stabilization = "shared_stabilization",
	festival_combo = "festival_combo",
	hidden_signal = "hidden_signal_scan",
	friend_chain = "friend_relay",
	open_collaboration = "friend_relay",
	low_gravity_flow = "inertia_flow",
	eclipse_palette = "eclipse_decode",
	open_rule = "shared_stabilization",
	signal_gate = "signal_gate",
	duet_lock = "duet_lock",
	tempo_charge = "tempo_charge",
	palette_shift = "palette_shift",
	role_spotlight = "role_spotlight",
	guardian_choreography = "guardian_choreography",
})

local function addUnique(result: { string }, seen: { [string]: boolean }, mechanicId: string?): ()
	if mechanicId and byId[mechanicId] and not seen[mechanicId] then
		seen[mechanicId] = true
		table.insert(result, mechanicId)
	end
end

local function contains(ids: { string }, mechanicId: string): boolean
	return table.find(ids, mechanicId) ~= nil
end

function GameplayMechanics.Resolve(act: any): MechanicProfile
	local semantic = if type(act) == "table" and type(act.semantic) == "string"
		then act.semantic
		else "collect"
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}
	addUnique(ids, seen, baseBySemantic[semantic] or "collect_sprint")

	local tags = if type(act) == "table" then act.mechanicTags else nil
	if type(tags) == "table" then
		for _, tag in tags do
			if type(tag) == "string" then
				addUnique(ids, seen, mechanicByTag[tag])
			end
		end
	end

	-- Physical modifiers participate in the mechanic contract even when an older
	-- RunDirector did not emit the matching semantic twist tag.
	if type(act) == "table" and act.movementStyle == "float" then
		addUnique(ids, seen, "inertia_flow")
	end

	local verbs = table.create(#ids)
	for _, mechanicId in ids do
		table.insert(verbs, byId[mechanicId].verb)
	end

	return {
		primaryId = ids[1],
		ids = ids,
		verbs = verbs,
		signature = table.concat(ids, "+"),
		orderedTouch = contains(ids, "ordered_surf")
			or contains(ids, "hidden_signal_scan")
			or contains(ids, "inertia_flow"),
		discoveryChain = contains(ids, "hidden_signal_scan"),
		relayChain = contains(ids, "friend_relay"),
		inertiaFlow = contains(ids, "inertia_flow"),
		teamCombo = contains(ids, "festival_combo"),
		lightWeave = contains(ids, "light_weave"),
		sharedStabilization = contains(ids, "shared_stabilization"),
		sharedRepair = contains(ids, "bloom_repair"),
		eclipseDecode = contains(ids, "eclipse_decode"),
		signalGate = contains(ids, "signal_gate"),
		duetLock = contains(ids, "duet_lock"),
		tempoCharge = contains(ids, "tempo_charge"),
		paletteShift = contains(ids, "palette_shift"),
		roleSpotlight = contains(ids, "role_spotlight"),
		guardianChoreography = contains(ids, "guardian_choreography"),
	}
end

function GameplayMechanics.GetById(mechanicId: string): MechanicDefinition?
	return byId[mechanicId]
end

function GameplayMechanics.GetCatalog(): { MechanicDefinition }
	local result = table.create(#definitions)
	for _, definition in definitions do
		table.insert(result, table.clone(definition))
	end
	return result
end

function GameplayMechanics.GetCount(): number
	return #definitions
end

return GameplayMechanics
