--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("AuraRushShared")
local server = ServerScriptService:WaitForChild("AuraRushServer")
local services = server:WaitForChild("Services")
local client = StarterPlayer.StarterPlayerScripts:WaitForChild("AuraRushClient")

local Config = require(shared:WaitForChild("Config"))
local PremiumCityCatalog = require(shared:WaitForChild("PremiumCityCatalog"))
local RemixCatalog = require(shared:WaitForChild("RemixCatalog"))
local ArtDirectionRegistry = require(shared:WaitForChild("ArtDirectionRegistry"))
local ProductionAssetManifest = require(shared:WaitForChild("ProductionAssetManifest"))
local WorldService = require(services:WaitForChild("WorldService"))
local CityPulseService = require(services:WaitForChild("CityPulseService"))
local RemixOverlay = require(client.UI:WaitForChild("RemixOverlay"))

local function hasCyrillic(value: string): boolean
	for _, codepoint in utf8.codes(value) do
		if
			(codepoint >= 0x0410 and codepoint <= 0x044F)
			or codepoint == 0x0401
			or codepoint == 0x0451
		then
			return true
		end
	end
	return false
end

local function assertAuthoredRussian(value: any, label: string): ()
	assert(type(value) == "string" and value ~= "", `{label} is missing`)
	assert(hasCyrillic(value), `{label} has no Russian copy`)
	local lowered = string.lower(value)
	for _, forbidden in { "lorem", "todo", "chatgpt", "generated", "нейросет" } do
		assert(not string.find(lowered, forbidden, 1, true), `{label} contains placeholder copy`)
	end
end

assert(Config.ClientVersion == 6, "v6 client contract is not active")
assert(Config.SchemaVersion == 5, "presentation upgrade must not break stored profiles")
assert(Config.FeatureFlags.CityPulse == true, "City Pulse is disabled")
assert(Workspace.StreamingEnabled, "instance streaming is disabled in the built place")
local function assertOptionalWorkspaceEnum(propertyName: string, expectedItemName: string): ()
	local ok, value = pcall(function()
		return (Workspace :: any)[propertyName]
	end)
	if not ok then
		print(`AURA_RUSH_CAPABILITY_FALLBACK {propertyName}`)
		return
	end
	assert(
		typeof(value) == "EnumItem" and value.Name == expectedItemName,
		`advanced Workspace property is stale: {propertyName}`
	)
