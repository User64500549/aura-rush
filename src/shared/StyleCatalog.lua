--!strict

local Types = require(script.Parent.Types)
local Localization = require(script.Parent.Localization)
type StyleCategory = Types.StyleCategory
type StyleItem = Types.StyleItem
type StyleLoadout = Types.StyleLoadout
type StyleRarity = Types.StyleRarity
type StyleUnlockKind = Types.StyleUnlockKind

local items: { StyleItem } = {}

local function addItem(
	id: string,
	category: StyleCategory,
	rarity: StyleRarity,
	unlockKind: StyleUnlockKind,
	unlockValue: number?,
	tags: { string },
	visualValue: { string } | string
)
	local nameKey = `style.{id}.name`
	local isStarter = unlockKind == "Default"
	local variant = if category == "palette" then id else visualValue :: string
	local item: StyleItem = {
		Id = id,
		Category = category,
		NameKey = nameKey,
		-- Russian is the authored product default. English clients resolve NameKey.
		-- GetPlayerText prevents a technical item ID from leaking if copy is missing.
		Name = Localization.GetPlayerText("ru", nameKey, nil, "ui.unknown"),
		IsStarter = isStarter,
		UnlockCost = if unlockKind == "GlowDust" then (unlockValue or 0) else 0,
		Variant = variant,
		ColorHex = if category == "palette" then (visualValue :: { string })[1] else nil,
		Material = if category == "material" then visualValue :: string else nil,
		id = id,
		category = category,
		displayNameKey = nameKey,
		descriptionKey = `style.description.{category}`,
		rarity = rarity,
		sortOrder = #items + 1,
		tags = table.freeze(tags),
		unlockKind = unlockKind,
		price = if unlockKind == "GlowDust" then unlockValue else nil,
		masteryRequired = if unlockKind == "Mastery" then unlockValue else nil,
		colors = if category == "palette" then visualValue :: { string } else nil,
		materialName = if category == "material" then visualValue :: string else nil,
		auraPreset = if category == "aura" then visualValue :: string else nil,
		posePreset = if category == "pose" then visualValue :: string else nil,
		accentPreset = if category == "accent" then visualValue :: string else nil,
	}

	if item.colors ~= nil then
		table.freeze(item.colors)
	end
	table.insert(items, table.freeze(item))
end

local function palette(
	id: string,
	colors: { string },
	rarity: StyleRarity,
	unlockKind: StyleUnlockKind,
	unlockValue: number?,
	tags: { string }
)
	addItem(id, "palette", rarity, unlockKind, unlockValue, tags, colors)
end

local function material(
	id: string,
	materialName: string,
	rarity: StyleRarity,
	unlockKind: StyleUnlockKind,
	unlockValue: number?,
	tags: { string }
)
	addItem(id, "material", rarity, unlockKind, unlockValue, tags, materialName)
end

local function aura(
	id: string,
	preset: string,
	rarity: StyleRarity,
	unlockKind: StyleUnlockKind,
	unlockValue: number?,
	tags: { string }
)
	addItem(id, "aura", rarity, unlockKind, unlockValue, tags, preset)
end

local function pose(
	id: string,
	preset: string,
	rarity: StyleRarity,
	unlockKind: StyleUnlockKind,
	unlockValue: number?,
	tags: { string }
)
	addItem(id, "pose", rarity, unlockKind, unlockValue, tags, preset)
end

local function accent(
	id: string,
	preset: string,
	rarity: StyleRarity,
	unlockKind: StyleUnlockKind,
	unlockValue: number?,
	tags: { string }
)
	addItem(id, "accent", rarity, unlockKind, unlockValue, tags, preset)
end

