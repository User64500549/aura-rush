--!strict

-- Converts the existing five style categories into a stable semantic recipe.
-- The recipe contains catalog IDs only; it never grants or infers ownership.
local AuraGenomeService = {}
local BloomComposerService = require(script.Parent:WaitForChild("BloomComposerService"))

local CATEGORIES = { "palette", "material", "aura", "pose", "accent" }

local styleCatalog: any = nil

local function stableHash(value: string): number
	local hash = 2166136261
	for index = 1, #value do
		hash = bit32.bxor(hash, string.byte(value, index))
		hash = (hash * 16777619) % 2147483646
	end
	return math.max(math.floor(hash), 1)
end

local function getItem(itemId: string): any
	if type(styleCatalog) ~= "table" then
		return nil
	end
	if type(styleCatalog.GetById) == "function" then
		return styleCatalog.GetById(itemId)
	end
	return if type(styleCatalog.ById) == "table" then styleCatalog.ById[itemId] else nil
end

local function itemTags(item: any): { string }
	local source = if type(item) == "table" then item.tags or item.Tags else nil
	local result = {}
	if type(source) == "table" then
		for _, value in source do
			if type(value) == "string" then
				table.insert(result, value)
			end
		end
	end
	return result
end

local function colorFromPalette(item: any): Color3
	if type(item) == "table" then
		local source = item.ColorHex or item.colorHex
		if type(source) ~= "string" and type(item.colors) == "table" then
			source = item.colors[1]
		end
		if type(source) == "string" then
			local ok, color = pcall(Color3.fromHex, string.gsub(source, "#", ""))
			if ok then
				return color
			end
		end
	end
	return Color3.fromRGB(130, 72, 255)
end

local function dominant(counts: { [string]: number }, fallback: string): string
	local bestId = fallback
	local bestCount = -1
	for itemId, count in counts do
		if count > bestCount or (count == bestCount and itemId < bestId) then
			bestId = itemId
			bestCount = count
		end
	end
	return bestId
end

function AuraGenomeService.Init(context: any): ()
	styleCatalog = context.StyleCatalog
end

function AuraGenomeService.Capture(player: Player, styleService: any): any
	local loadout = styleService.GetLoadout(player)
	local genes = {}
	local fingerprintParts = {}
	local allTags = {}
	for _, category in CATEGORIES do
		local itemId = if type(loadout[category]) == "string" then loadout[category] else ""
		local item = getItem(itemId)
		local tags = itemTags(item)
		genes[category] = {
			category = category,
			itemId = itemId,
			tags = tags,
			visual = if type(item) == "table"
				then item.Variant
					or item.materialName
					or item.auraPreset
					or item.posePreset
					or item.accentPreset
				else nil,
		}
		table.insert(fingerprintParts, itemId)
		for _, tag in tags do
			allTags[tag] = true
		end
	end
	local paletteItem = getItem(loadout.palette or "")
	local color = colorFromPalette(paletteItem)
	local fingerprint = table.concat(fingerprintParts, "/")
	return {
		version = 1,
		userId = player.UserId,
		genes = genes,
		loadout = loadout,
		color = color,
		colorHex = color:ToHex(),
		tags = allTags,
		fingerprint = tostring(stableHash(fingerprint)),
	}
end

function AuraGenomeService.CaptureTeam(players: { Player }, styleService: any): any
	local byUserId = {}
	local countsByCategory: { [string]: { [string]: number } } = {}
	local uniqueByCategory: { [string]: { [string]: boolean } } = {}
	for _, category in CATEGORIES do
		countsByCategory[category] = {}
		uniqueByCategory[category] = {}
	end

	local red, green, blue = 0, 0, 0
	local fingerprintParts = {}
	for _, player in players do
		local genome = AuraGenomeService.Capture(player, styleService)
		byUserId[tostring(player.UserId)] = genome
		red += genome.color.R
		green += genome.color.G
		blue += genome.color.B
		table.insert(fingerprintParts, genome.fingerprint)
		for _, category in CATEGORIES do
			local itemId = genome.genes[category].itemId
			countsByCategory[category][itemId] = (countsByCategory[category][itemId] or 0) + 1
			uniqueByCategory[category][itemId] = true
		end
	end

	table.sort(fingerprintParts)
	local count = math.max(#players, 1)
	local diversityTotal = 0
	local uniqueCounts = {}
	for _, category in CATEGORIES do
		local uniqueCount = 0
		for _ in uniqueByCategory[category] do
			uniqueCount += 1
		end
		uniqueCounts[category] = uniqueCount
		diversityTotal += uniqueCount / count
	end
	local diversity = math.clamp(diversityTotal / #CATEGORIES, 0, 1)
	local averageColor = if #players > 0
		then Color3.new(red / #players, green / #players, blue / #players)
		else Color3.fromRGB(130, 72, 255)
	local fingerprint = tostring(stableHash(table.concat(fingerprintParts, ":")))

	return {
		version = 1,
		players = byUserId,
		fingerprint = fingerprint,
		participantCount = #players,
		color = averageColor,
		colorHex = averageColor:ToHex(),
		primaryPaletteId = dominant(countsByCategory.palette, "palette_prism"),
		dominantMaterialId = dominant(countsByCategory.material, "material_smooth"),
		dominantAuraId = dominant(countsByCategory.aura, "aura_spark"),
		dominantPoseId = dominant(countsByCategory.pose, "pose_hero"),
		dominantAccentId = dominant(countsByCategory.accent, "accent_orbit"),
		uniqueCounts = uniqueCounts,
		diversity = diversity,
		synergy = math.clamp(0.5 + diversity * 0.5, 0, 1),
	}
end

function AuraGenomeService.BuildBloomRecipe(
	roundId: string,
	seed: number,
	brief: any,
	teamGenome: any,
	runPlan: any,
	performance: any?
): any
	local worldId = if type(runPlan) == "table" and type(runPlan.worldId) == "string"
		then runPlan.worldId
		else "prism_metro"
	local accentHex = if type(brief) == "table"
		then brief.AccentHex or brief.accentHex or teamGenome.colorHex
		else teamGenome.colorHex
	local actIds = {}
	if type(runPlan) == "table" and type(runPlan.acts) == "table" then
		for _, act in runPlan.acts do
			table.insert(actIds, act.id)
		end
	end
	local baseRecipe = {
		version = 2,
		roundId = roundId,
		seed = seed,
		worldId = worldId,
		primaryColor = teamGenome.color,
		primaryHex = teamGenome.colorHex,
		accentHex = accentHex,
		paletteId = teamGenome.primaryPaletteId,
		materialId = teamGenome.dominantMaterialId,
		auraId = teamGenome.dominantAuraId,
		poseId = teamGenome.dominantPoseId,
		accentId = teamGenome.dominantAccentId,
		diversity = teamGenome.diversity,
		synergy = teamGenome.synergy,
		routeId = if type(runPlan) == "table" then runPlan.selectedRouteId else nil,
		modifierId = if type(runPlan) == "table" and type(runPlan.modifier) == "table"
			then runPlan.modifier.id
			else nil,
		actIds = actIds,
		bloomActs = {
			{ index = 1, id = "seed", intensity = 0.32 },
			{ index = 2, id = "cascade", intensity = 0.68 },
			{ index = 3, id = "bloom", intensity = 1 },
		},
	}
	return BloomComposerService.Compose(styleCatalog, baseRecipe, teamGenome, runPlan, performance)
end

return AuraGenomeService
