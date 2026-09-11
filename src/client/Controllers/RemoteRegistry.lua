--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRegistry = {}
RemoteRegistry.__index = RemoteRegistry

export type RemoteRegistry = typeof(setmetatable(
	{} :: {
		Folder: Folder?,
		ReadinessIssue: string?,
	},
	RemoteRegistry
))

local FOLDER_NAMES = { "AuraRushRemotes", "Remotes" }
local WAIT_SECONDS = 12

local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared", WAIT_SECONDS)
local remotesDefinition: any = nil
if sharedRoot then
	local definitionModule = sharedRoot:FindFirstChild("Remotes")
	if definitionModule and definitionModule:IsA("ModuleScript") then
		local ok, result = pcall(require, definitionModule)
		if ok and type(result) == "table" then
			remotesDefinition = result
		end
	end
end

local function findFolder(): Folder?
	for _, name in FOLDER_NAMES do
		local candidate = ReplicatedStorage:FindFirstChild(name)
		if candidate and candidate:IsA("Folder") then
			return candidate
		end
	end
	return nil
end

local function inspectFolder(candidate: Folder?): (boolean, string?)
	if not candidate then
		return false, "folder_missing"
	end
	if candidate:GetAttribute("ContractReady") ~= true then
		return false, "contract_building"
	end
	if type(remotesDefinition) ~= "table" or type(remotesDefinition.All) ~= "table" then
		return false, "definition_missing"
	end
	local expectedVersion = math.max(1, math.floor(tonumber(remotesDefinition.Version) or 1))
	if candidate:GetAttribute("ContractVersion") ~= expectedVersion then
		return false, "version_mismatch"
	end
	for _, definition in remotesDefinition.All do
		local remote = candidate:FindFirstChild(definition.name)
		if not remote then
			return false, "missing_" .. tostring(definition.name)
		end
		if remote.ClassName ~= definition.className then
			return false, "class_" .. tostring(definition.name)
		end
	end
	return true, nil
end

local function waitForReadyFolder(): (Folder?, string?)
	local deadline = os.clock() + WAIT_SECONDS
	local candidate = findFolder()
	local _, issue = inspectFolder(candidate)
	while os.clock() < deadline do
		local ready, currentIssue = inspectFolder(candidate)
		if ready then
			return candidate, nil
		end
		issue = currentIssue
		task.wait(0.05)
		candidate = findFolder()
	end
	return candidate, issue
end

function RemoteRegistry.new(): RemoteRegistry
	local folder, issue = waitForReadyFolder()

	return setmetatable({
		Folder = folder,
		ReadinessIssue = issue,
	}, RemoteRegistry)
end

function RemoteRegistry.Refresh(self: RemoteRegistry)
	self.Folder = findFolder()
	local ready, issue = inspectFolder(self.Folder)
	self.ReadinessIssue = if ready then nil else issue
end

function RemoteRegistry.GetEvent(self: RemoteRegistry, name: string): RemoteEvent?
	if not self.Folder then
		self:Refresh()
	end
	local candidate = if self.Folder then self.Folder:FindFirstChild(name) else nil
	if candidate and candidate:IsA("RemoteEvent") then
		return candidate
	end
	return nil
end

function RemoteRegistry.GetFunction(self: RemoteRegistry, name: string): RemoteFunction?
	if not self.Folder then
		self:Refresh()
	end
	local candidate = if self.Folder then self.Folder:FindFirstChild(name) else nil
	if candidate and candidate:IsA("RemoteFunction") then
		return candidate
	end
	return nil
end

function RemoteRegistry.IsReady(self: RemoteRegistry): boolean
	local ready, issue = inspectFolder(self.Folder)
	self.ReadinessIssue = if ready then nil else issue
	return ready
end

function RemoteRegistry.GetReadinessIssue(self: RemoteRegistry): string
	self:IsReady()
	return self.ReadinessIssue or "ok"
end

return RemoteRegistry
