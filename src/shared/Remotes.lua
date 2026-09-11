--!strict

local Types = require(script.Parent.Types)
type RemoteDefinition = Types.RemoteDefinition
type RemoteClassName = Types.RemoteClassName
type RemoteDirection = Types.RemoteDirection

local function define(
	name: string,
	className: RemoteClassName,
	direction: RemoteDirection,
	capacity: number?,
	refillPerSecond: number?
): RemoteDefinition
	local rateLimit: Types.RateLimitDefinition? = nil
	if capacity ~= nil and refillPerSecond ~= nil then
		rateLimit = table.freeze({
			capacity = capacity,
			refillPerSecond = refillPerSecond,
		})
	end

	return table.freeze({
		name = name,
		className = className,
		direction = direction,
		rateLimit = rateLimit,
	})
end

local ClientToServer = table.freeze({
	RequestSnapshot = define("RequestSnapshot", "RemoteFunction", "ClientToServer", 2, 1),
	RequestMeta = define("RequestMeta", "RemoteFunction", "ClientToServer", 2, 1),
	RequestFirstMiracle = define("RequestFirstMiracle", "RemoteFunction", "ClientToServer", 2, 1),
	VoteBrief = define("VoteBrief", "RemoteEvent", "ClientToServer", 3, 1),
	BeatHit = define("BeatHit", "RemoteEvent", "ClientToServer", 16, 12),
	SubmitPrism = define("SubmitPrism", "RemoteEvent", "ClientToServer", 3, 1),
	SetStyle = define("SetStyle", "RemoteEvent", "ClientToServer", 10, 6),
	SetStyleReady = define("SetStyleReady", "RemoteEvent", "ClientToServer", 3, 1),
	UnlockStyle = define("UnlockStyle", "RemoteEvent", "ClientToServer", 4, 2),
	UpdateSettings = define("UpdateSettings", "RemoteEvent", "ClientToServer", 4, 2),
	Nominate = define("Nominate", "RemoteEvent", "ClientToServer", 3, 1),
	ChooseRoute = define("ChooseRoute", "RemoteEvent", "ClientToServer", 4, 2),
	SaveLook = define("SaveLook", "RemoteEvent", "ClientToServer", 3, 1),
	DeleteLook = define("DeleteLook", "RemoteEvent", "ClientToServer", 3, 1),
	EquipLook = define("EquipLook", "RemoteEvent", "ClientToServer", 4, 2),
	ClaimQuest = define("ClaimQuest", "RemoteEvent", "ClientToServer", 4, 2),
	RerollDaily = define("RerollDaily", "RemoteEvent", "ClientToServer", 2, 0.25),
	Requeue = define("Requeue", "RemoteEvent", "ClientToServer", 3, 1),
	PostcardAction = define("PostcardAction", "RemoteEvent", "ClientToServer", 4, 1),
	AtelierAction = define("AtelierAction", "RemoteEvent", "ClientToServer", 4, 1),
	ActivateToken = define("ActivateToken", "RemoteEvent", "ClientToServer", 2, 0.25),
	FirstMiracleAction = define("FirstMiracleAction", "RemoteEvent", "ClientToServer", 5, 2),
	RemixAction = define("RemixAction", "RemoteEvent", "ClientToServer", 12, 6),
})

local ServerToClient = table.freeze({
	RoundSnapshot = define("RoundSnapshot", "RemoteEvent", "ServerToClient", nil, nil),
	ProgressUpdate = define("ProgressUpdate", "RemoteEvent", "ServerToClient", nil, nil),
	Toast = define("Toast", "RemoteEvent", "ServerToClient", nil, nil),
	BloomStarted = define("BloomStarted", "RemoteEvent", "ServerToClient", nil, nil),
	MetaUpdate = define("MetaUpdate", "RemoteEvent", "ServerToClient", nil, nil),
	RunUpdate = define("RunUpdate", "RemoteEvent", "ServerToClient", nil, nil),
	PostcardUpdate = define("PostcardUpdate", "RemoteEvent", "ServerToClient", nil, nil),
	FirstMiracleUpdate = define("FirstMiracleUpdate", "RemoteEvent", "ServerToClient", nil, nil),
	RemixUpdate = define("RemixUpdate", "RemoteEvent", "ServerToClient", nil, nil),
})

local all: { RemoteDefinition } = {
	ClientToServer.RequestSnapshot,
	ClientToServer.RequestMeta,
	ClientToServer.RequestFirstMiracle,
	ClientToServer.VoteBrief,
	ClientToServer.BeatHit,
	ClientToServer.SubmitPrism,
	ClientToServer.SetStyle,
	ClientToServer.SetStyleReady,
	ClientToServer.UnlockStyle,
	ClientToServer.UpdateSettings,
	ClientToServer.Nominate,
	ClientToServer.ChooseRoute,
	ClientToServer.SaveLook,
	ClientToServer.DeleteLook,
	ClientToServer.EquipLook,
	ClientToServer.ClaimQuest,
	ClientToServer.RerollDaily,
	ClientToServer.Requeue,
	ClientToServer.PostcardAction,
	ClientToServer.AtelierAction,
	ClientToServer.ActivateToken,
	ClientToServer.FirstMiracleAction,
	ClientToServer.RemixAction,
	ServerToClient.RoundSnapshot,
	ServerToClient.ProgressUpdate,
	ServerToClient.Toast,
	ServerToClient.BloomStarted,
	ServerToClient.MetaUpdate,
	ServerToClient.RunUpdate,
	ServerToClient.PostcardUpdate,
	ServerToClient.FirstMiracleUpdate,
	ServerToClient.RemixUpdate,
}
local byName: { [string]: RemoteDefinition } = {}

for _, definition in all do
	assert(byName[definition.name] == nil, `Duplicate remote name: {definition.name}`)
	byName[definition.name] = definition
end

table.freeze(all)
table.freeze(byName)

local Remotes = {
	Version = 1,
	FolderName = "AuraRushRemotes",
	ClientToServer = ClientToServer,
	ServerToClient = ServerToClient,
	All = all,
	ByName = byName,
}

return table.freeze(Remotes)
