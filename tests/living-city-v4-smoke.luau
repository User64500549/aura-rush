--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("AuraRushShared")
local server = ServerScriptService:WaitForChild("AuraRushServer")
local services = server:WaitForChild("Services")

local Config = require(shared:WaitForChild("Config"))
local StyleCatalog = require(shared:WaitForChild("StyleCatalog"))
local ProductionAssetManifest = require(shared:WaitForChild("ProductionAssetManifest"))
local ArtDirectionRegistry = require(shared:WaitForChild("ArtDirectionRegistry"))
local BloomComposerService = require(services:WaitForChild("BloomComposerService"))
local WorldService = require(services:WaitForChild("WorldService"))

local plan = {
	version = 4,
	seed = 4042026,
	worldId = "prism_metro",
	selectedRouteId = "kinetic_cascade",
	selectedRouteTitle = "Кинетический каскад",
	briefTreatment = { visualProfile = "high_voltage_editorial" },
	modifier = { id = "living_runway" },
	acts = {
		{
			id = "thread_run",
			legacyPhase = "ThreadRun",
			sceneId = "ThreadRun",
			objective = "Соберите световой след",
			semantic = "movement",
			mechanicTags = { "route_weave", "assist_chain" },
		},
		{
			id = "beat_lab",
			legacyPhase = "BeatLab",
			sceneId = "BeatLab",
			semantic = "rhythm",
			mechanicTags = { "sync_window" },
		},
		{
			id = "prism_puzzle",
			legacyPhase = "PrismPuzzle",
			sceneId = "PrismPuzzle",
			semantic = "composition",
			mechanicTags = { "palette_memory" },
		},
	},
}

local baseRecipe = {
	seed = 4042026,
	roundId = "v4_contract_round",
	worldId = "prism_metro",
	routeId = "kinetic_cascade",
	primaryHex = "8250FF",
	primaryColor = Color3.fromHex("8250FF"),
}
local genome = {
	primaryPaletteId = "palette_candy_voltage",
	dominantMaterialId = "material_metal",
	dominantAuraId = "aura_comet_tail",
	dominantPoseId = "pose_editorial_turn",
	dominantAccentId = "accent_prism_wings",
	diversity = 0.82,
	synergy = 0.91,
	fingerprint = "contract_crew_genome",
}
local recipe = BloomComposerService.Compose(StyleCatalog, baseRecipe, genome, plan, {
	completion = 0.94,
	mastery = 0.88,
	teamwork = 0.96,
})

