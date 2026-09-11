--!strict

-- Deterministic style resonance. It changes presentation and authored route
-- opportunities, never score, rewards, timing windows, or paid power.
local StyleChemistry = {}

local recipes = {
	{
		id = "prism_current",
		nameRu = "Призматический ток",
		tags = { "prism", "pulse", "orbit" },
		motif = "rays",
	},
	{
		id = "clean_signal",
		nameRu = "Чистый сигнал",
		tags = { "clean", "open", "spark" },
		motif = "signal",
	},
	{
		id = "soft_orbit",
		nameRu = "Мягкая орбита",
		tags = { "soft", "orbit", "friendly" },
		motif = "rings",
	},
	{
		id = "festival_heat",
		nameRu = "Тепло фестиваля",
		tags = { "warm", "festival", "motion" },
		motif = "wave",
	},
	{
		id = "chrome_turn",
		nameRu = "Хромовый разворот",
		tags = { "chrome", "editorial", "future" },
		motif = "mirror",
	},
	{
		id = "cloud_duet",
		nameRu = "Облачный дуэт",
		tags = { "cloud", "duo", "soft" },
		motif = "arches",
	},
	{
		id = "moon_archive",
		nameRu = "Лунный архив",
		tags = { "moon", "gothic", "story" },
		motif = "pages",
	},
	{
		id = "living_bloom",
		nameRu = "Живая перекраска",
		tags = { "nature", "flower", "bloom" },
		motif = "petals",
	},
	{
		id = "arcade_glitch",
		nameRu = "Аркадный сбой",
		tags = { "arcade", "glitch", "pixel" },
		motif = "pixels",
	},
	{
		id = "solar_step",
		nameRu = "Солнечный шаг",
		tags = { "sun", "bright", "confident" },
		motif = "fan",
	},
	{
		id = "aurora_float",
		nameRu = "Парение авроры",
		tags = { "aurora", "float", "cool" },
		motif = "curtain",
	},
	{
		id = "velvet_frame",
		nameRu = "Бархатный кадр",
		tags = { "night", "editorial", "crown" },
		motif = "frame",
	},
	{
		id = "star_route",
		nameRu = "Звёздный маршрут",
		tags = { "stars", "space", "speed" },
		motif = "constellation",
	},
	{
		id = "glass_rain",
		nameRu = "Стеклянный дождь",
		tags = { "glass", "rain", "transparent" },
		motif = "rain",
	},
	{
		id = "crafted_light",
		nameRu = "Собранный свет",
		tags = { "crafted", "glow", "photo" },
		motif = "tiles",
	},
	{
		id = "candy_void",
		nameRu = "Контрастный микс",
		tags = { "candy", "void", "playful" },
		motif = "contrast",
	},
	{
		id = "forest_signal",
		nameRu = "Лесной сигнал",
		tags = { "forest", "signal", "nature" },
		motif = "branches",
	},
	{
		id = "hologram_vogue",
		nameRu = "Голографический кадр",
		tags = { "hologram", "editorial", "prism" },
		motif = "scan",
	},
	{
		id = "squad_skyline",
		nameRu = "Общий силуэт",
		tags = { "squad", "finale", "back" },
		motif = "skyline",
	},
	{
		id = "first_echo",
		nameRu = "Первое эхо",
		tags = { "first_miracle", "keepsake", "bloom" },
		motif = "echo",
	},
}

local function addTags(styleCatalog: any, itemId: any, tags: { [string]: boolean }): ()
	if type(itemId) ~= "string" then
		return
	end
	local item = styleCatalog.GetById(itemId)
	if type(item) ~= "table" or type(item.tags) ~= "table" then
		return
	end
	for _, tag in item.tags do
		if type(tag) == "string" then
			tags[tag] = true
		end
	end
end

local function stableHash(value: string): number
	local hash = 5381
	for index = 1, #value do
		hash = (hash * 33 + string.byte(value, index)) % 2147483646
	end
	return hash
end

function StyleChemistry.Resolve(styleCatalog: any, loadout: any): any
	local tags: { [string]: boolean } = {}
	local axes = { "palette", "material", "aura", "pose", "accent" }
	local axisSignals = {}
	for _, axis in axes do
		local itemId = if type(loadout) == "table" then loadout[axis] else nil
		addTags(styleCatalog, itemId, tags)
		axisSignals[axis] = tostring(itemId or "")
	end

	local axisFingerprint = table.concat({
		axisSignals.palette,
		axisSignals.material,
		axisSignals.aura,
		axisSignals.pose,
		axisSignals.accent,
	}, ":")
	local tieRanks: { [string]: number } = {}
	local ranked = {}
	for _, recipe in recipes do
		tieRanks[recipe.id] = stableHash(recipe.id .. ":" .. axisFingerprint)
		local matches = 0
		for _, tag in recipe.tags do
			if tags[tag] then
				matches += 1
			end
		end
		table.insert(ranked, {
			id = recipe.id,
			nameRu = recipe.nameRu,
			motif = recipe.motif,
			matches = matches,
			resonance = math.clamp(matches / #recipe.tags, 0, 1),
		})
	end
	table.sort(ranked, function(left, right)
		if left.matches ~= right.matches then
			return left.matches > right.matches
		end
		-- Both sides must use the same seed. The previous asymmetric hash could
		-- report a < b and b < a, aborting a real round inside table.sort.
		local leftRank, rightRank = tieRanks[left.id], tieRanks[right.id]
		if leftRank == rightRank then
			return left.id < right.id
		end
		return leftRank < rightRank
	end)

	local selected = {}
	for index = 1, math.min(3, #ranked) do
		table.insert(selected, ranked[index])
	end
	local signatureParts = {}
	local total = 0
	for _, result in selected do
		table.insert(signatureParts, result.id)
		total += result.resonance
	end
	return {
		version = 1,
		primary = selected[1],
		recipes = selected,
		resonance = if #selected > 0 then total / #selected else 0,
		signature = table.concat(signatureParts, "+"),
		axisSignals = axisSignals,
	}
end

function StyleChemistry.ResolveGenome(styleCatalog: any, genome: any): any
	return StyleChemistry.Resolve(styleCatalog, {
		palette = if type(genome) == "table" then genome.primaryPaletteId else nil,
		material = if type(genome) == "table" then genome.dominantMaterialId else nil,
		aura = if type(genome) == "table" then genome.dominantAuraId else nil,
		pose = if type(genome) == "table" then genome.dominantPoseId else nil,
		accent = if type(genome) == "table" then genome.dominantAccentId else nil,
	})
end

function StyleChemistry.GetRecipes(): { any }
	local result = {}
	for _, recipe in recipes do
		table.insert(result, table.clone(recipe))
	end
	return result
end

for _, recipe in recipes do
	table.freeze(recipe.tags)
	table.freeze(recipe)
end
table.freeze(recipes)

return table.freeze(StyleChemistry)
