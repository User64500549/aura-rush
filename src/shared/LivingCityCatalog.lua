--!strict
-- LivingCityCatalog: frozen, data-only description of the Living City system.
-- No functions, no side effects. Every nested table is frozen so consumers
-- cannot mutate shared contract data at runtime.

local M = {}

-- District identifiers and their static presentation data.
M.Districts = table.freeze({
	table.freeze({
		id = "prism_metro",
		displayName = "Prism Metro",
		biome = "urban",
		baseBloomWeight = 1.0,
	}),
	table.freeze({
		id = "cloud_bazaar",
		displayName = "Cloud Bazaar",
		biome = "sky",
		baseBloomWeight = 1.1,
	}),
	table.freeze({
		id = "moonlit_greenhouse",
		displayName = "Moonlit Greenhouse",
		biome = "flora",
		baseBloomWeight = 1.25,
	}),
	table.freeze({
		id = "orbital_boardwalk",
		displayName = "Orbital Boardwalk",
		biome = "space",
		baseBloomWeight = 1.15,
	}),
	table.freeze({
		id = "velvet_archive",
		displayName = "Velvet Archive",
		biome = "interior",
		baseBloomWeight = 0.9,
	}),
	table.freeze({
		id = "solar_cathedral",
		displayName = "Solar Cathedral",
		biome = "radiant",
		baseBloomWeight = 1.35,
	}),
})

-- Fast lookup by district id.
M.DistrictById = table.freeze({
	prism_metro = M.Districts[1],
	cloud_bazaar = M.Districts[2],
	moonlit_greenhouse = M.Districts[3],
	orbital_boardwalk = M.Districts[4],
	velvet_archive = M.Districts[5],
	solar_cathedral = M.Districts[6],
})

-- Bloom memory tiers with numeric thresholds (inclusive lower bound).
M.BloomTiers = table.freeze({
	table.freeze({ id = "Dormant", threshold = 0 }),
	table.freeze({ id = "Stirring", threshold = 100 }),
	table.freeze({ id = "Blooming", threshold = 400 }),
	table.freeze({ id = "Radiant", threshold = 1000 }),
})

M.BloomTierByName = table.freeze({
	Dormant = M.BloomTiers[1],
	Stirring = M.BloomTiers[2],
	Blooming = M.BloomTiers[3],
	Radiant = M.BloomTiers[4],
})

-- Decay rules applied to a district's bloom memory over time.
M.Decay = table.freeze({
	decayPerHour = 25,
	floor = 0,
})

-- Cross-server CityBloom event contract.
M.CityBloom = table.freeze({
	id = "city_bloom_seasonal",
	topic = "AuraRush_CityBloom_v1",
	milestones = table.freeze({
		table.freeze({ id = "spark", value = 5000, reward = "aura_bloom_spark" }),
		table.freeze({ id = "flourish", value = 25000, reward = "aura_bloom_flourish" }),
		table.freeze({ id = "ascension", value = 100000, reward = "aura_bloom_ascension" }),
	}),
})

return table.freeze(M)
