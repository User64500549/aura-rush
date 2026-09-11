--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local shared = ReplicatedStorage:WaitForChild("AuraRushShared")
local server = ServerScriptService:WaitForChild("AuraRushServer")
local servicesRoot = server:WaitForChild("Services")
local Config = require(shared:WaitForChild("Config"))
local PremiumCityCatalog = require(shared:WaitForChild("PremiumCityCatalog"))
local ArtDirectionRegistry = require(shared:WaitForChild("ArtDirectionRegistry"))
local RemixCatalog = require(shared:WaitForChild("RemixCatalog"))
local WorldService = require(servicesRoot:WaitForChild("WorldService"))
local SecretFrameService = require(servicesRoot:WaitForChild("SecretFrameService"))

local checks = 0
local function check(condition: boolean, message: string): ()
	assert(condition, "AURA RUSH Secret Frames failure: " .. message)
	checks += 1
end

local function contains(values: { string }, target: string): boolean
	return table.find(values, target) ~= nil
end

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

check(Config.FeatureFlags.SecretFrames == true, "feature flag is disabled")
check(PremiumCityCatalog.Version == 7, "catalog version is stale")
check(#PremiumCityCatalog.SecretFrames == 6, "one secret per district is required")
check(Config.SecretFrames.DiscoveryGlowDust > 0, "discovery reward is missing")
check(Config.SecretFrames.CollectionBonusGlowDust > 0, "collection payoff is missing")

local catalogIds: { [string]: boolean } = {}
local worldIds: { [string]: boolean } = {}
for _, definition in PremiumCityCatalog.SecretFrames do
	check(type(definition.id) == "string" and definition.id ~= "", "secret id is missing")
	check(not catalogIds[definition.id], "duplicate secret id")
	check(not worldIds[definition.worldId], "district has more than one secret")
	check(hasCyrillic(definition.nameRu), "secret name is not authored Russian copy")
	check(hasCyrillic(definition.hintRu), "secret hint is not authored Russian copy")
	check(definition.productId == nil, "secret is incorrectly paywalled")
	check(definition.startsAt == nil and definition.endsAt == nil, "secret is time-gated")
	catalogIds[definition.id] = true
	worldIds[definition.worldId] = true
end
for _, district in PremiumCityCatalog.Districts do
	check(worldIds[district.id] == true, "district secret is missing: " .. district.id)
end

WorldService.Init({
	ArtDirectionRegistry = ArtDirectionRegistry,
	RemixCatalog = RemixCatalog,
	PremiumCityCatalog = PremiumCityCatalog,
})
local world = WorldService.Build()
local frames = WorldService.GetSecretFrames()
check(#frames == 6, "world did not build all secret frames")
local builtIds: { [string]: boolean } = {}
for _, anchor in frames do
	local frameId = tostring(anchor:GetAttribute("SecretFrameId") or "")
	check(catalogIds[frameId] == true, "world frame is absent from the catalog")
	check(not builtIds[frameId], "world built a duplicate secret frame")
	check(anchor.CanCollide == false and anchor.CanTouch == false, "secret blocks movement")
	check(anchor.Transparency > 0.5, "secret surface is visually noisy")
	local prompt = anchor:FindFirstChild("SecretFramePrompt")
	check(prompt ~= nil and prompt:IsA("ProximityPrompt"), "secret prompt is missing")
	local typedPrompt = prompt :: ProximityPrompt
	check(typedPrompt.RequiresLineOfSight, "secret can be activated through walls")
	check(typedPrompt.MaxActivationDistance <= 10, "secret interaction range is excessive")
	check(typedPrompt.HoldDuration >= 0.2, "secret is too easy to trigger by accident")
	builtIds[frameId] = true
end
local revealAnchor = frames[1]
local revealModel = revealAnchor.Parent
local previousRevealToken = tonumber(revealModel:GetAttribute("RevealToken")) or 0
check(
	WorldService.RevealSecretFrame(tostring(revealAnchor:GetAttribute("SecretFrameId"))),
	"valid frame did not reveal"
)
check(
	(tonumber(revealModel:GetAttribute("RevealToken")) or 0) == previousRevealToken + 1,
	"reveal token did not advance"
)
check(revealModel:FindFirstChild("DiscoveryHighlight") ~= nil, "shared reveal has no feedback")
check(not WorldService.RevealSecretFrame("unknown_frame"), "unknown frame revealed")
check(
	SecretFrameService.IsDistanceAllowed(Vector3.zero, Vector3.new(12, 0, 0), 10, 3),
	"valid padded interaction was rejected"
)
check(
	not SecretFrameService.IsDistanceAllowed(Vector3.zero, Vector3.new(14, 0, 0), 10, 3),
	"out-of-range interaction was accepted"
)

local profiles: { [any]: any } = {}
local toasts: { any } = {}
local economyEvents: { any } = {}
local customEvents: { any } = {}
local revealCount = 0
local metaPushes = 0
local flagEnabled = true
local flagCallback: ((string, any) -> ())? = nil
local flagDisconnected = false

local fakeServices: any = {}
fakeServices.Flags = {
	IsEnabled = function(key: string): boolean
		return key == "SecretFrames" and flagEnabled
	end,
	OnChanged = function(callback: (string, any) -> ()): () -> ()
		flagCallback = callback
		return function()
			flagDisconnected = true
		end
	end,
}
fakeServices.World = {
	GetSecretFrames = function(): { BasePart }
		return frames
	end,
	RevealSecretFrame = function(_frameId: string): boolean
		revealCount += 1
		return true
	end,
}
fakeServices.Data = {
	IsLoaded = function(player: any): boolean
		return profiles[player] ~= nil
	end,
	GetProfile = function(player: any): any
		return profiles[player]
	end,
	Update = function(player: any, mutator: (any) -> ()): boolean
		local profile = profiles[player]
		if not profile then
			return false
		end
		mutator(profile)
		return true
	end,
}
fakeServices.Progression = {
	ApplySchoolXp = function(profile: any, school: string, amount: number): any
		check(school == "Camera", "discovery rewarded the wrong mastery school")
		profile.cameraXp = (profile.cameraXp or 0) + amount
		return { ok = true }
	end,
}
fakeServices.Economy = {
	HasGrant = function(player: any, _kind: string, grantId: string): boolean
		local profile = profiles[player]
		return profile ~= nil and profile.grants[grantId] == true
	end,
	GrantCurrency = function(
		player: any,
		_kind: string,
		grantId: string,
		amount: number,
		mutator: ((any) -> any)?
	): any
		local profile = profiles[player]
		if not profile then
			return { ok = false, reason = "profile_unavailable", balance = 0 }
		end
		if profile.grants[grantId] then
			return { ok = true, alreadyApplied = true, amount = 0, balance = profile.glowDust }
		end
		profile.grants[grantId] = true
		profile.glowDust += amount
		if mutator then
			mutator(profile)
		end
		return {
			ok = true,
			alreadyApplied = false,
			amount = amount,
			balance = profile.glowDust,
			readOnly = false,
		}
	end,
}
fakeServices.Remote = {
	FireClient = function(_name: string, _player: any, payload: any)
		table.insert(toasts, payload)
	end,
}
fakeServices.Analytics = {
	Log = function(_player: any, name: string, _value: number, fields: any)
		table.insert(customEvents, { name = name, fields = fields })
	end,
	Economy = function(...: any)
		table.insert(economyEvents, { ... })
	end,
}
fakeServices.Meta = {
	Push = function(_player: any, kind: string)
		check(kind == "SecretFrames", "meta refresh used the wrong kind")
		metaPushes += 1
	end,
}

SecretFrameService.Init({
	Config = Config,
	PremiumCityCatalog = PremiumCityCatalog,
	Services = fakeServices,
})
check(flagCallback ~= nil, "feature flag listener was not registered")
flagEnabled = false
(flagCallback :: (string, any) -> ())("SecretFrames", false)
check(
	(frames[1]:FindFirstChild("SecretFramePrompt") :: ProximityPrompt).Enabled == false,
	"kill switch did not disable prompts"
)
flagEnabled = true
(flagCallback :: (string, any) -> ())("SecretFrames", true)

local function makePlayer(position: Vector3, profile: any): (any, Model)
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Position = position
	root.Parent = character
	local player = {
		Name = "SecretFrameTester",
		Parent = Players,
		Character = character,
	}
	profiles[player] = profile
	return player, character
end

local firstPrompt = frames[1]:FindFirstChild("SecretFramePrompt") :: ProximityPrompt
local firstId = tostring(firstPrompt:GetAttribute("SecretFrameId"))
local profile = { photoModeUnlocks = {}, glowDust = 0, grants = {}, achievements = {} }
local nearPlayer, nearCharacter = makePlayer(frames[1].Position, profile)
check(
	SecretFrameService.TryDiscover(nearPlayer, firstPrompt) == "discovered",
	"valid nearby discovery failed"
)
check(contains(profile.photoModeUnlocks, firstId), "frame was not persisted in the collection")
check(profile.glowDust == Config.SecretFrames.DiscoveryGlowDust, "discovery reward is wrong")
check(profile.cameraXp == Config.SecretFrames.DiscoveryCameraXp, "Camera XP reward is wrong")
check(revealCount == 1, "world reveal was not requested exactly once")
check(metaPushes == 1, "Creator Hub progress was not refreshed")
check(customEvents[1].name == "secret_frame_discovered", "discovery analytics is missing")
check(#economyEvents == 1, "discovery economy movement is missing")
check(toasts[#toasts].key == "secret_frame_found", "discovery feedback is missing")

local repeatPlayer, repeatCharacter = makePlayer(frames[1].Position, profile)
check(
	SecretFrameService.TryDiscover(repeatPlayer, firstPrompt) == "already_found",
	"repeat discovery was not idempotent"
)
check(profile.glowDust == Config.SecretFrames.DiscoveryGlowDust, "repeat discovery paid twice")

local farProfile = { photoModeUnlocks = {}, glowDust = 0, grants = {}, achievements = {} }
local farPlayer, farCharacter = makePlayer(frames[1].Position + Vector3.new(100, 0, 0), farProfile)
check(
	SecretFrameService.TryDiscover(farPlayer, firstPrompt) == "too_far",
	"server accepted an out-of-range discovery"
)
check(farProfile.glowDust == 0, "out-of-range discovery paid a reward")

local collectionUnlocks = {}
for index = 1, #PremiumCityCatalog.SecretFrames - 1 do
	table.insert(collectionUnlocks, PremiumCityCatalog.SecretFrames[index].id)
end
local collectionProfile = {
	photoModeUnlocks = collectionUnlocks,
	glowDust = 0,
	grants = {},
	achievements = {},
}
local lastAnchor = frames[#frames]
local lastPrompt = lastAnchor:FindFirstChild("SecretFramePrompt") :: ProximityPrompt
local collectionPlayer, collectionCharacter = makePlayer(lastAnchor.Position, collectionProfile)
check(
	SecretFrameService.TryDiscover(collectionPlayer, lastPrompt) == "collection_complete",
	"sixth frame did not complete the collection"
)
check(
	collectionProfile.glowDust
		== Config.SecretFrames.DiscoveryGlowDust + Config.SecretFrames.CollectionBonusGlowDust,
	"collection reward is wrong"
)
check(collectionProfile.achievements.secret_frame_collection == true, "achievement missing")
local completeView = SecretFrameService.GetViewForProfile(collectionProfile)
check(completeView.complete == true and completeView.foundCount == 6, "collection view is stale")
check(toasts[#toasts].key == "secret_frame_collection_complete", "collection feedback is missing")

SecretFrameService.Destroy()
check(flagDisconnected, "feature flag listener leaked")
nearCharacter:Destroy()
repeatCharacter:Destroy()
farCharacter:Destroy()
collectionCharacter:Destroy()
world:Destroy()

print(`AURA_RUSH_SECRET_FRAMES_V7_PASS ({checks} checks)`)
