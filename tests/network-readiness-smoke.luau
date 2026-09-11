--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local serverRoot = ServerScriptService:WaitForChild("AuraRushServer")
local servicesRoot = serverRoot:WaitForChild("Services")
local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local clientRoot = StarterPlayer.StarterPlayerScripts:WaitForChild("AuraRushClient")
local controllersRoot = clientRoot:WaitForChild("Controllers")
local RemoteService = require(servicesRoot:WaitForChild("RemoteService"))
local RemoteRegistry = require(controllersRoot:WaitForChild("RemoteRegistry"))
local Remotes = require(sharedRoot:WaitForChild("Remotes"))

local checks = 0
local function check(condition: boolean, message: string): ()
	assert(condition, "AURA RUSH network readiness failure: " .. message)
	checks += 1
end

local stale = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
if stale then
	stale:Destroy()
end

RemoteService.Init({ RemotesDefinition = Remotes })
local folder = RemoteService.GetFolder()
check(folder.Parent == ReplicatedStorage, "network folder was not published")
check(folder:GetAttribute("ContractReady") == true, "network contract never became ready")
check(folder:GetAttribute("ContractVersion") == Remotes.Version, "network version drifted")
check(folder:GetAttribute("ContractCount") == #Remotes.All, "network count drifted")
for _, definition in Remotes.All do
	local remote = folder:FindFirstChild(definition.name)
	check(remote ~= nil, `remote is missing: {definition.name}`)
	check(remote.ClassName == definition.className, `remote class drifted: {definition.name}`)
end

local registry = RemoteRegistry.new()
check(registry:IsReady(), "complete network contract was rejected")
check(registry:GetReadinessIssue() == "ok", "ready contract retained an error reason")

local missing = folder:FindFirstChild("VoteBrief")
check(missing ~= nil, "VoteBrief is unavailable for corruption test")
missing:Destroy()
registry:Refresh()
check(not registry:IsReady(), "registry accepted a contract with a missing remote")
check(registry:GetReadinessIssue() == "missing_VoteBrief", "missing remote reason is unclear")

local restoredVote = Instance.new("RemoteEvent")
restoredVote.Name = "VoteBrief"
restoredVote.Parent = folder
registry:Refresh()
check(registry:IsReady(), "registry did not recover after remote restoration")

local wrongClass = folder:FindFirstChild("RequestSnapshot")
check(wrongClass ~= nil, "RequestSnapshot is unavailable for class test")
wrongClass:Destroy()
local invalidSnapshot = Instance.new("RemoteEvent")
invalidSnapshot.Name = "RequestSnapshot"
invalidSnapshot.Parent = folder
registry:Refresh()
check(not registry:IsReady(), "registry accepted the wrong remote class")
check(registry:GetReadinessIssue() == "class_RequestSnapshot", "wrong-class reason is unclear")

invalidSnapshot:Destroy()
local restoredSnapshot = Instance.new("RemoteFunction")
restoredSnapshot.Name = "RequestSnapshot"
restoredSnapshot.Parent = folder
registry:Refresh()
check(registry:IsReady(), "registry did not recover after class restoration")

local remoteServiceSource = (servicesRoot:WaitForChild("RemoteService") :: ModuleScript).Source
local readyPosition =
	string.find(remoteServiceSource, 'remoteFolder:SetAttribute("ContractReady", true)', 1, true)
local publishPosition =
	string.find(remoteServiceSource, "remoteFolder.Parent = ReplicatedStorage", 1, true)
check(
	readyPosition ~= nil and publishPosition ~= nil and readyPosition < publishPosition,
	"new network folder is replicated before its contract is complete"
)
for _, token in { "eventConnections", "functionRemotes", "clearBindings", "RemoteService.Destroy" } do
	check(
		string.find(remoteServiceSource, token, 1, true) ~= nil,
		`remote lifecycle token missing: {token}`
	)
end

local bootstrapSource = (clientRoot:WaitForChild("Bootstrap") :: LocalScript).Source
local registryPosition = string.find(bootstrapSource, "RemoteRegistry.new()", 1, true)
local appPosition = string.find(bootstrapSource, "App.new(playerGui)", 1, true)
check(
	registryPosition ~= nil and appPosition ~= nil and registryPosition < appPosition,
	"client creates the full UI before validating its network contract"
)
check(
	string.find(bootstrapSource, "network contract unavailable", 1, true) ~= nil,
	"client has no explicit network-contract failure"
)

RemoteService.Destroy()
check(folder:GetAttribute("ContractReady") == false, "destroy leaves a false-ready contract")
registry:Refresh()
check(not registry:IsReady(), "client accepts a destroyed server contract")

RemoteService.Init({ RemotesDefinition = Remotes })
check(
	RemoteService.GetFolder():GetAttribute("ContractReady") == true,
	"network cannot reinitialize"
)
RemoteService.Destroy()
folder:Destroy()

print(`AURA_RUSH_NETWORK_READINESS_PASS ({checks} checks)`)
