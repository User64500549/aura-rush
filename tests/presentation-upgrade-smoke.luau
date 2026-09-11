--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local shared = ReplicatedStorage:WaitForChild("AuraRushShared")
local server = ServerScriptService:WaitForChild("AuraRushServer")
local services = server:WaitForChild("Services")

local Config = require(shared:WaitForChild("Config"))
local ArtDirectionRegistry = require(shared:WaitForChild("ArtDirectionRegistry"))
local LiveOpsManifest = require(shared:WaitForChild("LiveOpsManifest"))
local RunDirectorService = require(services:WaitForChild("RunDirectorService"))
local WorldService = require(services:WaitForChild("WorldService"))

local client = StarterPlayer.StarterPlayerScripts:WaitForChild("AuraRushClient")
local ui = client:WaitForChild("UI")
local controllers = client:WaitForChild("Controllers")
local StyleOS = require(ui:WaitForChild("StyleOS"))
local Theme = require(ui:WaitForChild("Theme"))
local PresentationPolicy = require(ui:WaitForChild("PresentationPolicy"))
local App = require(ui:WaitForChild("App"))
local VisualItemTile = require(ui:WaitForChild("VisualItemTile"))
local VfxDirector = require(controllers:WaitForChild("VfxDirector"))
local FirstMiracleController = require(controllers:WaitForChild("FirstMiracleController"))

assert(StyleOS.Tokens.Control.MinimumHitTarget >= 48, "UI hit targets are too small")

local layoutCard = Instance.new("Frame")
local layout = Instance.new("UIListLayout")
layout.Parent = layoutCard
local accent = Theme.addAccentBand(layoutCard, Theme.Colors.Lime, 6)
assert(not accent:IsA("GuiObject"), "decorative accent occupies a UIListLayout slot")
local layoutTitle = Instance.new("TextLabel")
layoutTitle.Parent = layoutCard
local titleBorder = Theme.addStroke(layoutTitle)
assert(
	titleBorder.ApplyStrokeMode == Enum.ApplyStrokeMode.Border,
	"panel stroke outlines glyphs instead of its border"
)
local layoutChildren = 0
for _, child in layoutCard:GetChildren() do
	if child:IsA("GuiObject") then
		layoutChildren += 1
	end
end
assert(layoutChildren == 1, "card decoration pushes content outside its layout")
layoutCard:Destroy()
for _, phase in { "BriefChoice", "BeatLab", "PrismPuzzle", "MixLab", "Results" } do
	local policy = PresentationPolicy.Resolve(phase, false, false)
	assert(policy.suppressSecondaryHud, "secondary HUD obscures a primary activity: " .. phase)
	assert(not policy.routeRibbonVisible, "route ribbon covers the primary activity: " .. phase)
	assert(policy.readOnlyVisible, "persistence warning is hidden in the primary activity")
end
for _, phase in { "Hub", "ThreadRun", "Finale" } do
	assert(
		not PresentationPolicy.Resolve(phase, false, false).suppressSecondaryHud,
		"world activity lost its HUD"
	)
	assert(
		PresentationPolicy.Resolve(phase, true, false).suppressSecondaryHud,
		"modal priority is broken"
	)
	assert(
		PresentationPolicy.Resolve(phase, false, true).suppressSecondaryHud,
		"capture priority is broken"
	)
end

-- Exercise the real render/update methods without requiring a LocalPlayer in
-- RunScript. Missing choices must not leave a dash card or a dead gamepad stop.
local choiceHost = Instance.new("ScreenGui")
local choiceRefs: { [string]: any } = {}
for _, name in { "BriefHeader", "BriefSubtitle", "RouteRibbon", "ResultsRoute", "ReadOnlyBanner" } do
	local textLabel = Instance.new("TextLabel")
	textLabel.Parent = choiceHost
	choiceRefs[name] = textLabel
end
for index = 1, 3 do
	local card = Instance.new("Frame")
	card.Parent = choiceHost
	choiceRefs[`BriefCard{index}`] = card
	for _, prefix in { "BriefTitle", "BriefDetail" } do
		local textLabel = Instance.new("TextLabel")
		textLabel.Parent = card
		choiceRefs[`{prefix}{index}`] = textLabel
	end
	local choiceButton = Instance.new("TextButton")
	choiceButton.Parent = card
	choiceRefs[`BriefButton{index}`] = choiceButton
