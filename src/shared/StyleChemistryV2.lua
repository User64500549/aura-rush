--!strict
-- StyleChemistryV2: frozen module of pure, deterministic style-fusion functions.
-- No side effects, no state. Same inputs always produce the same outputs.

local M = {}

-- Genome categories that participate in style chemistry.
M.Categories = table.freeze({
	"palette",
	"material",
	"aura",
	"pose",
	"accent",
})

-- djb2 string hash, bounded to a stable positive range.
-- hash = 5381; hash = (hash * 33 + string.byte(c)) % 2147483646
local function djb2(text: string): number
	local hash = 5381
	for i = 1, #text do
		hash = (hash * 33 + string.byte(text, i)) % 2147483646
	end
	return hash
end

M.Hash = djb2

-- Frozen recipe table. Each entry maps a stable bucket to a deterministic effect.
-- Selection is derived purely from the combined hash of the input ids.
local Recipes = table.freeze({
	table.freeze({
		fusedAuraId = "fused_prism_cascade",
		effect = table.freeze({ hue = 12, intensity = 0.85, shimmer = 0.40, trail = "cascade" }),
	}),
	table.freeze({
		fusedAuraId = "fused_ember_veil",
		effect = table.freeze({ hue = 348, intensity = 0.92, shimmer = 0.28, trail = "veil" }),
	}),
	table.freeze({
		fusedAuraId = "fused_verdant_pulse",
		effect = table.freeze({ hue = 128, intensity = 0.78, shimmer = 0.55, trail = "pulse" }),
	}),
	table.freeze({
		fusedAuraId = "fused_lunar_drift",
		effect = table.freeze({ hue = 214, intensity = 0.70, shimmer = 0.66, trail = "drift" }),
	}),
	table.freeze({
		fusedAuraId = "fused_solar_crown",
		effect = table.freeze({ hue = 46, intensity = 0.98, shimmer = 0.33, trail = "crown" }),
	}),
	table.freeze({
		fusedAuraId = "fused_void_bloom",
		effect = table.freeze({ hue = 279, intensity = 0.88, shimmer = 0.48, trail = "bloom" }),
	}),
})

M.Recipes = Recipes

export type FusionEffect = {
	hue: number,
	intensity: number,
	shimmer: number,
	trail: string,
}

export type FusionResult = {
	fusedAuraId: string,
	effect: FusionEffect,
}

-- Fuse a deterministic set of ids into a single fused aura result.
-- Ids are sorted before hashing so the result is order-independent.
function M.Fuse(ids: { string }): FusionResult
	local ordered: { string } = table.create(#ids)
	for i = 1, #ids do
		ordered[i] = ids[i]
	end
	table.sort(ordered)

	local combined = table.concat(ordered, "|")
	local hash = djb2(combined)
	local index = (hash % #Recipes) + 1

	return Recipes[index]
end

return table.freeze(M)
