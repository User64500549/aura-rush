--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = {}

local DEFAULT_FOLDER_NAME = "AuraRushRemotes"
local MAX_PAYLOAD_DEPTH = 5
local MAX_PAYLOAD_NODES = 96
local MAX_PAYLOAD_STRING_BYTES = 256

type Window = {
	startedAt: number,
	count: number,
}

local folder: Folder? = nil
local remotes: { [string]: Instance } = {}
local windows: { [Player]: { [string]: Window } } = {}
local counters: { [string]: { accepted: number, rejected: number, outbound: number } } = {}
local eventConnections: { RBXScriptConnection } = {}
local functionRemotes: { [RemoteFunction]: boolean } = {}
local playerRemovingConnection: RBXScriptConnection? = nil

local function clearBindings(): ()
	for _, connection in eventConnections do
		connection:Disconnect()
	end
	table.clear(eventConnections)
	for remote in functionRemotes do
		remote.OnServerInvoke = nil
	end
	table.clear(functionRemotes)
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
end

local function finiteNumber(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function RemoteService.ValidatePayload(payload: any): (boolean, string)
	local visited: { [table]: boolean } = {}
	local nodes = 0

	local function visit(value: any, depth: number): (boolean, string)
		nodes += 1
		if nodes > MAX_PAYLOAD_NODES then
			return false, "node_limit"
		end

		local valueType = type(value)
		if valueType == "nil" or valueType == "boolean" then
			return true, "ok"
		elseif valueType == "number" then
			return if finiteNumber(value) then true else false,
				if finiteNumber(value) then "ok" else "non_finite_number"
		elseif valueType == "string" then
			return if #value <= MAX_PAYLOAD_STRING_BYTES then true else false,
				if #value <= MAX_PAYLOAD_STRING_BYTES then "ok" else "string_limit"
		elseif valueType ~= "table" then
			return false, "unsupported_type"
		end

		if depth >= MAX_PAYLOAD_DEPTH then
			return false, "depth_limit"
		end
		if visited[value] then
			return false, "cycle"
		end
		visited[value] = true
		for key, nestedValue in value do
			local keyType = type(key)
			if keyType == "string" then
				if #key > 64 then
					visited[value] = nil
					return false, "key_limit"
				end
			elseif keyType == "number" then
				if not finiteNumber(key) then
					visited[value] = nil
					return false, "invalid_key"
				end
			else
				visited[value] = nil
				return false, "invalid_key"
			end
			nodes += 1
			if nodes > MAX_PAYLOAD_NODES then
				visited[value] = nil
				return false, "node_limit"
			end
			local valid, reason = visit(nestedValue, depth + 1)
			if not valid then
				visited[value] = nil
				return false, reason
			end
		end
		visited[value] = nil
		return true, "ok"
	end

	return visit(payload, 0)
end

function RemoteService.GetPayloadLimits(): {
	maxDepth: number,
	maxNodes: number,
	maxStringBytes: number,
}
	return {
		maxDepth = MAX_PAYLOAD_DEPTH,
		maxNodes = MAX_PAYLOAD_NODES,
		maxStringBytes = MAX_PAYLOAD_STRING_BYTES,
	}
end

local function counterFor(name: string): { accepted: number, rejected: number, outbound: number }
	local counter = counters[name]
	if not counter then
		counter = { accepted = 0, rejected = 0, outbound = 0 }
		counters[name] = counter
	end
	return counter
end

local function allow(player: Player, remoteName: string, perSecond: number): boolean
	local now = os.clock()
	local playerWindows = windows[player]
	if not playerWindows then
		playerWindows = {}
		windows[player] = playerWindows
	end

	local window = playerWindows[remoteName]
	if not window or now - window.startedAt >= 1 then
		playerWindows[remoteName] = { startedAt = now, count = 1 }
		return true
	end

	if window.count >= perSecond then
		counterFor(remoteName).rejected += 1
		return false
	end
	window.count += 1
	return true
end

local function reportHandlerError(remoteName: string, player: Player, message: string): ()
	warn(string.format("[AuraRush/Remote] %s failed for %s: %s", remoteName, player.Name, message))
end

function RemoteService.Init(context: any): ()
	clearBindings()
	table.clear(remotes)
	table.clear(windows)
	table.clear(counters)

	local folderName = DEFAULT_FOLDER_NAME
	local definition = context.RemotesDefinition
	if type(definition) == "table" and type(definition.FolderName) == "string" then
		folderName = definition.FolderName
	end

	local existing = ReplicatedStorage:FindFirstChild(folderName)
	if existing and not existing:IsA("Folder") then
		existing:Destroy()
		existing = nil
	end

	local remoteFolder = existing :: Folder?
	local shouldPublishFolder = false
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = folderName
		shouldPublishFolder = true
	end
	folder = remoteFolder
	remoteFolder:SetAttribute("ContractReady", false)

	assert(
		type(definition) == "table" and type(definition.All) == "table",
		"Aura Rush remote definitions are required"
	)
	local classes: { [string]: string } = {}
	for _, remoteDefinition in definition.All do
		assert(type(remoteDefinition) == "table", "Invalid Aura Rush remote definition")
		assert(
			type(remoteDefinition.name) == "string" and remoteDefinition.name ~= "",
			"Aura Rush remote definition is missing a name"
		)
		assert(
			remoteDefinition.className == "RemoteEvent"
				or remoteDefinition.className == "RemoteFunction",
			"Aura Rush remote definition has an invalid class"
		)
		assert(
			classes[remoteDefinition.name] == nil,
			"Duplicate Aura Rush remote definition: " .. remoteDefinition.name
		)
		classes[remoteDefinition.name] = remoteDefinition.className
	end
	local contractCount = 0
	for name, className in classes do
		contractCount += 1
		local remote = remoteFolder:FindFirstChild(name)
		if remote and remote.ClassName ~= className then
			remote:Destroy()
			remote = nil
		end
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = remoteFolder
		end
		remotes[name] = remote
		counterFor(name)
	end
	local contractVersion = if type(definition) == "table"
		then math.max(1, math.floor(tonumber(definition.Version) or 1))
		else 1
	remoteFolder:SetAttribute("ContractVersion", contractVersion)
	remoteFolder:SetAttribute("ContractCount", contractCount)
	remoteFolder:SetAttribute("ContractReady", true)
	if shouldPublishFolder then
		remoteFolder.Parent = ReplicatedStorage
	end

	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		windows[player] = nil
	end)