-- Palettes (18). The cyan/sunset aliases match the persistent MVP starter schema.
palette(
	"palette_prism",
	{ "#FF4FD8", "#7657FF", "#38E8FF", "#FFF06A" },
	"Common",
	"Default",
	nil,
	{ "bright", "prism" }
)
palette(
	"palette_cyan",
	{ "#00D9FF", "#47F5D2", "#D9FFFF", "#4062FF" },
	"Common",
	"Default",
	nil,
	{ "cool", "bright" }
)
palette(
	"palette_sunset",
	{ "#FF6B6B", "#FFB347", "#FFE66D", "#6C5CE7" },
	"Common",
	"Default",
	nil,
	{ "warm", "festival" }
)
palette(
	"palette_sunset_pop",
	{ "#FF6B6B", "#FFB347", "#FFE66D", "#6C5CE7" },
	"Common",
	"GlowDust",
	100,
	{ "warm", "festival" }
)
palette(
	"palette_ocean_glass",
	{ "#073B4C", "#118AB2", "#06D6A0", "#E8FFFF" },
	"Common",
	"GlowDust",
	100,
	{ "cool", "glass" }
)
palette(
	"palette_mint_lilac",
	{ "#B8F2E6", "#AED9E0", "#CDB4DB", "#FFF1E6" },
	"Common",
	"GlowDust",
	100,
	{ "soft", "pastel" }
)
palette(
	"palette_ember_gold",
	{ "#5F0F40", "#9A031E", "#FB8B24", "#FFD166" },
	"Uncommon",
	"GlowDust",
	180,
	{ "warm", "dramatic" }
)
palette(
	"palette_moonberry",
	{ "#160C28", "#4B3F72", "#A167A5", "#E8C1C5" },
	"Uncommon",
	"GlowDust",
	180,
	{ "night", "soft" }
)
palette(
	"palette_candy_voltage",
	{ "#FF00A8", "#FFEA00", "#00F5D4", "#9B5DE5" },
	"Uncommon",
	"GlowDust",
	220,
	{ "bright", "arcade" }
)
palette(
	"palette_aurora_ice",
	{ "#001219", "#0A9396", "#94D2BD", "#E9D8A6" },
	"Uncommon",
	"GlowDust",
	220,
	{ "cool", "aurora" }
)
palette(
	"palette_solar_flare",
	{ "#370617", "#D00000", "#FF7900", "#FFDD00" },
	"Rare",
	"GlowDust",
	320,
	{ "energy", "warm" }
)
palette(
	"palette_velvet_night",
	{ "#10002B", "#3C096C", "#7B2CBF", "#E0AAFF" },
	"Rare",
	"GlowDust",
	320,
	{ "gothic", "night" }
)
palette(
	"palette_citrus_splash",
	{ "#007F5F", "#55A630", "#AACC00", "#FFFF3F" },
	"Rare",
	"GlowDust",
	350,
	{ "fresh", "bright" }
)
palette(
	"palette_rose_chrome",
	{ "#4A4E69", "#9A8C98", "#F2E9E4", "#FF8FAB" },
	"Rare",
	"Mastery",
	4,
	{ "editorial", "metal" }
)
palette(
	"palette_forest_signal",
	{ "#132A13", "#31572C", "#90A955", "#ECF39E" },
	"Rare",
	"Mastery",
	5,
	{ "nature", "signal" }
)
palette(
	"palette_bubblegum_void",
	{ "#090014", "#5A189A", "#F72585", "#4CC9F0" },
	"Epic",
	"Mastery",
	7,
	{ "void", "candy" }
)
palette(
	"palette_cloud_arcade",
	{ "#CAF0F8", "#90E0EF", "#FFAFCC", "#FFC8DD" },
	"Epic",
	"Mastery",
	8,
	{ "cloud", "arcade" }
)
palette(
	"palette_mono_editorial",
	{ "#111111", "#555555", "#DDDDDD", "#FFFFFF" },
	"Epic",
	"Mastery",
	10,
	{ "mono", "editorial" }
)

-- Materials (12). Values are names of Roblox Enum.Material members.
material("material_smooth", "SmoothPlastic", "Common", "Default", nil, { "clean", "base" })
material("material_glass", "Glass", "Common", "Default", nil, { "prism", "transparent" })
material("material_neon", "Neon", "Common", "GlowDust", 100, { "glow", "energy" })
material("material_fabric", "Fabric", "Uncommon", "GlowDust", 140, { "soft", "textile" })
material("material_marble", "Marble", "Uncommon", "GlowDust", 180, { "polished", "classic" })
material("material_metal", "Metal", "Uncommon", "GlowDust", 180, { "chrome", "future" })
material("material_cloud_foam", "SmoothPlastic", "Rare", "GlowDust", 280, { "cloud", "soft" })
material("material_crystal_ice", "Ice", "Rare", "GlowDust", 300, { "crystal", "cool" })
material("material_starlight", "Neon", "Rare", "GlowDust", 340, { "stars", "glow" })
material("material_sandstone", "Sand", "Rare", "Mastery", 4, { "earth", "texture" })
material("material_ceramic", "CeramicTiles", "Epic", "Mastery", 7, { "clean", "crafted" })
material("material_hologram", "ForceField", "Epic", "Mastery", 10, { "hologram", "future" })