end
local overlayHost = Instance.new("Frame")
overlayHost.Parent = choiceHost
local topBarHost = Instance.new("Frame")
topBarHost.Parent = choiceHost
local screenHost = Instance.new("Frame")
screenHost.Parent = choiceHost
local renderFixture = setmetatable({
	Locale = "ru",
	Refs = choiceRefs,
	State = { ScreenName = "MixLab", Phase = "MixLab", ReadOnly = true },
	OverlayContainer = overlayHost,
	TopBar = topBarHost,
	ScreenContainer = screenHost,
	ScreenGui = choiceHost,
}, { __index = App }) :: any
renderFixture:SetRouteChoices({ { id = "classic_bloom" }, { id = "kinetic_cascade" } })
assert(
	choiceRefs.BriefCard1.Visible and choiceRefs.BriefCard2.Visible,
	"valid route choices are hidden"
)
assert(not choiceRefs.BriefCard3.Visible, "missing route leaves an empty card")
assert(
	choiceRefs.BriefButton2.NextSelectionRight == choiceRefs.BriefButton2,
	"gamepad navigation enters an absent choice"
)
renderFixture:SetRouteChoices({
	{ id = "classic_bloom" },
	{ id = "kinetic_cascade" },
	{ id = "precision_grid" },
})
assert(choiceRefs.BriefCard3.Visible, "choice card did not return in the next round")
renderFixture:ApplyRunUpdate({ routeId = "classic_bloom" })
assert(
	choiceHost:GetAttribute("SuppressSecondaryHud") == true,
	"late run snapshot restores a conflicting HUD"
)
assert(not choiceRefs.RouteRibbon.Visible, "late run snapshot overlaps the fitting-room controls")
assert(choiceRefs.ReadOnlyBanner.Visible, "read-only warning is lost after a snapshot")
choiceHost:Destroy()

local spatialPanel = Instance.new("Frame")
local spatialFixture: any = { Panel = spatialPanel }
spatialFixture.Overlay = Instance.new("TextButton")
spatialFixture.Overlay.Parent = spatialPanel
spatialFixture.PanelConstraint = Instance.new("UISizeConstraint")
spatialFixture.PanelConstraint.Parent = spatialPanel
for _, field in { "Title", "Intro", "Progress", "Reward" } do
	spatialFixture[field] = Instance.new("TextLabel")
	spatialFixture[field].Parent = spatialPanel
end
spatialFixture.ActionButton = Instance.new("TextButton")
spatialFixture.ActionButton.Parent = spatialPanel
spatialFixture.SkipButton = Instance.new("TextButton")
spatialFixture.SkipButton.AnchorPoint = Vector2.new(0.5, 1)
spatialFixture.SkipButton.Parent = spatialPanel
FirstMiracleController._setSpatialMode(spatialFixture, true)
local panelHeight = spatialPanel.Size.Y.Offset
local primaryBottom = spatialFixture.ActionButton.Position.Y.Scale * panelHeight
	+ spatialFixture.ActionButton.Position.Y.Offset
	+ spatialFixture.ActionButton.Size.Y.Offset
local skipTop = spatialFixture.SkipButton.Position.Y.Scale * panelHeight
	+ spatialFixture.SkipButton.Position.Y.Offset
	- spatialFixture.SkipButton.Size.Y.Offset
assert(skipTop - primaryBottom >= 10, "First Miracle skip target overlaps the primary action")
assert(spatialFixture.SkipButton.Size.Y.Offset >= 48, "First Miracle skip target is too small")
spatialPanel:Destroy()
assert(
	StyleOS.Tokens.Tile.Height > StyleOS.Tokens.Tile.PreviewHeight,
	"item tile hierarchy is invalid"
)

local tileHost = Instance.new("Frame")
local itemTile = VisualItemTile.create(tileHost, "ContractItem", 1)
VisualItemTile.render(itemTile, {
	id = "contract_item",
	label = "Лимонный свет",
	color = Color3.fromRGB(214, 255, 73),
	locked = false,
}, true, "palette", "ru")
assert(itemTile.Visible, "visual item tile did not render")
assert(itemTile:FindFirstChild("Preview") ~= nil, "visual item tile preview is missing")
assert(itemTile:FindFirstChild("DisplayName") ~= nil, "visual item tile label is missing")
assert(itemTile:GetAttribute("AccessibilityLabel") ~= nil, "item accessibility label is missing")

