--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local shared = ReplicatedStorage:WaitForChild("AuraRushShared")
local services = ServerScriptService:WaitForChild("AuraRushServer"):WaitForChild("Services")
local client = StarterPlayer.StarterPlayerScripts:WaitForChild("AuraRushClient")

local Config = require(shared:WaitForChild("Config"))
local Remotes = require(shared:WaitForChild("Remotes"))
local BriefCatalog = require(shared:WaitForChild("BriefCatalog"))
local StyleCatalog = require(shared:WaitForChild("StyleCatalog"))
local RemixCatalog = require(shared:WaitForChild("RemixCatalog"))
local StyleChemistry = require(shared:WaitForChild("StyleChemistry"))
local ArtDirectionRegistry = require(shared:WaitForChild("ArtDirectionRegistry"))
local RunDirectorService = require(services:WaitForChild("RunDirectorService"))
local WorldService = require(services:WaitForChild("WorldService"))
local RemixCityService = require(services:WaitForChild("RemixCityService"))
local ProductionAssetService = require(services:WaitForChild("ProductionAssetService"))
local ProductionAssetManifest = require(shared:WaitForChild("ProductionAssetManifest"))

assert(Config.ClientVersion >= 5, "v5 compatibility contract is not active")
assert(Config.SchemaVersion == 5, "v5 profile schema is not active")
assert(Config.UI.DefaultLocale == "ru", "Russian is not the primary language")
assert(#Remotes.All == 35 and Remotes.Version == 2, "v2 remote contract is incomplete")
for _, flag in { "RemixCity", "StyleChemistry", "GuardianFinales", "ReplayGhosts", "SeasonOne" } do
	assert(Config.FeatureFlags[flag] == true, flag .. " feature flag is disabled")
end

assert(RemixCatalog.Version >= 5, "Remix catalog compatibility changed")
assert(#RemixCatalog.Roles == 4, "four cooperative roles are required")
assert(#RemixCatalog.Guardians == 6, "every district needs a Guardian")
assert(#RemixCatalog.EncounterCells == 18, "18 authored encounter cells are missing")
assert(#RemixCatalog.SeasonNodes == 40, "season one must contain 40 nodes")
local cellIds = {}
for _, cell in RemixCatalog.EncounterCells do
	assert(not cellIds[cell.id], "duplicate encounter cell id")
	cellIds[cell.id] = true
end
for _, node in RemixCatalog.SeasonNodes do
	local reward = node.freeReward
	if reward.kind == "style_item" then
		assert(
			StyleCatalog.GetById(reward.itemId) ~= nil,
			"season references an unknown style item"
		)
	end
end

assert(#StyleChemistry.GetRecipes() == 20, "20 Style Chemistry reactions are required")
local genome = {
	primaryPaletteId = "palette_prism",
	dominantMaterialId = "material_smooth",
	dominantAuraId = "aura_spark",
	dominantPoseId = "pose_hero",
	dominantAccentId = "accent_orbit",
	fingerprint = "remix-v5-smoke",
}
local chemistry = StyleChemistry.ResolveGenome(StyleCatalog, genome)
assert(#chemistry.recipes == 3, "Style Chemistry must return a readable top three")
assert(
	chemistry.signature == StyleChemistry.ResolveGenome(StyleCatalog, genome).signature,
	"Style Chemistry is not deterministic"
)
assert(type(chemistry.primary.nameRu) == "string", "Russian chemistry name is missing")

-- A single default outfit did not catch the old non-transitive tie comparator.
-- Exercise empty, First Miracle and mixed-category loadouts before a live round.
local chemistryRandom = Random.new(60603)
local chemistryAxes = { "palette", "material", "aura", "pose", "accent" }
for sample = 1, 512 do
	local loadout = if sample == 1 then {} else StyleCatalog.GetDefaultLoadout()
	if sample == 2 then
		loadout.aura = "aura_first_miracle"
	elseif sample > 2 then
		for _, axis in chemistryAxes do
			local choices = StyleCatalog.GetByCategory(axis)
			loadout[axis] = choices[chemistryRandom:NextInteger(1, #choices)].id
		end
	end
	local result = StyleChemistry.Resolve(StyleCatalog, loadout)
	assert(#result.recipes == 3, `chemistry top three missing for sample {sample}`)
	assert(
		result.signature == StyleChemistry.Resolve(StyleCatalog, loadout).signature,
		`chemistry order changed for sample {sample}`
	)
	local seen = {}
	local previousMatches = math.huge
	for _, recipe in result.recipes do
		assert(not seen[recipe.id], "chemistry returned a duplicate reaction")
		assert(recipe.matches <= previousMatches, "chemistry order is not descending by matches")
		seen[recipe.id] = true
		previousMatches = recipe.matches
	end
end
print("AURA_RUSH_CHEMISTRY_REGRESSION samples=512")

RunDirectorService.Init({ RemixCatalog = RemixCatalog })
RunDirectorService.ResetHistory()
local brief =
	BriefCatalog.Compose("prism_metro", "friendship_parade", "bioluminescent", "color_eclipse")
assert(brief ~= nil, "v5 smoke brief is missing")
local plan = RunDirectorService.Generate(5082501, 4, brief, genome)
assert(plan.version >= 5 and plan.seamless == true, "seamless v5 run contract is missing")
assert(#plan.acts == 3 and type(plan.guardian) == "table", "run finale contract is incomplete")
local requiredCellTags = { "signal_gate", "duet_lock", "palette_shift" }
for index, act in plan.acts do
	assert(type(act.cellId) == "string" and cellIds[act.cellId], "act lacks authored cell")
	assert(table.find(act.mechanicTags, requiredCellTags[index]), "cell mechanic is inactive")
	assert(table.find(act.mechanicIds, "role_spotlight"), "role gameplay is cosmetic-only")
end
assert(table.find(plan.acts[2].mechanicIds, "tempo_charge"), "tempo charge is missing")
assert(#RunDirectorService.GetMechanicCatalog() == 18, "exactly 18 mechanics are required")
local composition = RunDirectorService.GetCompositionSpace(BriefCatalog.CombinationCount)
assert(composition.distinctSignatures == 18432, "composition-space contract changed")
assert(composition.encounterCells == 18 and composition.seasonNodes == 40, "v5 dimensions missing")

WorldService.Init({ ArtDirectionRegistry = ArtDirectionRegistry, RemixCatalog = RemixCatalog })
local world = WorldService.Build()
assert(world:GetAttribute("PresentationVersion") == "remix_city_v6_ru", "v6 world is missing")
assert(world:GetAttribute("GuardianCount") == 6, "Guardian metadata is incomplete")
assert(world:GetAttribute("EncounterCellCount") == 18, "encounter metadata is incomplete")
for _, guardian in RemixCatalog.Guardians do
	local anchor = WorldService.GetGuardianAnchor(guardian.worldId)
	assert(anchor and anchor:GetAttribute("GuardianAnchor") == true, "physical Guardian missing")
end

WorldService.ApplyRunPlan(plan)
local active = world:FindFirstChild("ActiveRunGeometry")
assert(active and active:IsA("Model"), "continuous route was not built")
assert(active:GetAttribute("Seamless") == true, "route is still segmented")
for index = 1, 3 do
	local chunk = active:FindFirstChild(`RouteChunk_{index}`)
	assert(chunk and chunk:GetAttribute("CellId") ~= nil, "active cell chunk is missing")
	local arrival = chunk:GetAttribute("ArrivalPosition")
	local direction = chunk:GetAttribute("ArrivalDirection")
	local floor = chunk:FindFirstChild("RouteFloor")
	assert(
		typeof(arrival) == "Vector3" and typeof(direction) == "Vector3",
		"route arrival framing is missing"
	)
	assert(floor and floor:IsA("BasePart"), "route floor is missing")
	assert(
		(floor.Position - arrival):Dot(direction) > 30,
		"arrival camera looks away from the playable route"
	)
end
assert(active:FindFirstChild("Signal_1", true), "Signal Gate inputs are missing")
assert(active:FindFirstChild("DuetPad_1_-1", true), "Duet platform is missing")
assert(active:FindFirstChild("PalettePylon_1", true), "Palette Shift pylons are missing")
assert(active:FindFirstChild("SafetyRail_-1", true), "route safety rail is missing")
assert(active:FindFirstChild("RouteFacade_1_1", true), "route skyline dressing is missing")
assert(active:FindFirstChild("RouteExitCrown", true), "route milestone is missing")
assert(#WorldService.GetAllCollectibles() == 24, "dynamic signal pool is incomplete")

local ui = client:WaitForChild("UI")
local controllers = client:WaitForChild("Controllers")
local RemixOverlay = require(ui:WaitForChild("RemixOverlay"))
require(controllers:WaitForChild("RemixController"))
local host = Instance.new("Folder") :: any
local overlay = RemixOverlay.new(host)
overlay:SetReducedMotion(true)
overlay:Apply({
	enabled = true,
	roundId = "ui-smoke",
	phase = "Finale",
	roleId = "rhythmer",
	role = RemixCatalog.GetRole("rhythmer"),
	chemistry = chemistry,
	storyboard = { { kind = "beat" }, { kind = "guardian" } },
	guardian = {
		nameRu = "Дирижёр шума",
		verbRu = "Поймайте волну",
		progress = 12,
		target = 24,
		requiredRoleId = "rhythmer",
		accentHex = "38E8FF",
	},
})
assert(overlay.ScreenGui.Enabled, "Remix HUD did not become visible")
assert(overlay.GuardianCard.Visible, "Guardian HUD is missing")
assert(overlay.RoleButtons.rhythmer.Text == "БИТ", "role labels are not Russian-first")
assert(overlay.GuardianButton.Size.Y.Offset >= 44, "tap target is too small")
overlay:Apply({
	enabled = true,
	roundId = "ui-smoke",
	phase = "Results",
})
assert(not overlay.ScreenGui.Enabled, "duplicate Remix results panel overlaps the main results UI")
overlay:Destroy()
host:Destroy()

ProductionAssetService.Init({ ProductionAssetManifest = ProductionAssetManifest })
ProductionAssetService.Preload(world)
assert(world:GetAttribute("AssetManifestVersion") == 1, "asset bridge metadata is missing")
assert(world:GetAttribute("ProceduralFallbackActive") == true, "empty asset slots lost fallback")

local actionHandlers = {}
local lastReplayUpdate: any = nil
local fakePlayer = { UserId = 99101, Parent = game:GetService("Players"), Character = nil } :: any
local fakeProfile = {
	remixCity = {
		preferredRole = "rhythmer",
		replayConsent = false,
		savedReplays = {},
		stats = {
			momentsCaptured = 0,
			guardiansCompleted = 0,
			encoresRequested = 0,
			remixesSaved = 0,
			cityContribution = 0,
		},
		season = { id = "remix_city_s1", xp = 1000, claimedFree = {}, claimedPremium = {} },
	},
	unlocks = StyleCatalog.GetStarterUnlocks(),
	glowDust = 0,
	economyStats = { earned = 0, spent = 0 },
}
local fakeData = {
	GetProfile = function(_player: any): any
		return fakeProfile
	end,
	GetClientView = function(_player: any): any
		return fakeProfile
	end,
	IsLoaded = function(_player: any): boolean
		return true
	end,
	IsReadOnly = function(_player: any): boolean
		return false
	end,
	Update = function(_player: any, mutator: (any) -> ()): boolean
		mutator(fakeProfile)
		return true
	end,
}
local fakeServices: any = {
	Data = fakeData,
	Flags = {
		IsEnabled = function(_key: string): boolean
			return true
		end,
	},
	Remote = {
		BindEvent = function(name: string, _rate: number, handler: (any, any) -> ())
			actionHandlers[name] = handler
		end,
		FireClient = function(name: string, _player: any, payload: any)
			if name == "RemixUpdate" and payload.kind == "ReplayPlayback" then
				lastReplayUpdate = payload
			end
		end,
	},
	World = {},
	Analytics = { Log = function(_player: any, _event: string, _value: number, _detail: any) end },
}
fakeServices.Economy = {
	GrantCurrency = function(
		_player: any,
		_kind: string,
		_id: string,
		amount: number,
		mutator: (any) -> ()
	): any
		fakeProfile.glowDust += amount
		fakeProfile.economyStats.earned += amount
		mutator(fakeProfile)
		return { ok = true }
	end,
}
RemixCityService.Init({
	Config = Config,
	Services = fakeServices,
	StyleCatalog = StyleCatalog,
	RemixCatalog = RemixCatalog,
	StyleChemistry = StyleChemistry,
})
RemixCityService.BeginRound("v5-service-smoke", { fakePlayer }, plan, genome)
RemixCityService.RecordChallengeAction(
	fakePlayer,
	"BeatHit",
	"perfect",
	plan.acts[2].id,
	"duet_lock",
	8
)
RemixCityService.CompleteRound("prism_metro", plan.selectedRouteId)
RemixCityService.SetPhase("Results")
actionHandlers.RemixAction(fakePlayer, { action = "save_remix" })
assert(#fakeProfile.remixCity.savedReplays == 1, "server did not persist the authored replay")
assert(#fakeProfile.remixCity.savedReplays[1].events > 0, "saved replay has no storyboard")
actionHandlers.RemixAction(fakePlayer, {
	action = "claim_season",
	nodeId = RemixCatalog.SeasonNodes[1].id,
})
assert(
	fakeProfile.remixCity.season.claimedFree[RemixCatalog.SeasonNodes[1].id] == true,
	"free season node was not claimed authoritatively"
)
local replayId = fakeProfile.remixCity.savedReplays[1].id
RemixCityService.Reset()
actionHandlers.RemixAction(fakePlayer, { action = "play_saved", replayId = replayId })
assert(lastReplayUpdate ~= nil, "saved replay did not return through the safe playback contract")

print("AURA_RUSH_REMIX_CITY_" .. "V5_PASS")
