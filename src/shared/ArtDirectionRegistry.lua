--!strict

export type LightingProfile = {
	brightness: number,
	clockTime: number,
	ambientHex: string,
	outdoorAmbientHex: string,
	atmosphereDensity: number,
	atmosphereHaze: number,
	bloomIntensity: number,
	bloomSize: number,
}

export type WorldArtProfile = {
	id: string,
	displayNameKey: string,
	accentHex: string,
	palette: { string },
	materialFamilies: { string },
	silhouetteLanguage: { string },
	soundMotif: string,
	normal: LightingProfile,
	bloom: LightingProfile,
}

local function lighting(
	brightness: number,
	clockTime: number,
	ambientHex: string,
	outdoorAmbientHex: string,
	density: number,
	haze: number,
	bloomIntensity: number,
	bloomSize: number
): LightingProfile
	return table.freeze({
		brightness = brightness,
		clockTime = clockTime,
		ambientHex = ambientHex,
		outdoorAmbientHex = outdoorAmbientHex,
		atmosphereDensity = density,
		atmosphereHaze = haze,
		bloomIntensity = bloomIntensity,
		bloomSize = bloomSize,
	})
end

local function world(profile: WorldArtProfile): WorldArtProfile
	table.freeze(profile.palette)
	table.freeze(profile.materialFamilies)
	table.freeze(profile.silhouetteLanguage)
	return table.freeze(profile)
end

local worlds: { WorldArtProfile } = {
	world({
		id = "prism_metro",
		displayNameKey = "brief.world.prism_metro.name",
		accentHex = "38E8FF",
		palette = { "172039", "38E8FF", "FF6B8B", "C6D4FF" },
		materialFamilies = {
			"LiquidChrome",
			"HolographicGlass",
			"WetStone",
			"CarbonTextile",
			"PrismLight",
		},
		silhouetteLanguage = { "diagonal", "kinetic_gate", "long_perspective" },
		soundMotif = "mechanical_editorial_breakbeat",
		normal = lighting(2.2, 21.2, "18213D", "304A67", 0.32, 1.1, 0.18, 28),
		bloom = lighting(3.0, 22.0, "2A2461", "17677B", 0.24, 1.7, 0.62, 42),
	}),
	world({
		id = "cloud_bazaar",
		displayNameKey = "brief.world.cloud_bazaar.name",
		accentHex = "FFC8DD",
		palette = { "FFF7ED", "FFC8DD", "B8F2E6", "CDB4DB" },
		materialFamilies = { "InflatedSilk", "Porcelain", "Pearl", "CloudFoam", "OpalGlass" },
		silhouetteLanguage = { "soft_arch", "floating_pavilion", "round_volume" },
		soundMotif = "air_bells_soft_house",
		normal = lighting(2.7, 8.4, "D6CDE5", "C7E7E8", 0.2, 0.7, 0.12, 22),
		bloom = lighting(3.3, 7.8, "E8C9DA", "B5ECE3", 0.16, 1.1, 0.45, 36),
	}),
	world({
		id = "moonlit_greenhouse",
		displayNameKey = "brief.world.moonlit_greenhouse.name",
		accentHex = "94D2BD",
		palette = { "071A17", "0A9396", "94D2BD", "B58CFF" },
		materialFamilies = {
			"WetObsidian",
			"TranslucentLeaf",
			"LuminousVein",
			"MoonGlass",
			"VelvetMoss",
		},
		silhouetteLanguage = { "branch", "petal", "glass_rib" },
		soundMotif = "organic_pulse_whispered_leaves",
		normal = lighting(1.7, 0.2, "0A2A25", "14223A", 0.4, 1.9, 0.16, 30),
		bloom = lighting(2.4, 1.0, "164A3D", "392A63", 0.3, 2.3, 0.55, 40),
	}),
	world({
		id = "orbital_boardwalk",
		displayNameKey = "brief.world.orbital_boardwalk.name",
		accentHex = "9B5DE5",
		palette = { "0B0C2A", "9B5DE5", "FFD166", "F72585" },
		materialFamilies = { "StarGlass", "Lacquer", "Carbon", "FiberOptic", "SolarMetal" },
		silhouetteLanguage = { "orbit", "festival_ramp", "wide_ring" },
		soundMotif = "cosmic_disco_groove",
		normal = lighting(1.9, 23.0, "17183B", "332B5A", 0.18, 1.4, 0.2, 32),
		bloom = lighting(3.1, 23.5, "372A75", "695217", 0.13, 2.0, 0.65, 45),
	}),
	world({
		id = "velvet_archive",
		displayNameKey = "brief.world.velvet_archive.name",
		accentHex = "E0AAFF",
		palette = { "160B22", "5A189A", "E0AAFF", "F3D9B1" },
		materialFamilies = { "InkVelvet", "SilkPaper", "DarkBrass", "BookGlass", "StarlitThread" },
		silhouetteLanguage = { "vault", "flying_page", "spiral_shelf" },
		soundMotif = "chamber_strings_ink_percussion",
		normal = lighting(1.8, 19.5, "281632", "4B3352", 0.29, 1.2, 0.13, 26),
		bloom = lighting(2.8, 20.4, "522A66", "8B6543", 0.22, 1.8, 0.58, 40),
	}),
	world({
		id = "solar_cathedral",
		displayNameKey = "brief.world.solar_cathedral.name",
		accentHex = "FFD166",
		palette = { "3A1D12", "FF9F1C", "FFD166", "FFF4D6" },
		materialFamilies = { "WarmGlass", "SolarMirror", "IvoryStone", "GoldLeaf", "LightFabric" },
		silhouetteLanguage = { "sun_arch", "vertical_ray", "mirror_fan" },
		soundMotif = "radiant_choir_future_garage",
		normal = lighting(2.9, 16.7, "A65A3A", "D39B58", 0.12, 0.9, 0.1, 20),
		bloom = lighting(3.8, 17.2, "D9823C", "FFE7A0", 0.08, 1.2, 0.5, 38),
	}),
}

local byId: { [string]: WorldArtProfile } = {}
for _, profile in worlds do
	assert(byId[profile.id] == nil, `Duplicate art world id: {profile.id}`)
	assert(#profile.palette >= 4, `World {profile.id} needs a complete color script`)
	assert(#profile.materialFamilies >= 5, `World {profile.id} needs five material families`)
	byId[profile.id] = profile
end

table.freeze(worlds)
table.freeze(byId)

local ArtDirectionRegistry = {
	Worlds = worlds,
	ById = byId,
	Count = #worlds,
}

function ArtDirectionRegistry.GetWorld(id: string): WorldArtProfile?
	return byId[id]
end

return table.freeze(ArtDirectionRegistry)