end

function RemoteService.Get(name: string): Instance
	local remote = remotes[name]
	assert(remote, "Unknown Aura Rush remote: " .. name)
	return remote
end

function RemoteService.GetFolder(): Folder
	assert(folder, "RemoteService.Init must run first")
	return folder
end

function RemoteService.BindEvent(
	name: string,
	perSecond: number,
	handler: (Player, any) -> ()
): RBXScriptConnection
	local remote = RemoteService.Get(name)
	assert(remote:IsA("RemoteEvent"), name .. " is not a RemoteEvent")
	local connection = remote.OnServerEvent:Connect(function(player: Player, payload: any)
		if not allow(player, name, perSecond) then
			return
		end
		local valid = RemoteService.ValidatePayload(payload)
		if not valid then
			counterFor(name).rejected += 1
			return
		end
		counterFor(name).accepted += 1
		local ok, message = xpcall(function()
			handler(player, payload)
		end, debug.traceback)
		if not ok then
			reportHandlerError(name, player, tostring(message))
		end
	end)
	table.insert(eventConnections, connection)
	return connection
end

function RemoteService.BindFunction(
	name: string,
	perSecond: number,
	handler: (Player, any) -> any
): ()
	local remote = RemoteService.Get(name)
	assert(remote:IsA("RemoteFunction"), name .. " is not a RemoteFunction")
	remote.OnServerInvoke = function(player: Player, payload: any): any
		if not allow(player, name, perSecond) then
			return nil
		end
		local valid = RemoteService.ValidatePayload(payload)
		if not valid then
			counterFor(name).rejected += 1
			return nil
		end
		counterFor(name).accepted += 1
		local ok, result = xpcall(function()
			return handler(player, payload)
		end, debug.traceback)
		if not ok then
			reportHandlerError(name, player, tostring(result))
			return nil
		end
		return result
	end
	functionRemotes[remote] = true
end

function RemoteService.FireClient(name: string, player: Player, payload: any): ()
	local remote = RemoteService.Get(name)
	assert(remote:IsA("RemoteEvent"), name .. " is not a RemoteEvent")
	counterFor(name).outbound += 1
	remote:FireClient(player, payload)
end

function RemoteService.FireAll(name: string, payload: any): ()
	local remote = RemoteService.Get(name)
	assert(remote:IsA("RemoteEvent"), name .. " is not a RemoteEvent")
	counterFor(name).outbound += #Players:GetPlayers()
	remote:FireAllClients(payload)
end

function RemoteService.GetStats(): {
	[string]: { accepted: number, rejected: number, outbound: number },
}
	local result: { [string]: { accepted: number, rejected: number, outbound: number } } = {}
	for name, counter in counters do
		result[name] = {
			accepted = counter.accepted,
			rejected = counter.rejected,
			outbound = counter.outbound,
		}
	end
	return result
end

function RemoteService.Destroy(): ()
	clearBindings()
	if folder then
		folder:SetAttribute("ContractReady", false)
	end
	table.clear(remotes)
	table.clear(windows)
	table.clear(counters)
	folder = nil
end

return RemoteService
