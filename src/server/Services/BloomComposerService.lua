--!strict

-- Converts the semantic Aura Genome into a deterministic presentation recipe.
-- The composer only returns catalog IDs, authored presets and bounded numbers;
-- it never grants ownership and never depends on uploaded assets being present.
local BloomComposerService = {}

local DEFAULT_PALETTE = { "8250FF", "38E8FF", "FF6B8B", "FFF06A" }

local CAMERA_PRESETS = {
	Hero = "hero_arc",
	Wave = "friendly_push",
	Peace = "portrait_snap",
	PowerStep = "kinetic_chase",
	CloudFloat = "soft_orbit",
	Detective = "mystery_reveal",
	StarPoint = "landmark_tilt",
	DuoMirror = "duo_mirror",
	EditorialTurn = "editorial_sweep",
	ZeroG = "zero_g_roll",
	PrismVogue = "prism_cut",
	BloomFinale = "bloom_crane",
	SquadSkyline = "squad_skyline",
}

local LANDMARK_PRESETS = {
	OrbitRings = "orbit_rings",
	StarterWings = "wing_gate",
	StarPin = "star_beacon",
	PrismWings = "prism_wings",
	CloudBow = "soft_arch",
	FlowerCrown = "petal_crown",
	GlitchCape = "glitch_banner",
	MoonSatellites = "moon_orbits",
	BloomCrown = "bloom_crown",
}

local AURA_PRESETS = {
	SoftSpark = { motif = "spark", pulse = 0.78, emission = 0.34 },
	PrismPulse = { motif = "pulse", pulse = 1, emission = 0.5 },
	FirstMiracle = { motif = "miracle", pulse = 0.9, emission = 0.52 },
	PixelBurst = { motif = "pixel", pulse = 1.12, emission = 0.58 },
	RibbonOrbit = { motif = "ribbon", pulse = 0.86, emission = 0.44 },
	BubblePop = { motif = "bubble", pulse = 0.8, emission = 0.38 },
	FireflyCloud = { motif = "firefly", pulse = 0.68, emission = 0.3 },
	PrismRain = { motif = "rain", pulse = 0.94, emission = 0.48 },
	HeartSignal = { motif = "heart", pulse = 0.88, emission = 0.42 },
	CometTail = { motif = "comet", pulse = 1.16, emission = 0.6 },
	FlowerEcho = { motif = "petal", pulse = 0.74, emission = 0.4 },
	GlitchHalo = { motif = "glitch", pulse = 1.2, emission = 0.62 },
	MoonMist = { motif = "mist", pulse = 0.62, emission = 0.26 },
	Sunbeam = { motif = "ray", pulse = 0.92, emission = 0.56 },
	JellyOrbit = { motif = "jelly", pulse = 0.72, emission = 0.36 },
	Constellation = { motif = "star", pulse = 0.84, emission = 0.48 },
	AuroraCrown = { motif = "aurora", pulse = 0.76, emission = 0.54 },
	WorldBloom = { motif = "bloom", pulse = 1, emission = 0.68 },
}

local ROUTE_PATTERNS = {
	kinetic_cascade = "cascade",
	precision_atelier = "precision_grid",
	wild_remix = "split_remix",
}

local function stableHash(value: string): number
	local hash = 2166136261
	for index = 1, #value do
		hash = bit32.bxor(hash, string.byte(value, index))
		hash = (hash * 16777619) % 2147483646
	end
	return math.max(math.floor(hash), 1)
end

