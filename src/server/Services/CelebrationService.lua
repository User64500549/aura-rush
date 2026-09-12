--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local CelebrationService = {}

local services: any = nil
local nextActivationAt = 0
local playerCooldowns: { [Player]: number } = {}
local active = false
local playerRemovingConnection: RBXScriptConnection? = nil
local lifecycleEpoch = 0

local function countToken(profile: any, tokenId: string): number
	if type(profile) ~= "table" or type(profile.activationTokens) ~= "table" then
		return 0
	end
	return math.max(0, math.floor(tonumber(profile.activationTokens[tokenId]) or 0))
end

local function restoreToken(player: Player, tokenId: string, activationId: string): boolean
	services.Data.Update(player, function(profile: any)
		profile.activationTokens = profile.activationTokens or {}
		profile.activationTokens[tokenId] = countToken(profile, tokenId) + 1
		profile.pendingActivations = profile.pendingActivations or {}
		profile.pendingActivations[activationId] = nil
	end)
	return services.Data.Save(player)
end

local function activate(player: Player, tokenId: string): ()
	if tokenId ~= "glowstorm" or active or os.clock() < nextActivationAt then
		return
	end
	if (playerCooldowns[player] or 0) > os.clock() or services.Data.IsReadOnly(player) then
		return
	end
	local profile = services.Data.GetProfile(player)
	if countToken(profile, tokenId) <= 0 then
		return
	end
	local activationId = HttpService:GenerateGUID(false)
	active = true
	local consumed = services.Data.Update(player, function(editable: any)
		if countToken(editable, tokenId) <= 0 then
			error("Activation token was already consumed")
		end
		editable.activationTokens[tokenId] = countToken(editable, tokenId) - 1
		editable.pendingActivations = editable.pendingActivations or {}
		editable.pendingActivations[activationId] = {
			tokenId = tokenId,
			createdAt = os.time(),
		}
	end)
	if not consumed then
		active = false
		return
	end
	if not services.Data.Save(player) then
		restoreToken(player, tokenId, activationId)
		active = false
		return
	end

	nextActivationAt = os.clock() + 45
	playerCooldowns[player] = os.clock() + 120
	local ok, message = pcall(function()
		services.World.TriggerGlowstorm(player.DisplayName)
	end)
	if not ok then
		restoreToken(player, tokenId, activationId)
		active = false
		warn("[AuraRush/Celebration] Token restored after visual failure: " .. tostring(message))
		return
	end
	services.Data.Update(player, function(editable: any)
		editable.pendingActivations = editable.pendingActivations or {}
		editable.pendingActivations[activationId] = nil
	end)
	if not services.Data.Save(player) then
		-- The durable reservation remains in the last successful snapshot, so a
		-- reconnect refunds the token rather than losing paid value.
		warn("[AuraRush/Celebration] Activation completion save deferred")
	end
	services.Remote.FireAll("Toast", {
		key = "server_glowstorm",
		tone = "Success",
		from = player.DisplayName,
	})
	services.Remote.FireClient("MetaUpdate", player, {
		kind = "ActivationToken",
		profile = services.Data.GetClientView(player),
	})
	services.Analytics.Log(player, "celebration_token_activated", 1, { tokenId = tokenId })
	local expectedEpoch = lifecycleEpoch
	task.delay(18, function()
		if expectedEpoch == lifecycleEpoch then
			active = false
		end
	end)
end

function CelebrationService.RecoverPending(player: Player): number
	if services.Data.IsReadOnly(player) then
		return 0
	end
	local profile = services.Data.GetProfile(player)
	if not profile or type(profile.pendingActivations) ~= "table" then
		return 0
	end
	local recovered = 0
	local updated = services.Data.Update(player, function(editable: any)
		for activationId, reservation in editable.pendingActivations do
			local tokenId = if type(reservation) == "table" then reservation.tokenId else nil
			if
				type(activationId) == "string"
				and type(tokenId) == "string"
				and #tokenId > 0
				and #tokenId <= 48
			then
				editable.activationTokens[tokenId] = countToken(editable, tokenId) + 1
				recovered += 1
			end
			editable.pendingActivations[activationId] = nil
		end
	end)
	if updated and recovered > 0 then
		services.Data.Save(player)
		services.Analytics.Log(player, "celebration_token_recovered", recovered, nil)
	end
	return recovered
end

function CelebrationService.Init(context: any): ()
	CelebrationService.Destroy()
	lifecycleEpoch += 1
	services = context.Services
	services.Remote.BindEvent("ActivateToken", 1, function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.tokenId) ~= "string" then
			return
		end
		activate(player, string.sub(payload.tokenId, 1, 48))
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		playerCooldowns[player] = nil
	end)
end

function CelebrationService.Destroy(): ()
	lifecycleEpoch += 1
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	table.clear(playerCooldowns)
	nextActivationAt = 0
	active = false
	services = nil
end

return CelebrationService
