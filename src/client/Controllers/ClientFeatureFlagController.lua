--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistryModule = require(script.Parent.RemoteRegistry)
type RemoteRegistry = RemoteRegistryModule.RemoteRegistry

local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local Config = require(sharedRoot:WaitForChild("Config"))

local ClientFeatureFlagController = {}
ClientFeatureFlagController.__index = ClientFeatureFlagController

local FLAG_KEYS = table.freeze({
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
	"RecommendationService",
	"PredictiveStreaming",
	"ExperimentalMeshStreaming",
	"ExperimentalAcoustics",
	"RewardedVideo",
})

export type ClientFeatureFlagController = typeof(setmetatable(
	{} :: {
		Remotes: RemoteRegistry,
		Connections: { RBXScriptConnection },
	},
	ClientFeatureFlagController
))

local function setFlag(key: string, value: any): ()
	if type(value) == "boolean" then
		Players.LocalPlayer:SetAttribute("AuraRushFlag_" .. key, value)
	end
end

local function applyFlags(flags: any): ()
	if type(flags) ~= "table" then
		return
	end
	for _, key in FLAG_KEYS do
		setFlag(key, flags[key])
	end
end

local function flagsFromPayload(payload: any): any
	if type(payload) ~= "table" then
		return nil
	end
	local data = if type(payload.data) == "table" then payload.data else payload
	return data.featureFlags or payload.featureFlags
end

function ClientFeatureFlagController.new(remotes: RemoteRegistry): ClientFeatureFlagController
	local self: ClientFeatureFlagController = setmetatable({
		Remotes = remotes,
		Connections = {},
	}, ClientFeatureFlagController)

	applyFlags(Config.FeatureFlags)
	local metaUpdate = remotes:GetEvent("MetaUpdate")
	if metaUpdate then
		table.insert(
			self.Connections,
			metaUpdate.OnClientEvent:Connect(function(payload: any)
				applyFlags(flagsFromPayload(payload))
			end)
		)
	end
	task.defer(function()
		local request = remotes:GetFunction("RequestMeta")
		if not request then
			return
		end
		local ok, result = pcall(function()
			return request:InvokeServer({})
		end)
		if ok then
			applyFlags(flagsFromPayload(result))
		end
	end)
	return self
end

function ClientFeatureFlagController.Destroy(self: ClientFeatureFlagController): ()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return ClientFeatureFlagController
