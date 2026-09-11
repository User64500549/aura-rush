--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local shared = ReplicatedStorage:WaitForChild("AuraRushShared")
local serverRoot = ServerScriptService:WaitForChild("AuraRushServer")
local services = serverRoot:WaitForChild("Services")

local WorldService = require(services:WaitForChild("WorldService"))
local RunDirectorService = require(services:WaitForChild("RunDirectorService"))
local ChallengeService = require(services:WaitForChild("ChallengeService"))
local AuraGenomeService = require(services:WaitForChild("AuraGenomeService"))
local StyleCatalog = require(shared:WaitForChild("StyleCatalog"))
local BriefCatalog = require(shared:WaitForChild("BriefCatalog"))
local Config = require(shared:WaitForChild("Config"))

WorldService.Init({})
local world = WorldService.Build()
assert(#WorldService.GetCollectibles() == 8, "legacy Thread Run collectible contract changed")
assert(#WorldService.GetCollectibles("material_surf") == 8, "Material Surf samples missing")
assert(#WorldService.GetAllCollectibles() == 16, "unexpected total collectible count")

for _, zoneName in
	{
		"MaterialSurf",
		"LightLoom",
		"BloomRescue",
		"VelvetArchive",
		"SolarCathedral",
	}
do
	assert(world:FindFirstChild(zoneName) ~= nil, zoneName .. " is missing")
end
for _, worldId in { "velvet_archive", "solar_cathedral" } do
	assert(
		world:FindFirstChild("FinaleCamera_" .. worldId, true) ~= nil,
		"finale camera missing for " .. worldId
	)
end

local fakeTeamGenome = {
	fingerprint = "smoke-team",
	primaryPaletteId = "palette_prism",
	color = Color3.fromRGB(130, 72, 255),
	colorHex = "8248FF",
	dominantMaterialId = "material_smooth",
	dominantAuraId = "aura_spark",
	dominantPoseId = "pose_hero",
	dominantAccentId = "accent_orbit",
	diversity = 0.8,
	synergy = 0.9,
}
local brief =
	BriefCatalog.Compose("velvet_archive", "rescue_rehearsal", "soft_gothic", "zero_gravity")
assert(brief ~= nil, "semantic smoke brief is missing")
RunDirectorService.Init({})
RunDirectorService.ResetHistory()
local mechanicCatalog = RunDirectorService.GetMechanicCatalog()
assert(#mechanicCatalog >= 12, "authoritative mechanic catalog is below P0 target")
local mechanicIds: { [string]: boolean } = {}
local mechanicVerbs: { [string]: boolean } = {}
for _, mechanic in mechanicCatalog do
	assert(mechanic.implemented == true, "catalog exposes a paper-only mechanic")
	assert(not mechanicIds[mechanic.id], "duplicate mechanic id")
	assert(not mechanicVerbs[mechanic.verb], "mechanics must expose distinct gameplay verbs")
	mechanicIds[mechanic.id] = true
	mechanicVerbs[mechanic.verb] = true
end
local first = RunDirectorService.Generate(91373, 4, brief, fakeTeamGenome)
RunDirectorService.ResetHistory()
local replay = RunDirectorService.Generate(91373, 4, brief, fakeTeamGenome)
assert(first.signature == replay.signature, "seeded run is not deterministic")
assert(#first.acts == 3 and #first.routeOptions == 2, "run contract is incomplete")
assert(first.version >= 3, "semantic run contract was not activated")
assert(first.briefTreatment.occasionId == "rescue_rehearsal", "occasion treatment was lost")
assert(first.briefTreatment.aestheticId == "soft_gothic", "aesthetic treatment was lost")
assert(first.briefTreatment.twistId == "zero_gravity", "twist treatment was lost")
assert(first.acts[1].visualProfile == "velvet_silhouette", "aesthetic did not direct the act")
for _, act in first.acts do
	assert(type(act.mechanicProfile) == "table", "act mechanic profile is missing")
	assert(#act.mechanicIds >= 2, "brief tags were not consumed into gameplay mechanics")
	assert(act.mechanicProfile.sharedStabilization == true, "occasion mechanic was cosmetic")
	assert(act.mechanicProfile.inertiaFlow == true, "twist mechanic was cosmetic")
end
assert(
	string.find(first.acts[1].briefVariantId, "zero_gravity", 1, true) ~= nil,
	"twist did not create an act variant"
)
local routed = RunDirectorService.ApplyRoute(first, first.routeOptions[2].id, fakeTeamGenome)
assert(routed.selectedRouteId == first.routeOptions[2].id, "route vote was not applied")
assert(#routed.acts == 3, "route vote did not recompose the three acts")
assert(
	routed.briefTreatment.id == first.briefTreatment.id,
	"route vote discarded the semantic brief"
)

local axisVariants = {
	BriefCatalog.Compose("velvet_archive", "midnight_festival", "soft_gothic", "zero_gravity"),
	BriefCatalog.Compose("velvet_archive", "rescue_rehearsal", "retro_future", "zero_gravity"),
	BriefCatalog.Compose("velvet_archive", "rescue_rehearsal", "soft_gothic", "color_eclipse"),
}
for _, axisBrief in axisVariants do
	assert(axisBrief ~= nil, "axis variant brief is missing")
	RunDirectorService.ResetHistory()
	local axisPlan = RunDirectorService.Generate(91373, 4, axisBrief, fakeTeamGenome)
	assert(axisPlan.signature ~= first.signature, "a semantic axis did not change the signature")
	assert(
		axisPlan.acts[1].briefVariantId ~= first.acts[1].briefVariantId,
		"a semantic axis did not change act composition"
	)
end

local compositionSpace = RunDirectorService.GetCompositionSpace(BriefCatalog.CombinationCount)
assert(compositionSpace.semanticBriefs == 192, "unexpected semantic brief count")
assert(compositionSpace.routes == 3, "unexpected route dimension")
assert(compositionSpace.actLayouts == 8, "unexpected act-layout dimension")
assert(compositionSpace.modifiers == 4, "unexpected modifier dimension")
assert(compositionSpace.mechanics >= 12, "mechanic dimension is below P0 target")
assert(
	compositionSpace.distinctSignatures >= Config.RunDirector.MinimumDistinctCombinations,
	"Run Director signature space is below the configured minimum"
)

-- Exercise enough authored briefs and deterministic seeds to prove that the
-- semantic dimensions produce more than a paper-only estimate.
local empiricalSignatures: { [string]: boolean } = {}
local empiricalCount = 0
for briefIndex, semanticBrief in BriefCatalog.All do
	RunDirectorService.ResetHistory()
	for seedVariant = 1, 8 do
		local plan = RunDirectorService.Generate(
			700001 + briefIndex * 4099 + seedVariant * 65537,
			4,
			semanticBrief,
			fakeTeamGenome
		)
		if not empiricalSignatures[plan.signature] then
			empiricalSignatures[plan.signature] = true
			empiricalCount += 1
		end
	end
end
assert(
	empiricalCount >= Config.RunDirector.MinimumDistinctCombinations,
	`empirical signature space is too small: {empiricalCount}`
)
print(
	`AURA_RUSH_SIGNATURE_SPACE theoretical={compositionSpace.distinctSignatures} empirical={empiricalCount}`
)

RunDirectorService.ResetHistory()
local signatures = {}
for index = 1, 5 do
	local plan = RunDirectorService.Generate(91373 + index, 4, brief, fakeTeamGenome)
	assert(not signatures[plan.signature], "anti-repeat returned a recent signature")
	signatures[plan.signature] = true
end

-- Exercise three server-authoritative variants together: shared repair,
-- alternating relay contributors, and eclipse input decoding.
local prismSetups: { [any]: any } = {}
local challengeRemote = {
	BindEvent = function(_name: string, _rate: number, _handler: (any, any) -> ()) end,
	FireClient = function(name: string, player: any, payload: any)
		if name == "ProgressUpdate" and payload.kind == "PrismSetup" then
			prismSetups[player] = payload
		end
	end,
}
ChallengeService.Init({
	Config = Config,
	Services = { Remote = challengeRemote, World = {} },
})
local repairPlayers = {
	{ UserId = 801, Character = nil },
	{ UserId = 802, Character = nil },
} :: any
ChallengeService.Begin("PrismPuzzle", "mechanics-smoke", repairPlayers, 44771, {
	id = "bloom_rescue",
	index = 3,
	seed = 44771,
	semantic = "restore_sequence",
	mechanicTags = { "friend_chain", "eclipse_palette" },
})
local firstSetup = prismSetups[repairPlayers[1]]
local secondSetup = prismSetups[repairPlayers[2]]
assert(firstSetup.shared == true, "bloom repair did not become a shared server sequence")
assert(firstSetup.inputTransform == "complement", "eclipse decode contract is missing")
assert(
	table.concat(firstSetup.sequence, ",") == table.concat(secondSetup.sequence, ","),
	"shared repair generated divergent player sequences"
)
for index, prismIndex in firstSetup.sequence do
	ChallengeService.SubmitPrism(repairPlayers[((index - 1) % 2) + 1], {
		index = prismIndex,
	})
end
local firstRepairProgress = ChallengeService.GetProgress(repairPlayers[1])
local secondRepairProgress = ChallengeService.GetProgress(repairPlayers[2])
assert(
	firstRepairProgress and firstRepairProgress.prismComplete,
	"shared repair did not complete for first contributor"
)
assert(
	secondRepairProgress and secondRepairProgress.prismComplete,
	"shared repair did not synchronize to the team"
)
assert(
	(firstRepairProgress.mechanicAssists + secondRepairProgress.mechanicAssists) > 0,
	"friend relay did not reward alternating contributors"
)
local repairResult = ChallengeService.Finish()
assert(
	repairResult[repairPlayers[1]].mechanicSteps + repairResult[repairPlayers[2]].mechanicSteps
		== #firstSetup.sequence,
	"authoritative mechanic contributions were not retained"
)

AuraGenomeService.Init({ StyleCatalog = StyleCatalog })
local recipe =
	AuraGenomeService.BuildBloomRecipe("smoke-round", 91373, brief, fakeTeamGenome, first)
assert(#recipe.bloomActs == 3, "World Bloom must expose Seed/Cascade/Bloom")
WorldService.BeginWorldBloom(recipe, 3)
assert(world:GetAttribute("BloomAct") == "seed", "World Bloom did not enter Seed")

print("AURA_RUSH_GAMEPLAY_DIRECTOR_" .. "SMOKE_PASS")
