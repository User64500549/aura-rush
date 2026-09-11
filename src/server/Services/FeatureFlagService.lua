--!strict

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local FeatureFlagService = {}

local config: any = nil
local snapshot: any = nil
local remoteValues: { [string]: any } = {}
local refreshConnection: RBXScriptConnection? = nil
local remoteService: any = nil
local hasReadSnapshot = false
local changeListeners: { [number]: (string, any) -> () } = {}
local nextListenerId = 0

local REMOTE_KEYS = table.freeze({
	"FirstMiracle",
	"AdaptiveRuns",
	"Progression",
	"LiveOps",
	"Crews",
	"CommunityBloom",
	"EditablePostcards",
	"ModularAudio",
	"ChallengeFramework2",
	"BloomComposer2",
	"SpatialFirstMiracle",
	"LivingCity",
	"StyleOS",
	"RemixCity",
	"StyleChemistry",
	"GuardianFinales",
	"ReplayGhosts",
	"SeasonOne",
	"CityPulse",
	"SecretFrames",
})

-- Commerce and persistence can never be enabled remotely. They remain visible
-- to clients through GetAll(), but their value is sourced only from reviewed code.
local ALL_KEYS = table.freeze({
	"Persistence",
	"Analytics",
	"Capture",
	"FirstMiracle",
	"AdaptiveRuns",
	"Progression",
	"NewChallenges",
	"Postcards",
	"LiveOps",
	"Crews",
	"CommunityBloom",
	"EditablePostcards",
	"ModularAudio",
	"Purchases",
	"Passes",
	"MarketplaceCatalog",
	"Subscriptions",
	"ChallengeFramework2",
	"BloomComposer2",
	"SpatialFirstMiracle",
	"LivingCity",
	"StyleOS",
	"RemixCity",
	"StyleChemistry",
	"GuardianFinales",
	"ReplayGhosts",
	"SeasonOne",
	"CityPulse",
	"SecretFrames",
	"RecommendationService",
	"PredictiveStreaming",
	"ExperimentalMeshStreaming",
	"ExperimentalAcoustics",
	"RewardedVideo",
})

local function getLocalValue(key: string): any
	local featureFlags = if config then config.FeatureFlags else nil
	if type(featureFlags) == "table" then
		return featureFlags[key]
	end
	return nil
end

local function readSnapshot(): ()
	if not snapshot then
		return
	end
	local changed = false
	local changedKeys = {}
	for _, key in REMOTE_KEYS do
		local ok, value = pcall(function()
			return snapshot:GetValue("aura_rush_" .. string.lower(key))
		end)
		if ok and type(value) == type(getLocalValue(key)) then
			if remoteValues[key] ~= value then
				changed = true
				table.insert(changedKeys, key)
			end
			remoteValues[key] = value
		end
	end
	if changed and hasReadSnapshot and remoteService then
		for _, player in Players:GetPlayers() do
			remoteService.FireClient("MetaUpdate", player, {
				kind = "FeatureFlags",
				data = { featureFlags = FeatureFlagService.GetAll() },
			})
		end
	end
	if changed and hasReadSnapshot then
		local listeners = table.clone(changeListeners)
		for _, key in changedKeys do
			for _, callback in listeners do
				local ok, message = pcall(callback, key, FeatureFlagService.Get(key))
				if not ok then
					warn("[AuraRush/Flags] change listener failed: " .. tostring(message))
				end
			end
		end
	end
	hasReadSnapshot = true
end

function FeatureFlagService.Init(context: any): ()
	config = context.Config
	remoteService = context.Services.Remote
	hasReadSnapshot = false
	if refreshConnection then
		refreshConnection:Disconnect()
		refreshConnection = nil
	end
	table.clear(remoteValues)

	if RunService:IsStudio() and game.GameId == 0 then
		return
	end
	local serviceOk, configService = pcall(function()
		return game:GetService("ConfigService")
	end)
	if not serviceOk or not configService then
		return
	end
	local ok, result = pcall(function()
		return (configService :: any):GetConfigAsync()
	end)
	if not ok or not result then
		warn("[AuraRush/Flags] Experience Configs unavailable; using local fallbacks")
		return
	end
	snapshot = result
	readSnapshot()
	local updateAvailable = snapshot.UpdateAvailable
	if typeof(updateAvailable) == "RBXScriptSignal" then
		refreshConnection = updateAvailable:Connect(function()
			local refreshed = pcall(function()
				snapshot:Refresh()
			end)
			if refreshed then
				readSnapshot()
			end
		end)
	end
end

function FeatureFlagService.Get(key: string): any
	local remote = remoteValues[key]
	if remote ~= nil then
		return remote
	end
	return getLocalValue(key)
end

function FeatureFlagService.IsEnabled(key: string): boolean
	return FeatureFlagService.Get(key) == true
end

function FeatureFlagService.GetAll(): { [string]: any }
	local result: { [string]: any } = {}
	for _, key in ALL_KEYS do
		result[key] = FeatureFlagService.Get(key)
	end
	return result
end

function FeatureFlagService.OnChanged(callback: (string, any) -> ()): () -> ()
	nextListenerId += 1
	local listenerId = nextListenerId
	changeListeners[listenerId] = callback
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		changeListeners[listenerId] = nil
	end
end

function FeatureFlagService.Destroy(): ()
	if refreshConnection then
		refreshConnection:Disconnect()
		refreshConnection = nil
	end
	snapshot = nil
	remoteService = nil
	hasReadSnapshot = false
	table.clear(remoteValues)
	table.clear(changeListeners)
end

return FeatureFlagService