assert(recipe.version == 4, "Aura Genome recipe did not upgrade to v4")
assert(recipe.presentation.version == 2, "presentation recipe contract changed")
assert(recipe.presentation.materialName == "Metal", "material axis is cosmetic-only")
assert(recipe.presentation.auraMotif == "comet", "aura axis is cosmetic-only")
assert(recipe.presentation.cameraPreset == "editorial_sweep", "pose axis is cosmetic-only")
assert(recipe.presentation.landmarkPreset == "prism_wings", "accent axis is cosmetic-only")
assert(recipe.presentation.routePattern == "cascade", "route did not affect presentation")
assert(#recipe.presentation.paletteStops >= 4, "palette recipe is incomplete")
assert(#recipe.mechanicTags >= 4, "run mechanics were not preserved in the bloom recipe")
assert(recipe.performance > 0.8, "performance did not influence the finale")

local repeatedRecipe = BloomComposerService.Compose(StyleCatalog, baseRecipe, genome, plan, {
	completion = 0.94,
	mastery = 0.88,
	teamwork = 0.96,
})
assert(
	repeatedRecipe.presentation.variant == recipe.presentation.variant,
	"presentation recipe is not deterministic"
)

WorldService.Init({ ArtDirectionRegistry = ArtDirectionRegistry })
local world = WorldService.Build()
assert(world:GetAttribute("PresentationVersion") == "remix_city_v6_ru", "v6 world missing")
local baseSpawn = WorldService.GetSpawn("ThreadRun")
WorldService.ApplyRunPlan(plan)
local activeGeometry = world:FindFirstChild("ActiveRunGeometry")
assert(activeGeometry ~= nil and activeGeometry:IsA("Model"), "adaptive route geometry missing")
assert(activeGeometry:GetAttribute("RoutePattern") == "cascade", "route geometry is generic")
assert(#activeGeometry:GetDescendants() >= 20, "route geometry is unexpectedly sparse")
assert(
	WorldService.GetSpawn("ThreadRun").Position ~= baseSpawn.Position,
	"selected route did not change the playable path"
)
assert(world:GetAttribute("ActiveRouteId") == "kinetic_cascade", "active route metadata missing")

WorldService.BeginWorldBloom(recipe, 3)
WorldService.AdvanceWorldBloom(3)
assert(world:GetAttribute("BloomRecipeVersion") == 4, "world did not consume recipe v4")
assert(world:GetAttribute("BloomMaterial") == "Metal", "world ignored chosen material")
assert(world:GetAttribute("BloomAuraMotif") == "comet", "world ignored chosen aura")
assert(world:GetAttribute("BloomCameraPreset") == "editorial_sweep", "camera preset missing")
assert(world:GetAttribute("BloomLandmarkPreset") == "prism_wings", "landmark preset missing")
assert(world:GetAttribute("BloomRoutePattern") == "cascade", "route pattern missing")
assert((world:GetAttribute("BloomPerformance") :: number) > 0.8, "performance metadata missing")

WorldService.TriggerGlowstorm("Контрактный автор")
local glowstorm = Workspace:FindFirstChild("AuraRushGlowstorm")
assert(glowstorm ~= nil and glowstorm:IsA("Model"), "Glowstorm marker missing")
assert(glowstorm:GetAttribute("ClientLocal") == true, "Glowstorm is not client-local")
assert(#glowstorm:GetDescendants() == 0, "server replicated Glowstorm particles")
local glowstormColor = Lighting:FindFirstChild("AuraRushGlowstormColor")
local glowstormBloom = Lighting:FindFirstChild("AuraRushGlowstormBloom")
assert(
	glowstormColor ~= nil
		and glowstormColor:IsA("ColorCorrectionEffect")
		and not glowstormColor.Enabled,
	"server forced a Glowstorm color filter"
)
assert(
	glowstormBloom ~= nil and glowstormBloom:IsA("BloomEffect") and not glowstormBloom.Enabled,
	"server forced a Glowstorm bloom filter"
)

assert(Config.FeatureFlags.BloomComposer2 == true, "Bloom Composer rollout disabled")
assert(Config.FeatureFlags.LivingCity == true, "Living City rollout disabled")
assert(Config.FeatureFlags.StyleOS == true, "Style OS rollout disabled")
assert(Config.FeatureFlags.RecommendationService == false, "unshipped recommender was enabled")
assert(Config.FeatureFlags.RewardedVideo == false, "unconfigured rewarded video was enabled")

local readiness = ProductionAssetManifest.GetReadiness()
assert(readiness.total >= 60, "production asset manifest is incomplete")
assert(readiness.configured == 0 and readiness.ready == false, "empty asset IDs were misreported")
assert(
	ProductionAssetManifest.brand.keyArt.localSource == "assets/brand/style-raid-key-art-v2.png",
	"v2 key art is not registered"
)
for _, district in ProductionAssetManifest.districts do
	for _, collection in { district.meshKit, district.surfaces, district.stems } do
		for _, slot in collection do
			assert(slot.assetId == "", "fake production asset ID leaked into the manifest")
			assert(slot.fallback == "procedural_v4", "safe procedural fallback missing")
		end
	end
end

print("AURA_RUSH_LIVING_CITY_" .. "V4_PASS")