local function cleanHex(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local clean = string.upper(string.gsub(value, "#", ""))
	if #clean ~= 6 or tonumber(clean, 16) == nil then
		return nil
	end
	return clean
end

local function getItem(styleCatalog: any, itemId: any): any
	if type(itemId) ~= "string" or type(styleCatalog) ~= "table" then
		return nil
	end
	if type(styleCatalog.GetById) == "function" then
		local ok, item = pcall(styleCatalog.GetById, itemId)
		if ok and type(item) == "table" then
			return item
		end
	end
	local byId = styleCatalog.ById
	return if type(byId) == "table" then byId[itemId] else nil
end

local function paletteStops(item: any, fallback: any): { string }
	local result = {}
	local source = if type(item) == "table" then item.colors or item.Colors else nil
	if type(source) == "table" then
		for _, value in source do
			local clean = cleanHex(value)
			if clean then
				table.insert(result, clean)
			end
		end
	end
	if #result == 0 then
		local clean = cleanHex(fallback)
		if clean then
			table.insert(result, clean)
		end
	end
	for _, value in DEFAULT_PALETTE do
		if #result >= 4 then
			break
		end
		table.insert(result, value)
	end
	return result
end

local function visualValue(item: any, ...: string): string?
	if type(item) ~= "table" then
		return nil
	end
	for _, key in { ... } do
		local value = item[key]
		if type(value) == "string" and value ~= "" then
			return value
		end
	end
	return nil
end

local function collectMechanicTags(runPlan: any): { string }
	local seen: { [string]: boolean } = {}
	local result = {}
	local function append(value: any): ()
		if type(value) == "string" and value ~= "" and not seen[value] then
			seen[value] = true
			table.insert(result, value)
		end
	end
	if type(runPlan) == "table" and type(runPlan.acts) == "table" then
		for _, act in runPlan.acts do
			if type(act) == "table" and type(act.mechanicTags) == "table" then
				for _, tag in act.mechanicTags do
					append(tag)
				end
			end
		end
	end
	return result
end

local function performanceScore(performance: any): number
	if type(performance) ~= "table" then
		return 0.55
	end
	local completion = math.clamp(tonumber(performance.completion) or 0, 0, 1)
	local mastery = math.clamp(tonumber(performance.mastery) or completion, 0, 1)
	local teamwork = math.clamp(tonumber(performance.teamwork) or completion, 0, 1)
	return math.clamp(completion * 0.5 + mastery * 0.28 + teamwork * 0.22, 0, 1)
end

function BloomComposerService.Compose(
	styleCatalog: any,
	base: any,
	teamGenome: any,
	runPlan: any,
	performance: any?
): any
	local paletteId = tostring(teamGenome.primaryPaletteId or "palette_prism")
	local materialId = tostring(teamGenome.dominantMaterialId or "material_smooth")
	local auraId = tostring(teamGenome.dominantAuraId or "aura_spark")
	local poseId = tostring(teamGenome.dominantPoseId or "pose_hero")
	local accentId = tostring(teamGenome.dominantAccentId or "accent_orbit")

	local paletteItem = getItem(styleCatalog, paletteId)
	local materialItem = getItem(styleCatalog, materialId)
	local auraItem = getItem(styleCatalog, auraId)
	local poseItem = getItem(styleCatalog, poseId)
	local accentItem = getItem(styleCatalog, accentId)

	local materialName = visualValue(materialItem, "materialName", "Material", "Variant")
		or "SmoothPlastic"
	local auraName = visualValue(auraItem, "auraPreset", "Variant") or "SoftSpark"
	local poseName = visualValue(poseItem, "posePreset", "Variant") or "Hero"
	local accentName = visualValue(accentItem, "accentPreset", "Variant") or "OrbitRings"
	local aura = AURA_PRESETS[auraName] or AURA_PRESETS.SoftSpark
	local routeId = if type(runPlan) == "table"
		then tostring(runPlan.selectedRouteId or "wild_remix")
		else "wild_remix"
	local visualProfile = if type(runPlan) == "table"
			and type(runPlan.briefTreatment) == "table"
		then tostring(runPlan.briefTreatment.visualProfile or "open_canvas")
		else "open_canvas"
	local diversity = math.clamp(tonumber(teamGenome.diversity) or 0, 0, 1)
	local synergy = math.clamp(tonumber(teamGenome.synergy) or 0.5, 0, 1)
	local performanceValue = performanceScore(performance)
	local intensity =
		math.clamp(0.34 + synergy * 0.28 + diversity * 0.12 + performanceValue * 0.26, 0.4, 1)
	local seed = math.max(math.floor(tonumber(base.seed) or 1), 1)
	local fingerprint = tostring(teamGenome.fingerprint or "default")
	local palette = paletteStops(paletteItem, base.primaryHex)
	local cameraPreset = CAMERA_PRESETS[poseName] or "hero_arc"
	local landmarkPreset = LANDMARK_PRESETS[accentName] or "orbit_rings"

	local result = table.clone(base)
	result.version = 4
	result.paletteId = paletteId
	result.materialId = materialId
	result.auraId = auraId
	result.poseId = poseId
	result.accentId = accentId
	result.performance = performanceValue
	result.mechanicTags = collectMechanicTags(runPlan)
	result.presentation = {
		version = 2,
		paletteStops = palette,
		materialName = materialName,
		auraPreset = auraName,
		auraMotif = aura.motif,
		pulseRate = aura.pulse,
		emission = math.clamp(aura.emission * (0.72 + intensity * 0.45), 0.18, 0.9),
		posePreset = poseName,
		cameraPreset = cameraPreset,
		accentPreset = accentName,
		landmarkPreset = landmarkPreset,
		routePattern = ROUTE_PATTERNS[routeId] or "split_remix",
		visualProfile = visualProfile,
		intensity = intensity,
		colorBlend = math.clamp(0.24 + diversity * 0.24, 0.24, 0.52),
		landmarkScale = math.clamp(0.9 + synergy * 0.28, 0.9, 1.18),
		variant = (stableHash(`{seed}:{fingerprint}:{routeId}`) % 3) + 1,
	}
	result.bloomActs = {
		{
			index = 1,
			id = "seed",
			intensity = math.clamp(intensity * 0.34, 0.24, 0.4),
			paletteIndex = 1,
		},
		{
			index = 2,
			id = "cascade",
			intensity = math.clamp(intensity * 0.7, 0.5, 0.76),
			paletteIndex = 2,
		},
		{ index = 3, id = "bloom", intensity = intensity, paletteIndex = 3 },
	}
	return result
end

return BloomComposerService
