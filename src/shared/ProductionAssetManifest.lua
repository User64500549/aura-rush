--!strict

-- Canonical production-asset registry. Empty asset IDs are intentional: local
-- source art is never presented to the runtime as uploaded Roblox content.
local DISTRICTS = {
	{
		id = "prism_metro",
		meshKit = { "kinetic_gate", "metro_facade", "liquid_chrome_landmark" },
		surfaces = { "liquid_chrome", "wet_stone", "carbon_textile", "prism_light" },
		stems = { "breakbeat", "mechanical_pulse", "metro_bass", "bloom_topline" },
	},
	{
		id = "cloud_bazaar",
		meshKit = { "soft_arch", "floating_pavilion", "pearl_landmark" },
		surfaces = { "inflated_silk", "porcelain", "cloud_foam", "opal_glass" },
		stems = { "soft_house", "air_bells", "cloud_bass", "bloom_topline" },
	},
	{
		id = "moonlit_greenhouse",
		meshKit = { "glass_rib", "living_branch", "luminous_flower" },
		surfaces = { "wet_obsidian", "translucent_leaf", "velvet_moss", "moon_glass" },
		stems = { "organic_pulse", "leaf_percussion", "moon_bass", "bloom_topline" },
	},
	{
		id = "orbital_boardwalk",
		meshKit = { "orbit_ring", "festival_ramp", "solar_beacon" },
		surfaces = { "star_glass", "lacquer", "carbon", "fiber_optic" },
		stems = { "cosmic_disco", "orbit_percussion", "festival_bass", "bloom_topline" },
	},
	{
		id = "velvet_archive",
		meshKit = { "archive_vault", "spiral_shelf", "page_spindle" },
		surfaces = { "ink_velvet", "silk_paper", "dark_brass", "book_glass" },
		stems = { "chamber_strings", "ink_percussion", "archive_bass", "bloom_topline" },
	},
	{
		id = "solar_cathedral",
		meshKit = { "sun_arch", "mirror_fan", "solar_flower" },
		surfaces = { "warm_glass", "solar_mirror", "ivory_stone", "gold_leaf" },
		stems = { "future_garage", "radiant_choir", "solar_bass", "bloom_topline" },
	},
}

local function slots(names: { string }): { any }
	local result = {}
	for _, name in names do
		table.insert(result, {
			name = name,
			assetId = "",
			owner = "",
			license = "",
			version = 1,
			measuredMemoryMb = 0,
			fallback = "procedural_v4",
		})
	end
	return result
end

local districts = {}
for _, district in DISTRICTS do
	table.insert(districts, {
		id = district.id,
		meshKit = slots(district.meshKit),
		surfaces = slots(district.surfaces),
		stems = slots(district.stems),
	})
end

local ProductionAssetManifest = {
	version = 1,
	brand = {
		keyArt = {
			localSource = "assets/brand/style-raid-key-art-v2.png",
			assetId = "",
			status = "awaiting_dashboard_upload",
		},
		icon = {
			localSource = "assets/brand/style-raid-icon-v2.png",
			assetId = "",
			status = "awaiting_dashboard_upload",
		},
		mapConcept = {
			localSource = "assets/brand/remix-city-premium-map-concept-v3.png",
			assetId = "",
			status = "production_reference_only",
		},
	},
	districts = districts,
}

function ProductionAssetManifest.IsConfigured(slot: any): boolean
	return type(slot) == "table" and type(slot.assetId) == "string" and slot.assetId ~= ""
end

function ProductionAssetManifest.GetReadiness(): any
	local configured = 0
	local total = 0
	for _, district in districts do
		for _, collection in { district.meshKit, district.surfaces, district.stems } do
			for _, slot in collection do
				total += 1
				if ProductionAssetManifest.IsConfigured(slot) then
					configured += 1
				end
			end
		end
	end
	return {
		configured = configured,
		total = total,
		ready = configured == total,
	}
end

return table.freeze(ProductionAssetManifest)