local query = StyleOS.attachQuery(tileHost, "ContractNarrow", {
	MaxSize = Vector2.new(520, math.huge),
})
assert(
	type(tileHost:GetAttribute("AuraRushStyleQuery_ContractNarrow")) == "boolean",
	"StyleQuery capability was not recorded"
)
if query then
	assert(query.Parent == tileHost, "supported StyleQuery was not attached")
end

local contractGui = Instance.new("ScreenGui")
local styleMount = StyleOS.mount(contractGui)
assert(type(styleMount.supported) == "boolean", "StyleSheet capability result is invalid")
assert(
	contractGui:GetAttribute("AuraRushStyleSheetSupported") == styleMount.supported,
	"StyleSheet capability attribute is out of sync"
)
contractGui:Destroy()
tileHost:Destroy()

assert(Config.UI.DefaultLocale == "ru", "Russian-first UI contract changed")
assert(ArtDirectionRegistry.Count == 6, "all six district art profiles are required")
assert(LiveOpsManifest.version >= 2, "weekly district manifest is missing")
local motionFeedback = VfxDirector.GetMotionFeedbackContract()
assert(motionFeedback.clientOnly == true, "movement feedback must stay client-local")
assert(motionFeedback.extraRemotes == 0, "movement feedback added a network remote")
assert(motionFeedback.pooled == true, "movement feedback must use the VFX pool")
assert(motionFeedback.entryPhase == "Loading", "movement feedback starts after onboarding")
assert(
	motionFeedback.stepDistance.High < motionFeedback.stepDistance.Balanced
		and motionFeedback.stepDistance.Balanced < motionFeedback.stepDistance.Low,
	"movement feedback quality scaling is invalid"
)
local event = LiveOpsManifest.events[1]
assert(type(event) == "table", "live event is missing")
assert(
	type(event.districtRotation) == "table" and #event.districtRotation == 6,
	"district rotation incomplete"
)
assert((tonumber(event.weeklyGoal) or 0) > 0, "weekly district goal is invalid")

WorldService.Init({ ArtDirectionRegistry = ArtDirectionRegistry })
local world = WorldService.Build()
assert((world:GetAttribute("HeroSliceVersion") :: number) >= 7, "hero slice upgrade is missing")
assert(
	world:GetAttribute("VisualQualityPass") == "premium_city_ring_v8",
	"visual quality pass metadata is missing"
)
assert(
	world:GetAttribute("MotionFeedbackContract") == "pooled_local_v1",
	"local movement feedback contract is missing"
)
local hub = world:FindFirstChild("Hub")
assert(hub and hub:IsA("Model"), "style plaza is missing")
assert(hub:GetAttribute("SpawnClearRadius") == 14, "hub spawn clearance is not authored")
local hubSpawn = WorldService.GetSpawn("Hub")
local signatureCore = hub:FindFirstChild("SignatureCore", true)
assert(signatureCore and signatureCore:IsA("BasePart"), "hub landmark core is missing")
assert(
	(hubSpawn.Position - signatureCore.Position).Magnitude > 35,
	"player still spawns inside the hub landmark"
)
assert(hubSpawn.LookVector.Z > 0.9, "hub spawn does not face the primary route")
local arrivalPad = hub:FindFirstChild("ArrivalPad", true)
assert(
	arrivalPad and arrivalPad:GetAttribute("SafeSpawnArea") == true,
	"hub arrival pad is missing"
)
local hubFacades = 0
for _, descendant in hub:GetDescendants() do
	if descendant:GetAttribute("ModularKit") == "StylePlazaFacade" then
		hubFacades += 1
	end
	if descendant:IsA("BillboardGui") and descendant.Name == "WorldLabel" then
		assert(descendant.Size.X.Offset <= 380, "world sign is too wide")
		assert(descendant.Size.Y.Offset <= 98, "world sign is too tall")
	end
end
assert(hubFacades == 6, "hub skyline kit is incomplete")