-- Auras (18). First Miracle is a non-purchasable, guaranteed onboarding keepsake.
aura("aura_spark", "SoftSpark", "Common", "Default", nil, { "spark", "soft" })
aura("aura_pulse", "PrismPulse", "Common", "Default", nil, { "pulse", "prism" })
aura(
	"aura_first_miracle",
	"FirstMiracle",
	"Rare",
	"Milestone",
	nil,
	{ "first_miracle", "keepsake", "bloom" }
)
aura("aura_pixel_burst", "PixelBurst", "Common", "GlowDust", 100, { "pixel", "arcade" })
aura("aura_ribbon", "RibbonOrbit", "Common", "GlowDust", 100, { "ribbon", "motion" })
aura("aura_bubble_pop", "BubblePop", "Common", "GlowDust", 120, { "bubble", "playful" })
aura("aura_firefly", "FireflyCloud", "Uncommon", "GlowDust", 160, { "nature", "soft" })
aura("aura_prism_rain", "PrismRain", "Uncommon", "GlowDust", 180, { "prism", "rain" })
aura("aura_heart_signal", "HeartSignal", "Uncommon", "GlowDust", 200, { "heart", "social" })
aura("aura_comet_tail", "CometTail", "Uncommon", "GlowDust", 220, { "space", "speed" })
aura("aura_flower_echo", "FlowerEcho", "Rare", "GlowDust", 300, { "flower", "nature" })
aura("aura_glitch_halo", "GlitchHalo", "Rare", "GlowDust", 320, { "glitch", "future" })
aura("aura_moon_mist", "MoonMist", "Rare", "GlowDust", 320, { "moon", "gothic" })
aura("aura_sunbeam", "Sunbeam", "Rare", "GlowDust", 340, { "sun", "bright" })
aura("aura_jelly_orbit", "JellyOrbit", "Rare", "Mastery", 5, { "jelly", "orbit" })
aura("aura_constellation", "Constellation", "Epic", "Mastery", 7, { "stars", "space" })
aura("aura_aurora_crown", "AuroraCrown", "Epic", "Mastery", 9, { "aurora", "crown" })
aura("aura_world_bloom", "WorldBloom", "Epic", "Mastery", 12, { "bloom", "finale" })

-- Poses (13)
pose("pose_hero", "Hero", "Common", "Default", nil, { "confident", "open" })
pose("pose_wave", "Wave", "Common", "Default", nil, { "friendly", "social" })
pose("pose_peace", "Peace", "Common", "GlowDust", 80, { "friendly", "photo" })
pose("pose_power_step", "PowerStep", "Common", "GlowDust", 100, { "motion", "confident" })
pose("pose_cloud_float", "CloudFloat", "Uncommon", "GlowDust", 120, { "cloud", "soft" })
pose("pose_detective", "Detective", "Uncommon", "GlowDust", 160, { "mystery", "story" })
pose("pose_star_point", "StarPoint", "Uncommon", "GlowDust", 180, { "star", "photo" })
pose("pose_duo_mirror", "DuoMirror", "Rare", "GlowDust", 260, { "duo", "social" })
pose("pose_editorial_turn", "EditorialTurn", "Rare", "GlowDust", 280, { "editorial", "motion" })
pose("pose_zero_g", "ZeroG", "Rare", "GlowDust", 320, { "space", "float" })
pose("pose_prism_vogue", "PrismVogue", "Rare", "Mastery", 5, { "prism", "editorial" })
pose("pose_bloom_finale", "BloomFinale", "Epic", "Mastery", 8, { "bloom", "finale" })
pose("pose_squad_skyline", "SquadSkyline", "Epic", "Mastery", 11, { "squad", "finale" })

