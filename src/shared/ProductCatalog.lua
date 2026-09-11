--!strict

local Types = require(script.Parent.Types)
type DeveloperProductDefinition = Types.DeveloperProductDefinition
type PassDefinition = Types.PassDefinition
type SubscriptionDefinition = Types.SubscriptionDefinition

-- IDs intentionally remain 0 until configured in Creator Dashboard. Robux prices are
-- never stored here: UI must obtain the current localized price from MarketplaceService.
local developerProducts: { DeveloperProductDefinition } = table.freeze({
	table.freeze({
		key = "glowdust_pocket",
		id = 0,
		displayNameKey = "product.glowdust_pocket.name",
		descriptionKey = "product.glowdust_pocket.description",
		grant = table.freeze({ kind = "GlowDust", amount = 250 }),
	}),
	table.freeze({
		key = "glowdust_bundle",
		id = 0,
		displayNameKey = "product.glowdust_bundle.name",
		descriptionKey = "product.glowdust_bundle.description",
		grant = table.freeze({ kind = "GlowDust", amount = 900 }),
	}),
	table.freeze({
		key = "glowdust_vault",
		id = 0,
		displayNameKey = "product.glowdust_vault.name",
		descriptionKey = "product.glowdust_vault.description",
		grant = table.freeze({ kind = "GlowDust", amount = 3000 }),
	}),
	table.freeze({
		key = "server_glowstorm",
		id = 0,
		displayNameKey = "product.server_glowstorm.name",
		descriptionKey = "product.server_glowstorm.description",
		grant = table.freeze({ kind = "ActivationToken", tokenId = "glowstorm", amount = 1 }),
	}),
	table.freeze({
		key = "signature_prism_collection",
		id = 0,
		displayNameKey = "product.signature_prism_collection.name",
		descriptionKey = "product.signature_prism_collection.description",
		grant = table.freeze({
			kind = "CosmeticBundle",
			bundleId = "signature_prism_collection",
			duplicateGlowDustPerItem = 400,
			itemIds = table.freeze({
				"palette_solar_flare",
				"aura_glitch_halo",
				"pose_editorial_turn",
			}),
		}),
	}),
})

local passes: { PassDefinition } = table.freeze({
	table.freeze({
		key = "director_pack",
		id = 0,
		displayNameKey = "pass.director_pack.name",
		descriptionKey = "pass.director_pack.description",
		benefits = table.freeze({
			"benefit.camera_presets",
			"benefit.transitions",
			"benefit.capture_frames",
		}),
	}),
	table.freeze({
		key = "atelier_pro",
		id = 0,
		displayNameKey = "pass.atelier_pro.name",
		descriptionKey = "pass.atelier_pro.description",
		benefits = table.freeze({
			"benefit.lookbook_slots",
			"benefit.studio_decor",
			"benefit.look_variants",
		}),
	}),
	table.freeze({
		key = "prism_patron",
		id = 0,
		displayNameKey = "pass.prism_patron.name",
		descriptionKey = "pass.prism_patron.description",
		benefits = table.freeze({
			"benefit.cosmetic_nameplate",
			"benefit.vip_lounge",
			"benefit.vip_cosmetics",
		}),
	}),
})

local subscriptions: { SubscriptionDefinition } = table.freeze({
	table.freeze({
		key = "aura_club",
		-- Roblox subscription IDs are strings (for example "EXP-...").
		id = "",
		displayNameKey = "subscription.aura_club.name",
		descriptionKey = "subscription.aura_club.description",
		benefits = table.freeze({
			"benefit.monthly_cosmetics",
			"benefit.monthly_studio_theme",
			"benefit.lookbook_slots",
			"benefit.color_variants",
			"benefit.celebration_token",
		}),
	}),
})

-- Never delete a configured developer-product ID after it has been sold. Move
-- its exact deterministic grant here so delayed/open receipts can still be
-- honored without keeping the retired offer visible in the shop.
local retiredDeveloperProducts: { any } = table.freeze({})

local productByKey: { [string]: DeveloperProductDefinition } = {}
local productById: { [number]: DeveloperProductDefinition } = {}
local retiredProductById: { [number]: any } = {}
local passByKey: { [string]: PassDefinition } = {}
local passById: { [number]: PassDefinition } = {}
local subscriptionByKey: { [string]: SubscriptionDefinition } = {}
local subscriptionById: { [string]: SubscriptionDefinition } = {}

for _, definition in developerProducts do
	assert(productByKey[definition.key] == nil, `Duplicate product key: {definition.key}`)
	productByKey[definition.key] = definition
	if definition.id > 0 then
		assert(
			productById[definition.id] == nil,
			`Duplicate configured product id: {definition.id}`
		)
		productById[definition.id] = definition
	end
end

for _, definition in retiredDeveloperProducts do
	assert(type(definition.id) == "number" and definition.id > 0, "Invalid retired product id")
	assert(productById[definition.id] == nil, "Retired product id is still active")
	assert(retiredProductById[definition.id] == nil, "Duplicate retired product id")
	assert(type(definition.grant) == "table", "Retired product must preserve its grant")
	retiredProductById[definition.id] = definition
end

for _, definition in passes do
	assert(passByKey[definition.key] == nil, `Duplicate pass key: {definition.key}`)
	passByKey[definition.key] = definition
	if definition.id > 0 then
		assert(passById[definition.id] == nil, `Duplicate configured pass id: {definition.id}`)
		passById[definition.id] = definition
	end
end

for _, definition in subscriptions do
	assert(subscriptionByKey[definition.key] == nil, `Duplicate subscription key: {definition.key}`)
	subscriptionByKey[definition.key] = definition
	if #definition.id > 0 then
		assert(
			subscriptionById[definition.id] == nil,
			`Duplicate configured subscription id: {definition.id}`
		)
		subscriptionById[definition.id] = definition
	end
end

table.freeze(productByKey)
table.freeze(productById)
table.freeze(retiredProductById)
table.freeze(passByKey)
table.freeze(passById)
table.freeze(subscriptionByKey)
table.freeze(subscriptionById)

local ProductCatalog = {
	DeveloperProducts = developerProducts,
	RetiredDeveloperProducts = retiredDeveloperProducts,
	Passes = passes,
	Subscriptions = subscriptions,
}

function ProductCatalog.GetProduct(key: string): DeveloperProductDefinition?
	return productByKey[key]
end

function ProductCatalog.GetProductById(id: number): DeveloperProductDefinition?
	return productById[id]
end

function ProductCatalog.GetDeveloperProductById(id: number): DeveloperProductDefinition?
	return productById[id]
end

function ProductCatalog.GetRetiredDeveloperProductById(id: number): any
	return retiredProductById[id]
end

function ProductCatalog.GetPass(key: string): PassDefinition?
	return passByKey[key]
end

function ProductCatalog.GetPassById(id: number): PassDefinition?
	return passById[id]
end

function ProductCatalog.GetSubscription(key: string): SubscriptionDefinition?
	return subscriptionByKey[key]
end

function ProductCatalog.GetSubscriptionById(id: string): SubscriptionDefinition?
	return subscriptionById[id]
end

function ProductCatalog.IsConfigured(
	definition: DeveloperProductDefinition | PassDefinition | SubscriptionDefinition
): boolean
	local id = (definition :: any).id
	return if type(id) == "number" then id > 0 else type(id) == "string" and #id > 0
end

return table.freeze(ProductCatalog)
