--!strict

local Types = require(script.Parent.Types)
local Localization = require(script.Parent.Localization)
type Brief = Types.Brief
type BriefAxisEntry = Types.BriefAxisEntry

type AxisRecord = BriefAxisEntry & {
	label: string,
	accentHex: string,
}

local function axis(id: string, kind: string, accentHex: string, tags: { string }): AxisRecord
	local displayNameKey = `brief.{kind}.{id}.name`
	return table.freeze({
		id = id,
		displayNameKey = displayNameKey,
		descriptionKey = `brief.{kind}.{id}.description`,
		tags = table.freeze(tags),
		-- Legacy fields now have a safe Russian default; localized clients use the key.
		label = Localization.GetPlayerText("ru", displayNameKey, nil, "ui.unknown"),
		accentHex = accentHex,
	})
end

-- Every entry is intentionally fictional, non-body-focused and compatible with every
-- entry on the other axes. 6 x 4 x 4 x 2 yields 192 curated-safe combinations.
local worlds: { AxisRecord } = table.freeze({
	axis("prism_metro", "world", "#38E8FF", { "city", "prism", "motion" }),
	axis("cloud_bazaar", "world", "#FFC8DD", { "cloud", "market", "social" }),
	axis("moonlit_greenhouse", "world", "#94D2BD", { "nature", "moon", "bloom" }),
	axis("orbital_boardwalk", "world", "#9B5DE5", { "space", "festival", "future" }),
	axis("velvet_archive", "world", "#E0AAFF", { "archive", "velvet", "mystery" }),
	axis("solar_cathedral", "world", "#FFD166", { "solar", "glass", "radiant" }),
})

local occasions: { AxisRecord } = table.freeze({
	axis("rescue_rehearsal", "occasion", "#FFB347", { "teamwork", "adventure" }),
	axis("midnight_festival", "occasion", "#F72585", { "music", "celebration" }),
	axis("mystery_premiere", "occasion", "#CDB4DB", { "mystery", "cinema" }),
	axis("friendship_parade", "occasion", "#FFE66D", { "friends", "parade" }),
})

local aesthetics: { AxisRecord } = table.freeze({
	axis("retro_future", "aesthetic", "#00F5D4", { "retro", "future" }),
	axis("soft_gothic", "aesthetic", "#A167A5", { "soft", "gothic" }),
	axis("bioluminescent", "aesthetic", "#06D6A0", { "glow", "nature" }),
	axis("toybox_editorial", "aesthetic", "#FF4FD8", { "playful", "editorial" }),
})

local twists: { AxisRecord } = table.freeze({
	axis("zero_gravity", "twist", "#4CC9F0", { "float", "motion" }),
	axis("color_eclipse", "twist", "#FFD166", { "color", "light" }),
})

local function mergeTags(a: { string }, b: { string }, c: { string }, d: { string }): { string }
	local result: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, source in { a, b, c, d } do
		for _, tag in source do
			if not seen[tag] then
				seen[tag] = true
				table.insert(result, tag)
			end
		end
	end
	return table.freeze(result)
end

local function createBrief(
	world: AxisRecord,
	occasion: AxisRecord,
	aesthetic: AxisRecord,
	twist: AxisRecord
): Brief
	local id = `brief:{world.id}:{occasion.id}:{aesthetic.id}:{twist.id}`
	local title = Localization.GetBriefTitle("ru", world.id, occasion.id, aesthetic.id, twist.id)
	local tags = mergeTags(world.tags, occasion.tags, aesthetic.tags, twist.tags)
	return table.freeze({
		Id = id,
		WorldId = world.id,
		OccasionId = occasion.id,
		AestheticId = aesthetic.id,
		TwistId = twist.id,
		TitleKey = "brief.title.generated",
		Title = title,
		AccentHex = aesthetic.accentHex,
		WorldNameKey = world.displayNameKey,
		OccasionNameKey = occasion.displayNameKey,
		AestheticNameKey = aesthetic.displayNameKey,
		TwistNameKey = twist.displayNameKey,
		Tags = tags,
		id = id,
		worldId = world.id,
		occasionId = occasion.id,
		aestheticId = aesthetic.id,
		twistId = twist.id,
		title = title,
		accentHex = aesthetic.accentHex,
		worldName = world.label,
		occasionName = occasion.label,
		aestheticName = aesthetic.label,
		twistName = twist.label,
		worldNameKey = world.displayNameKey,
		occasionNameKey = occasion.displayNameKey,
		aestheticNameKey = aesthetic.displayNameKey,
		twistNameKey = twist.displayNameKey,
		tags = tags,
	})
end

local all: { Brief } = {}
local byId: { [string]: Brief } = {}

for _, world in worlds do
	for _, occasion in occasions do
		for _, aesthetic in aesthetics do
			for _, twist in twists do
				local brief = createBrief(world, occasion, aesthetic, twist)
				assert(byId[brief.Id] == nil, `Duplicate brief id: {brief.Id}`)
				byId[brief.Id] = brief
				table.insert(all, brief)
			end
		end
	end
end

assert(#all >= 192, "BriefCatalog must expose at least 192 safe combinations")
table.freeze(all)
table.freeze(byId)

local function normalizedSeed(seed: number): number
	if seed ~= seed or seed == math.huge or seed == -math.huge then
		return 1
	end
	return math.floor(math.abs(seed)) % 4294967296
end

local function nextState(state: number): number
	return (state * 1664525 + 1013904223) % 4294967296
end

local BriefCatalog = {
	Axes = table.freeze({
		worlds = worlds,
		occasions = occasions,
		aesthetics = aesthetics,
		twists = twists,
	}),
	All = all,
	ById = byId,
	CombinationCount = #all,
}

function BriefCatalog.GetById(id: string): Brief?
	return byId[id]
end

function BriefCatalog.GetChoices(seed: number, count: number?): { Brief }
	local resolvedCount = math.clamp(math.floor(count or 3), 0, #all)
	local choices: { Brief } = table.create(resolvedCount)
	local used: { [number]: boolean } = {}
	local state = normalizedSeed(seed)

	while #choices < resolvedCount do
		state = nextState(state)
		local index = (state % #all) + 1
		if not used[index] then
			used[index] = true
			table.insert(choices, all[index])
		end
	end

	return choices
end

function BriefCatalog.Compose(
	worldId: string,
	occasionId: string,
	aestheticId: string,
	twistId: string
): Brief?
	return byId[`brief:{worldId}:{occasionId}:{aestheticId}:{twistId}`]
end

return table.freeze(BriefCatalog)