-- Accents (9)
accent("accent_orbit", "OrbitRings", "Common", "Default", nil, { "orbit", "space" })
accent("accent_wings", "StarterWings", "Common", "Default", nil, { "wing", "back" })
accent("accent_star_pin", "StarPin", "Common", "GlowDust", 80, { "star", "small" })
accent("accent_prism_wings", "PrismWings", "Common", "GlowDust", 120, { "prism", "back" })
accent("accent_cloud_bow", "CloudBow", "Uncommon", "GlowDust", 160, { "cloud", "soft" })
accent("accent_flower_crown", "FlowerCrown", "Uncommon", "GlowDust", 200, { "flower", "crown" })
accent("accent_glitch_cape", "GlitchCape", "Rare", "GlowDust", 300, { "glitch", "back" })
accent("accent_moon_satellites", "MoonSatellites", "Rare", "Mastery", 6, { "moon", "orbit" })
accent("accent_bloom_crown", "BloomCrown", "Epic", "Mastery", 10, { "bloom", "crown" })

local categories: { StyleCategory } = { "palette", "material", "aura", "pose", "accent" }
local byId: { [string]: StyleItem } = {}
local byCategory: { [StyleCategory]: { StyleItem } } = {
	palette = {},
	material = {},
	aura = {},
	pose = {},
	accent = {},
}
local starterUnlocks: { [StyleCategory]: { string } } = {
	palette = {},
	material = {},
	aura = {},
	pose = {},
	accent = {},
}

local function isValidCategory(value: string): boolean
	return value == "palette"
		or value == "material"
		or value == "aura"
		or value == "pose"
		or value == "accent"
end

for _, item in items do
	assert(byId[item.id] == nil, `Duplicate style item id: {item.id}`)
	byId[item.id] = item
	table.insert(byCategory[item.category], item)
	if item.unlockKind == "Default" then
		table.insert(starterUnlocks[item.category], item.id)
	end
end

for _, category in categories do
	table.freeze(byCategory[category])
	table.freeze(starterUnlocks[category])
end

local defaultLoadout: StyleLoadout = table.freeze({
	palette = "palette_prism",
	material = "material_smooth",
	aura = "aura_spark",
	pose = "pose_hero",
	accent = "accent_orbit",
})

for category, itemId in defaultLoadout do
	local item = byId[itemId]
	assert(item ~= nil and item.category == category, `Invalid default style item: {itemId}`)
	assert(item.unlockKind == "Default", `Default loadout item must be a starter: {itemId}`)
end

assert(#items >= 60, "StyleCatalog must contain at least 60 items")
table.freeze(items)
table.freeze(byId)
table.freeze(byCategory)
table.freeze(starterUnlocks)

local StyleCatalog = {
	Items = items,
	ById = byId,
	ByCategory = byCategory,
	Count = #items,
}

function StyleCatalog.GetById(id: string): StyleItem?
	return byId[id]
end

function StyleCatalog.GetAll(): { StyleItem }
	return items
end

function StyleCatalog.GetByCategory(category: string): { StyleItem }
	local normalized = string.lower(category)
	if not isValidCategory(normalized) then
		return {}
	end
	return byCategory[normalized :: StyleCategory]
end

function StyleCatalog.GetDefaultLoadout(): StyleLoadout
	return {
		palette = defaultLoadout.palette,
		material = defaultLoadout.material,
		aura = defaultLoadout.aura,
		pose = defaultLoadout.pose,
		accent = defaultLoadout.accent,
	}
end

function StyleCatalog.GetStarterUnlocks(): { [StyleCategory]: { string } }
	local result: { [StyleCategory]: { string } } = {
		palette = table.clone(starterUnlocks.palette),
		material = table.clone(starterUnlocks.material),
		aura = table.clone(starterUnlocks.aura),
		pose = table.clone(starterUnlocks.pose),
		accent = table.clone(starterUnlocks.accent),
	}
	return result
end

function StyleCatalog.IsStarter(id: string): boolean
	local item = byId[id]
	return item ~= nil and item.unlockKind == "Default"
end

function StyleCatalog.IsValidCategory(value: string): boolean
	return isValidCategory(value)
end

return table.freeze(StyleCatalog)
