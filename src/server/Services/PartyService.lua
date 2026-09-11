--!strict

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local PartyService = {}

local snapshots: { [string]: { any } } = {}
local connections: { [Player]: RBXScriptConnection } = {}

local function partyIdFor(player: Player): string
	local ok, value = pcall(function()
		return (player :: any).PartyId
	end)
	return if ok and type(value) == "string" then value else ""
end

function PartyService.RefreshPlayer(player: Player): ()
	local partyId = partyIdFor(player)
	if partyId == "" then
		return
	end
	task.spawn(function()
		local ok, partyData = pcall(function()
			return SocialService:GetPartyAsync(partyId)
		end)
		if ok and type(partyData) == "table" then
			snapshots[partyId] = partyData
		end
	end)
end

function PartyService.Init(_context: any): ()
	local function observe(player: Player): ()
		PartyService.RefreshPlayer(player)
		local ok, signal = pcall(function()
			return (player :: any):GetPropertyChangedSignal("PartyId")
		end)
		if ok and typeof(signal) == "RBXScriptSignal" then
			connections[player] = signal:Connect(function()
				PartyService.RefreshPlayer(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(observe)
	Players.PlayerRemoving:Connect(function(player)
		local connection = connections[player]
		if connection then
			connection:Disconnect()
			connections[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		observe(player)
	end
end

function PartyService.GetPartyId(player: Player): string
	return partyIdFor(player)
end

function PartyService.GetLocalPlayers(player: Player): { Player }
	local partyId = partyIdFor(player)
	if partyId == "" then
		return { player }
	end
	local ok, partyPlayers = pcall(function()
		return SocialService:GetPlayersByPartyId(partyId)
	end)
	if ok and type(partyPlayers) == "table" and #partyPlayers > 0 then
		return partyPlayers
	end
	return { player }
end

function PartyService.GetClientView(player: Player): any
	local partyId = partyIdFor(player)
	if partyId == "" then
		return { inParty = false, localUserIds = { player.UserId }, totalMembers = 1 }
	end
	local localUserIds: { number } = {}
	for _, partyPlayer in PartyService.GetLocalPlayers(player) do
		table.insert(localUserIds, partyPlayer.UserId)
	end
	local snapshot = snapshots[partyId]
	return {
		inParty = true,
		partyId = partyId,
		localUserIds = localUserIds,
		totalMembers = if snapshot then #snapshot else #localUserIds,
	}
end

function PartyService.Destroy(): ()
	for player, connection in connections do
		connection:Disconnect()
		connections[player] = nil
	end
	table.clear(snapshots)
end

return PartyService