local metro = world:FindFirstChild("PrismMetro")
assert(metro and metro:IsA("Model"), "Prism Metro is missing")
assert(metro:GetAttribute("HeroDistrict") == true, "Prism Metro is not the hero district")
assert(metro:GetAttribute("ArtPassVersion") == 6, "Prism Metro art pass is stale")
assert(metro:GetAttribute("RouteClearWidth") == 28, "Prism Metro route clearance changed")
local metroFacades = 0
local metroLamps = 0
local reactiveTiles = 0
local routeBlockers = {}
local runway = metro:FindFirstChild("MetroRunway", true)
assert(runway and runway:IsA("BasePart"), "Metro runway is missing")
for _, descendant in metro:GetDescendants() do
	if descendant:GetAttribute("ModularKit") == "PrismTransitFacade" then
		metroFacades += 1
	elseif descendant:GetAttribute("SetDressing") == "TransitLamp" then
		metroLamps += 1
	end
	if descendant:GetAttribute("RouteBeat") ~= nil then
		assert(descendant:GetAttribute("ReactiveSignal") == true, "route beat is not reactive")
		reactiveTiles += 1
	end
	if
		descendant:IsA("BasePart")
		and descendant.CanCollide
		and descendant ~= runway
		and descendant.Name ~= "EditorialPlatform"
	then
		local delta = descendant.Position - runway.Position
		if math.abs(delta.X) < 14 and delta.Z > -55 and delta.Z < 47 and delta.Y > 2 then
			table.insert(routeBlockers, descendant:GetFullName())
		end
	end
end
assert(metroFacades == 10, "Prism Metro modular facade kit is incomplete")
assert(metroLamps == 10, "Prism Metro lighting cadence is incomplete")
assert(reactiveTiles == 12, "Prism Metro reactive route cadence is incomplete")
assert(#routeBlockers == 0, "Prism Metro route contains a camera/player blocker")
local metroSpawn = WorldService.GetSpawn("Finale", "prism_metro")
assert(metroSpawn.LookVector.Z > 0.9, "Prism Metro spawn faces away from the route")
for _, profile in ArtDirectionRegistry.Worlds do
	assert(
		world:FindFirstChild("FinaleCamera_" .. profile.id, true) ~= nil,
		"missing finale camera for " .. profile.id
	)
end

local forbiddenSignCopy = {
	"THREAD RUN",
	"BEAT LAB",
	"PRISM PUZZLE",
	"MIX LAB",
	"WORLD BLOOM",
	"TURN THE",
	"MAKE AN ENTIRE",
	"WRITE YOUR AURA",
}
for _, descendant in world:GetDescendants() do
	if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
		local text = string.upper(descendant.Text)
		for _, forbidden in forbiddenSignCopy do
			assert(not string.find(text, forbidden, 1, true), "English world sign leaked: " .. text)
		end
	end
end

local stages = {}
for _, instance in CollectionService:GetTagged("AuraRushBloomable") do
	local stage = instance:GetAttribute("BloomRevealStage")
	if type(stage) == "number" then
		stages[math.floor(stage)] = true
	end
end
assert(stages[1] and stages[2] and stages[3], "three-stage district recolor is incomplete")

RunDirectorService.ResetHistory()
local plan = RunDirectorService.Generate(90210, 4, {
	Id = "smoke_brief",
	WorldId = "prism_metro",
	OccasionId = "midnight_festival",
	AestheticId = "retro_future",
	TwistId = "color_eclipse",
}, {
	fingerprint = "smoke_genome",
})
assert(type(plan.selectedRouteTitle) == "string", "route title missing")
assert(plan.selectedRouteTitle ~= "Kinetic Cascade", "English route title leaked")
assert(type(plan.modifier.title) == "string", "modifier title missing")
for _, act in plan.acts do
	assert(type(act.title) == "string" and act.title ~= act.id, "authored act title missing")
	assert(type(act.modifierId) == "string", "physical modifier was not propagated")
	assert(
		type(act.laneTransform) == "string" or type(act.movementStyle) == "string",
		"modifier has no legible gameplay effect"
	)
end

print("AURA_RUSH_PRESENTATION_" .. "UPGRADE_PASS")