end
assertOptionalWorkspaceEnum("PredictiveStreamingMode", "Enabled")
assertOptionalWorkspaceEnum("StreamOutBehavior", "Opportunistic")
assertOptionalWorkspaceEnum("StreamingIntegrityMode", "PauseOutsideLoadedArea")
assertOptionalWorkspaceEnum("EnableSLIMAvatars", "Enabled")
assert(PremiumCityCatalog.Version == 7, "premium city v7 catalog is not active")
assert(RemixCatalog.Version == 6, "Remix City catalog did not advance to v6")
assert(#PremiumCityCatalog.Districts == 6, "six district gateways are required")
assert(#PremiumCityCatalog.PulsePads == 4, "four readable pulse roles are required")
assert(#PremiumCityCatalog.PulseEvents >= 6, "hub event rotation is too shallow")

local districtIds = {}
for _, definition in PremiumCityCatalog.Districts do
	assertAuthoredRussian(definition.nameRu, "Russian district name")
	assertAuthoredRussian(definition.hintRu, "district hint")
	assert(not districtIds[definition.id], "duplicate premium district id")
	districtIds[definition.id] = true
end
local padIds = {}
for index, definition in PremiumCityCatalog.PulsePads do
	assert(not padIds[definition.id], "duplicate pulse pad id")
	padIds[definition.id] = index
	assertAuthoredRussian(definition.nameRu, "pulse pad name")
	assertAuthoredRussian(definition.cueRu, "pulse pad cue")
end
for _, event in PremiumCityCatalog.PulseEvents do
	assertAuthoredRussian(event.nameRu, "Russian pulse event name")
	assertAuthoredRussian(event.cueRu, "Russian pulse event cue")
	assert(padIds[event.preferredPadId] ~= nil, "pulse event references an unknown preferred pad")
	assert((utf8.len(event.cueRu) or math.huge) <= 96, "pulse cue is too verbose for mobile HUD")
end

WorldService.Init({
	ArtDirectionRegistry = ArtDirectionRegistry,
	RemixCatalog = RemixCatalog,
	PremiumCityCatalog = PremiumCityCatalog,
})
local world = WorldService.Build()
assert(world:GetAttribute("PresentationVersion") == "remix_city_v6_ru", "v6 world is missing")
assert(world:GetAttribute("PremiumCityVersion") == 7, "premium city metadata is missing")
assert(
	world:GetAttribute("VisualQualityPass") == "premium_city_ring_v8",
	"premium visual pass is stale"
)

local hub = world:FindFirstChild("Hub")
assert(hub and hub:IsA("Model"), "premium hub is missing")
assert(hub:GetAttribute("ArtPassVersion") == 8, "hub art pass is stale")
assert(
	hub:GetAttribute("SpatialHierarchy") == "arrival_heart_districts",
	"map hierarchy is unclear"
)
assert(hub:GetAttribute("IdleGameplay") == "city_pulse", "hub still has no gameplay")
local premium = hub:FindFirstChild("PremiumCityLayer")
assert(premium and premium:IsA("Model"), "premium city layer is missing")
assert(premium:GetAttribute("DistrictGatewayCount") == 6, "district ring is incomplete")
assert(premium:GetAttribute("PulsePadCount") == 4, "pulse plaza is incomplete")
assert(premium:GetAttribute("RailSegmentCount") == 72, "Prism Rail silhouette is incomplete")
assert(premium:FindFirstChild("HeartOfStyle"), "Heart of Style landmark is missing")

local heartRibbons = 0
local gateways = 0
local transitSegments = 0
local photoSpots = 0
local compactLabels = 0
local pulsePadLabels = 0
local districtPrompts = 0
local photoPrompts = 0
for _, descendant in hub:GetDescendants() do
	if descendant:IsA("BasePart") and descendant:GetAttribute("CityPulseVisual") == true then
		heartRibbons += 1
	end
	if descendant:IsA("Model") and descendant:GetAttribute("DistrictGateway") == true then
		gateways += 1
	end
	if descendant:IsA("BasePart") and descendant:GetAttribute("TransitRing") == true then
		transitSegments += 1
	end
	if descendant:IsA("BasePart") and descendant:GetAttribute("PhotoSpot") == true then
		photoSpots += 1
	end
	if descendant:IsA("BillboardGui") and descendant.Name == "DistrictLabel" then
		compactLabels += 1
		assert(descendant.Size.X.Offset <= 258, "district sign blocks too much of the view")
		assert(descendant.MaxDistance <= 52, "distant district signs crowd the arrival view")
	end
	if descendant:IsA("BillboardGui") and descendant.Name == "PulsePadLabel" then
		pulsePadLabels += 1
		assert(descendant.MaxDistance <= 34, "distant pad labels cover the hero landmark")
		local title = descendant:FindFirstChild("Title", true)
		assert(
			title and title:IsA("TextLabel") and hasCyrillic(title.Text),
			"pulse pad label is unreadable"
		)
	end
	if
		descendant:IsA("ProximityPrompt")
		and descendant:GetAttribute("AuraRushDistrictPreview") == true
	then
		districtPrompts += 1
		assertAuthoredRussian(descendant.ActionText, "district prompt action")
		assertAuthoredRussian(descendant.ObjectText, "district prompt object")
	end
	if
		descendant:IsA("ProximityPrompt")
		and descendant:GetAttribute("AuraRushPhotoSpot") == true
	then
		photoPrompts += 1
		assertAuthoredRussian(descendant.ActionText, "photo prompt action")
		assertAuthoredRussian(descendant.ObjectText, "photo prompt object")
	end
end
assert(heartRibbons == 60, "six smooth ten-segment Heart ribbons are incomplete")
assert(gateways == 6, "six physical district gateways are required")
assert(transitSegments == 72, "the elevated rail ring has gaps")
assert(photoSpots == 2, "social photo stages are missing")
assert(compactLabels == 6, "Russian district navigation is incomplete")
assert(pulsePadLabels == 4, "visible Russian pulse pad labels are incomplete")
assert(districtPrompts == 6, "district previews are decorative-only")
assert(photoPrompts == 2, "photo stages are decorative-only")

local function belongsToPlazaFacade(instance: Instance): boolean
	local cursor: Instance? = instance
	while cursor and cursor ~= hub do
		if cursor:IsA("Model") and string.sub(cursor.Name, 1, 12) == "PlazaFacade" then
			return true
		end
		cursor = cursor.Parent
	end
	return false
end

for _, gateway in premium:GetChildren() do
	if gateway:IsA("Model") and gateway:GetAttribute("DistrictGateway") == true then
		for _, gatewayPart in gateway:GetDescendants() do
			if gatewayPart:IsA("BasePart") then
				for _, overlap in Workspace:GetPartsInPart(gatewayPart) do
					assert(
						not belongsToPlazaFacade(overlap),
						`district gateway clips {overlap:GetFullName()}`
					)
				end
			end
		end
	end
end
for _, railPart in premium:GetDescendants() do
	if railPart:IsA("BasePart") and railPart:GetAttribute("TransitRing") == true then
		for _, overlap in Workspace:GetPartsInPart(railPart) do
			assert(not belongsToPlazaFacade(overlap), `elevated rail clips {overlap:GetFullName()}`)
		end
	end
end

local pads = WorldService.GetCityPulsePads()
assert(#pads == 4, "WorldService did not expose four pulse pads")
for _, pad in pads do
	assert(pad.CanTouch, "pulse pad cannot detect players")
	assert(type(pad:GetAttribute("PulsePadId")) == "string", "pulse pad id missing")
	assert(type(pad:GetAttribute("PulsePadIndex")) == "number", "pulse pad number missing")
	assert(type(pad:GetAttribute("ColorIndependentCue")) == "string", "accessible pad cue missing")
end

local completionToken = world:GetAttribute("CityPulseCompletionToken") :: number
WorldService.SetCityPulse(0.5, "smoke_event", "38E8FF", false, "flow")
assert(world:GetAttribute("CityPulseProgress") == 0.5, "world pulse did not update")
assert(world:GetAttribute("CityPulseEventId") == "smoke_event", "pulse event metadata missing")
WorldService.SetCityPulse(1, "smoke_event", "38E8FF", true, "flow")
assert(
	world:GetAttribute("CityPulseCompletionToken") == completionToken + 1,
	"pulse completion token did not advance"
)
WorldService.SetCityPulse(1, "smoke_event", "38E8FF", true, "flow")
assert(
	world:GetAttribute("CityPulseCompletionToken") == completionToken + 1,
	"pulse completion is not idempotent"
)
WorldService.SetCityPulse(0.5, "smoke_event", "38E8FF", false, "flow")
local pulseVisual = premium:FindFirstChild("HeartRibbon_1_1", true)
assert(pulseVisual and pulseVisual:IsA("BasePart"), "pulse visual missing before reset")
local pulseColorBeforeReset = pulseVisual.Color
WorldService.ResetRound("premium-reset-smoke")
assert(pulseVisual.Color == pulseColorBeforeReset, "round reset erased active City Pulse visuals")

local hubParts = 0
local worldParts = 0
local lights = 0
local transparentParts = 0
local hubTransparentParts = 0
local transparentByZone: { [string]: number } = {}
for _, descendant in world:GetDescendants() do
	if descendant:IsA("BasePart") then
		worldParts += 1
		if descendant:IsDescendantOf(hub) then
			hubParts += 1
		end
		-- Fully invisible anchors and trigger volumes are not layered alpha
		-- surfaces. Budget only partially transparent geometry that can create
		-- visible overdraw on low-end devices.
		if descendant.Transparency > 0 and descendant.Transparency < 1 then
			transparentParts += 1
			if descendant:IsDescendantOf(hub) then
				hubTransparentParts += 1
			end
			local zone: Instance = descendant
			while zone.Parent and zone.Parent ~= world do
				zone = zone.Parent
			end
			transparentByZone[zone.Name] = (transparentByZone[zone.Name] or 0) + 1
		end
	elseif descendant:IsA("Light") then
		lights += 1
		assert(descendant.Shadows == false, "mass world light has expensive shadows enabled")
	end
end
local zoneCounts = {}
for zoneName, count in transparentByZone do
	table.insert(zoneCounts, `{zoneName}={count}`)
end
table.sort(zoneCounts)
print(`AURA_RUSH_PREMIUM_TRANSPARENCY {table.concat(zoneCounts, " ")}`)
local budget = PremiumCityCatalog.PerformanceBudget
assert(hubParts <= budget.hubBaseParts, `hub part budget exceeded: {hubParts}`)
assert(worldParts <= budget.worldBaseParts, `world part budget exceeded: {worldParts}`)
assert(lights <= budget.pointLights, `point-light budget exceeded: {lights}`)
assert(
	hubTransparentParts <= budget.hubTransparentParts,
	`hub transparency budget exceeded: {hubTransparentParts}`
)
for zoneName, count in transparentByZone do
	if zoneName ~= "Hub" then
		assert(
			count <= budget.districtTransparentParts,
			`zone transparency budget exceeded: {zoneName}={count}`
		)
	end
end
assert(
	transparentParts <= budget.transparentParts,
	`transparency budget exceeded: {transparentParts}`
)

local fakeRemotePayload: any = nil
local fakeWorldState: any = nil
local fakeFlagEnabled = true
local fakeFlagChanged: any = nil
CityPulseService.Init({
	Config = Config,
	PremiumCityCatalog = PremiumCityCatalog,
	Services = {
		Flags = {
			IsEnabled = function(_key: string): boolean
				return fakeFlagEnabled
			end,
			OnChanged = function(callback: any)
				fakeFlagChanged = callback
				return function()
					fakeFlagChanged = nil
				end
			end,
		},
		World = {
			GetCityPulsePads = function(): { BasePart }
				return {}
			end,
			SetCityPulse = function(...: any)
				fakeWorldState = { ... }
			end,
		},
		Remote = {
			FireAll = function(_name: string, payload: any)
				fakeRemotePayload = payload
			end,
		},
		Analytics = {
			Log = function(_player: any, _name: string, _value: number, _fields: any) end,
		},
	},
})
local pulseSnapshot = CityPulseService.GetSnapshot(nil)
assert(pulseSnapshot.enabled == true, "City Pulse service did not start")
assert(pulseSnapshot.target >= 10, "City Pulse target is invalid")
assert(
	CityPulseService.GetMaximumUpdateRate()
		== PremiumCityCatalog.PerformanceBudget.maximumPulseUpdatesPerSecond,
	"City Pulse network cap is not bound to the performance budget"
)
assert(type(fakeWorldState) == "table", "City Pulse did not bind to the world")
assert(fakeRemotePayload.kind == "CityPulseStarted", "City Pulse did not publish its first state")
assert(CityPulseService.ResolveContribution("flow", "flow") == 2, "preferred pad bonus is wrong")
assert(
	CityPulseService.ResolveContribution("beat", "flow") == 1,
	"normal pad contribution is wrong"
)
fakeFlagEnabled = false
fakeFlagChanged("CityPulse", false)
task.wait(0.05)
assert(
	CityPulseService.GetSnapshot(nil).enabled == false,
	"hot kill switch did not stop City Pulse"
)
assert(
	fakeRemotePayload.kind == "CityPulseStopped" and fakeRemotePayload.data.enabled == false,
	"hot kill switch left a stale visible HUD"
)
assert(
	fakeWorldState[1] == 0 and fakeWorldState[2] == "",
	"hot kill switch left active world visuals"
)
fakeFlagEnabled = true
fakeFlagChanged("CityPulse", true)
task.wait(0.05)
assert(CityPulseService.GetSnapshot(nil).enabled == true, "City Pulse did not hot-restart")
CityPulseService.Stop()
assert(
	CityPulseService.GetSnapshot(nil).enabled == false,
	"stopped City Pulse still reports enabled"
)

local host = Instance.new("Folder") :: any
local overlay = RemixOverlay.new(host)
overlay:SetReducedMotion(true)
overlay:Apply({
	enabled = false,
	roundId = "",
	phase = "Waiting",
	cityPulse = {
		enabled = true,
		nameRu = "Неоновый разгон",
		cueRu = "Наступай на плиты вместе с другими.",
		accentHex = "38E8FF",
		progress = 6,
		target = 10,
		contributors = 3,
		preferredPadIndex = 1,
		preferredPadNameRu = "ПУТЬ",
	},
})
assert(overlay.ScreenGui.Enabled, "hub pulse HUD did not become visible")
assert(overlay.PulseCard.Visible and not overlay.Panel.Visible, "hub HUD hierarchy is wrong")
assert(
	string.find(overlay.PulseTitle.Text, "Неоновый разгон", 1, true),
	"pulse title is not Russian-first"
)
assert(math.abs(overlay.PulseFill.Size.X.Scale - 0.6) < 0.01, "pulse progress is incorrect")
assert(
	string.find(overlay.PulseCue.Text, "1 · ПУТЬ", 1, true),
	"preferred pulse pad is not explained"
)
assert(not overlay.ScreenGui.IgnoreGuiInset, "secondary HUD ignores the Roblox safe area")
overlay:SetSuppressed(true)
overlay:ApplyCityPulse(pulseSnapshot)
assert(not overlay.ScreenGui.Enabled, "incoming pulse restored a HUD over onboarding/modal")
overlay:SetSuppressed(false)
assert(overlay.ScreenGui.Enabled, "secondary HUD did not recover after modal closed")
overlay:Apply({
	enabled = true,
	roundId = "premium-smoke",
	phase = "ThreadRun",
	cityPulse = pulseSnapshot,
})
assert(
	overlay.Panel.Visible and not overlay.PulseCard.Visible,
	"pulse HUD overlaps active gameplay"
)
overlay:Destroy()
host:Destroy()

assert(
	ProductionAssetManifest.brand.mapConcept.localSource
		== "assets/brand/remix-city-premium-map-concept-v3.png",
	"premium map reference is not registered"
)

print(`AURA_RUSH_PREMIUM_CITY_V6_PASS hubParts={hubParts} worldParts={worldParts} lights={lights}`)
