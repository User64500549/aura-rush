--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SocialCreationService = {}

local services: any = nil
local config: any = nil
local styleCatalog: any = nil
local recentPostcards: { [string]: any } = {}
local recentOrder: { string } = {}
local createdForRound: { [Player]: string } = {}
local reactions: { [string]: { [number]: string } } = {}
local pendingAtelierInvites: { [Player]: { id: string, invitedBy: number, expiresAt: number } } = {}
local atelierInviteCooldowns: { [string]: number } = {}
local atelierInviteBlocks: { [Player]: { [number]: number } } = {}
local atelierStore: any = nil
local localAtelierWeeks: { [string]: any } = {}

local ATELIER_WEEK_SECONDS = 7 * 86_400
local ATELIER_INVITE_SECONDS = 120
local ATELIER_INVITE_COOLDOWN_SECONDS = 300
local ATELIER_INVITE_BLOCK_SECONDS = 30 * 86_400
local MAX_ATELIER_CONTRIBUTION_RECEIPTS = 300

local POSITIVE_REACTIONS: { [string]: boolean } = table.freeze({
	color_story = true,
	kind_collaborator = true,
	bold_remix = true,
	team_hero = true,
	unexpected_idea = true,
})

local function atelierWeek(timestamp: number?): number
	return math.floor((timestamp or os.time()) / ATELIER_WEEK_SECONDS)
end

local function invitationKey(inviterUserId: number, targetUserId: number): string
	return tostring(inviterUserId) .. ":" .. tostring(targetUserId)
end

local function trimTimestampMap(values: any, maximum: number): ()
	if type(values) ~= "table" then
		return
	end
	local entries = {}
	for id, timestamp in values do
		if type(id) == "string" then
			table.insert(entries, { id = id, timestamp = tonumber(timestamp) or 0 })
		end
	end
	table.sort(entries, function(left, right)
		if left.timestamp == right.timestamp then
			return left.id < right.id
		end
		return left.timestamp < right.timestamp
	end)
	for index = 1, math.max(0, #entries - maximum) do
		values[entries[index].id] = nil
	end
end

local function qualifiedRound(player: Player, roundId: string): boolean
	return roundId ~= ""
		and services.Economy ~= nil
		and type(services.Economy.HasGrant) == "function"
		and services.Economy.HasGrant(player, "system", "qualified_round:" .. roundId)
end

local function sharedWeekKey(ownerUserId: number, period: number): string
	return string.format("week:%d:%d", period, math.max(0, math.floor(ownerUserId)))
end

local function normalizeSharedWeek(current: any, period: number): any
	local record = if type(current) == "table" then current else {}
	record.version = 1
	record.period = period
	record.total = math.max(0, math.floor(tonumber(record.total) or 0))
	record.receipts = if type(record.receipts) == "table" then record.receipts else {}
	record.members = if type(record.members) == "table" then record.members else {}
	return record
end

local function cloneLoadout(loadout: any): { [string]: string }
	local result: { [string]: string } = {}
	for _, category in { "palette", "material", "aura", "pose", "accent" } do
		local value = if type(loadout) == "table" then loadout[category] else nil
		if type(value) == "string" then
			result[category] = value
		end
	end
	return result
end

local function fireMeta(player: Player): ()
	services.Remote.FireClient("MetaUpdate", player, {
		kind = "Social",
		profile = services.Data.GetClientView(player),
	})
end

local function syncLocalAtelierWeek(atelierId: string, record: any): ()
	local period = math.floor(tonumber(record.period) or atelierWeek())
	local total = math.max(0, math.floor(tonumber(record.total) or 0))
	local members = if type(record.members) == "table" then record.members else {}
	for _, localPlayer in Players:GetPlayers() do
		local profile = services.Data.GetProfile(localPlayer)
		if
			profile
			and type(profile.atelier) == "table"
			and profile.atelier.id == atelierId
			and not services.Data.IsReadOnly(localPlayer)
		then
			local personal =
				math.max(0, math.floor(tonumber(members[tostring(localPlayer.UserId)]) or 0))
			local updated = services.Data.Update(localPlayer, function(editable: any)
				if type(editable.atelier) == "table" and editable.atelier.id == atelierId then
					editable.atelier.contributionPeriod = period
					editable.atelier.weeklyContribution = total
					editable.atelier.personalWeeklyContribution = personal
				end
			end)
			if updated then
				fireMeta(localPlayer)
			end
		end
	end
end

local function loadSharedAtelierWeek(atelier: any): any
	local ownerUserId = math.max(0, math.floor(tonumber(atelier.ownerUserId) or 0))
	local atelierId = if type(atelier.id) == "string" then atelier.id else ""
	if ownerUserId <= 0 or atelierId == "" then
		return nil
	end
	local period = atelierWeek()
	local key = sharedWeekKey(ownerUserId, period)
	if not atelierStore then
		local record = normalizeSharedWeek(localAtelierWeeks[key], period)
		localAtelierWeeks[key] = record
		return record
	end
	local ok, current = pcall(function()
		return atelierStore:GetAsync(key)
	end)
	if not ok then
		return nil
	end
	return normalizeSharedWeek(current, period)
end

local function hydrateAtelierForPlayer(player: Player): ()
	local profile = services.Data.GetProfile(player)
	local atelier = if profile then profile.atelier else nil
	if type(atelier) ~= "table" or type(atelier.id) ~= "string" or atelier.id == "" then
		return
	end
	local record = loadSharedAtelierWeek(atelier)
	if record then
		syncLocalAtelierWeek(atelier.id, record)
	end
end

local function recordSharedAtelierRound(player: Player, atelier: any, roundId: string): any
	local ownerUserId = math.max(0, math.floor(tonumber(atelier.ownerUserId) or 0))
	local atelierId = if type(atelier.id) == "string" then atelier.id else ""
	if ownerUserId <= 0 or atelierId == "" then
		return nil
	end
	local period = atelierWeek()
	local key = sharedWeekKey(ownerUserId, period)
	local receiptId = tostring(player.UserId) .. ":" .. string.sub(roundId, 1, 100)
	local applied = false
	local function apply(current: any): any
		local record = normalizeSharedWeek(current, period)
		if record.receipts[receiptId] == nil then
			record.receipts[receiptId] = os.time()
			record.total += 1
			local memberKey = tostring(player.UserId)
			record.members[memberKey] = math.max(
				0,
				math.floor(tonumber(record.members[memberKey]) or 0)
			) + 1
			trimTimestampMap(record.receipts, MAX_ATELIER_CONTRIBUTION_RECEIPTS)
			applied = true
		end
		record.updatedAt = os.time()
		return record
	end

	local record: any = nil
	if atelierStore then
		local ok, result = pcall(function()
			return atelierStore:UpdateAsync(key, apply)
		end)
		if not ok or type(result) ~= "table" then
			warn("[AuraRush/Social] Shared Atelier contribution deferred")
			return nil
		end
		record = result
	else
		record = apply(localAtelierWeeks[key])
		localAtelierWeeks[key] = record
	end
	syncLocalAtelierWeek(atelierId, record)
	if applied then
		services.Analytics.Log(player, "atelier_shared_contribution", 1, {
			period = tostring(period % 8),
		})
	end
	return record
end

local function featureEnabled(key: string): boolean
	local flags = services and services.Flags
	if flags and type(flags.IsEnabled) == "function" then
		return flags.IsEnabled(key)
	end
	local localFlags = config and config.FeatureFlags
	return type(localFlags) == "table" and localFlags[key] == true
end

local function remember(postcard: any): ()
	recentPostcards[postcard.id] = postcard
	table.insert(recentOrder, postcard.id)
	while #recentOrder > 60 do
		local removed = table.remove(recentOrder, 1)
		recentPostcards[removed] = nil
		reactions[removed] = nil
	end
end

local function findPostcard(player: Player, postcardId: string): any
	local recent = recentPostcards[postcardId]
	if recent then
		return recent
	end
	local profile = services.Data.GetProfile(player)
	if profile and type(profile.postcards) == "table" then
		for _, postcard in profile.postcards do
			if type(postcard) == "table" and postcard.id == postcardId then
				return postcard
			end
		end
	end
	return nil
end

local function createPostcard(player: Player): ()
	if services.Data.IsReadOnly(player) then
		services.Remote.FireClient("Toast", player, { key = "data_read_only", tone = "Warning" })
		return
	end
	local snapshot = services.Round.GetSnapshot(player)
	if
		type(snapshot) ~= "table"
		or (snapshot.state ~= "Finale" and snapshot.state ~= "Results")
		or snapshot.isParticipant ~= true
	then
		return
	end
	local activeRoundId = tostring(snapshot.roundId or "")
	if #activeRoundId == 0 or createdForRound[player] == activeRoundId then
		return
	end
	local brief = snapshot.brief
	local participants: { number } = {}
	if type(services.Round.GetParticipantUserIds) == "function" then
		participants = services.Round.GetParticipantUserIds()
	else
		participants = { player.UserId }
	end
	local postcard = {
		id = HttpService:GenerateGUID(false),
		createdAt = os.time(),
		ownerUserId = player.UserId,
		roundId = string.sub(activeRoundId, 1, 80),
		briefId = if type(brief) == "table" then tostring(brief.Id or brief.id or "") else "",
		worldId = if type(brief) == "table"
			then tostring(brief.WorldId or brief.worldId or "prism_metro")
			else "prism_metro",
		recipe = cloneLoadout(services.Style.GetLoadout(player)),
		-- Other participants are represented only as an aggregate until an
		-- explicit per-player tagging consent flow exists.
		participants = { player.UserId },
		participantCount = #participants,
		cover = "world_bloom",
	}
	local saved = services.Data.Update(player, function(profile: any)
		profile.postcards = profile.postcards or {}
		table.insert(profile.postcards, postcard)
		local maximum = tonumber(config.DataLimits.MaximumPostcards) or 24
		while #profile.postcards > maximum do
			table.remove(profile.postcards, 1)
		end
	end)
	if not saved then
		return
	end
	createdForRound[player] = activeRoundId
	remember(postcard)
	services.Remote.FireClient("PostcardUpdate", player, {
		kind = "Created",
		postcard = postcard,
	})
	services.Analytics.Funnel(player, "SocialCreation", activeRoundId, 1, "Postcard Created", {
		world = postcard.worldId,
	})
	fireMeta(player)
end

local function remixPostcard(player: Player, postcardId: string): ()
	local postcard = findPostcard(player, postcardId)
	if not postcard or type(postcard.recipe) ~= "table" then
		return
	end
	local equipped: { string } = {}
	local missing: { string } = {}
	for _, category in { "palette", "material", "aura", "pose", "accent" } do
		local itemId = postcard.recipe[category]
		local item = if type(itemId) == "string" then styleCatalog.GetById(itemId) else nil
		if item and item.category == category then
			local ok = services.Style.SetChoice(player, category, itemId)
			if ok then
				table.insert(equipped, itemId)
			else
				table.insert(missing, itemId)
			end
		end
	end
	services.Remote.FireClient("PostcardUpdate", player, {
		kind = "Remixed",
		postcardId = postcardId,
		equipped = equipped,
		missing = missing,
	})
	services.Analytics.Funnel(player, "SocialCreation", postcardId, 2, "Postcard Remixed", {
		missingCount = tostring(#missing),
	})
end

local function reactToPostcard(player: Player, postcardId: string, reaction: string): ()
	if not POSITIVE_REACTIONS[reaction] then
		return
	end
	local postcard = findPostcard(player, postcardId)
	if not postcard or postcard.ownerUserId == player.UserId then
		return
	end
	local byUser = reactions[postcardId]
	if not byUser then
		byUser = {}
		reactions[postcardId] = byUser
	end
	if byUser[player.UserId] then
		return
	end
	byUser[player.UserId] = reaction
	services.Remote.FireAll("PostcardUpdate", {
		kind = "Reaction",
		postcardId = postcardId,
		reaction = reaction,
	})
	services.Analytics.Log(player, "positive_postcard_reaction", 1, { reaction = reaction })
end

local function deletePostcard(player: Player, postcardId: string): ()
	if services.Data.IsReadOnly(player) then
		return
	end
	local removed = false
	services.Data.Update(player, function(profile: any)
		if type(profile.postcards) ~= "table" then
			return
		end
		for index = #profile.postcards, 1, -1 do
			local postcard = profile.postcards[index]
			if type(postcard) == "table" and postcard.id == postcardId then
				table.remove(profile.postcards, index)
				removed = true
				break
			end
		end
	end)
	if removed then
		recentPostcards[postcardId] = nil
		services.Remote.FireClient("PostcardUpdate", player, {
			kind = "Deleted",
			postcardId = postcardId,
		})
		fireMeta(player)
	end
end

local function createAtelier(player: Player): ()
	if services.Data.IsReadOnly(player) then
		return
	end
	local profile = services.Data.GetProfile(player)
	if
		profile
		and type(profile.atelier) == "table"
		and type(profile.atelier.id) == "string"
		and #profile.atelier.id > 0
	then
		return
	end
	local paletteId = services.Style.GetLoadout(player).palette
	services.Data.Update(player, function(editable: any)
		local blockedInviters = if type(editable.atelier) == "table"
				and type(editable.atelier.blockedInviters) == "table"
			then editable.atelier.blockedInviters
			else {}
		editable.atelier = {
			id = "atelier:" .. tostring(player.UserId),
			ownerUserId = player.UserId,
			role = "Founder",
			paletteId = paletteId,
			contributionPeriod = atelierWeek(),
			weeklyContribution = 0,
			personalWeeklyContribution = 0,
			joinedAt = os.time(),
			blockedInviters = blockedInviters,
		}
	end)
	services.Analytics.Log(player, "atelier_created", 1, nil)
	fireMeta(player)
	task.spawn(hydrateAtelierForPlayer, player)
end

local function inviteToAtelier(player: Player, targetUserId: number): ()
	local profile = services.Data.GetProfile(player)
	local atelier = if profile then profile.atelier else nil
	local role = if type(atelier) == "table" then string.lower(tostring(atelier.role or "")) else ""
	if
		type(atelier) ~= "table"
		or type(atelier.id) ~= "string"
		or atelier.id == ""
		or (role ~= "founder" and role ~= "moderator")
	then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	local targetProfile = services.Data.GetProfile(target)
	if
		targetProfile
		and type(targetProfile.atelier) == "table"
		and type(targetProfile.atelier.id) == "string"
		and targetProfile.atelier.id ~= ""
	then
		return
	end
	local now = os.time()
	local pending = pendingAtelierInvites[target]
	if pending and pending.expiresAt >= now then
		return
	end
	local blockedByTarget = atelierInviteBlocks[target]
	local blockedUntil = if blockedByTarget then blockedByTarget[player.UserId] or 0 else 0
	local persistedBlocks = if targetProfile and type(targetProfile.atelier) == "table"
		then targetProfile.atelier.blockedInviters
		else nil
	local persistedUntil = if type(persistedBlocks) == "table"
		then tonumber(persistedBlocks[tostring(player.UserId)]) or 0
		else 0
	if math.max(blockedUntil, persistedUntil) > now then
		return
	end
	local cooldownKey = invitationKey(player.UserId, target.UserId)
	if (atelierInviteCooldowns[cooldownKey] or 0) > now then
		return
	end
	atelierInviteCooldowns[cooldownKey] = now + ATELIER_INVITE_COOLDOWN_SECONDS
	pendingAtelierInvites[target] = {
		id = atelier.id,
		invitedBy = player.UserId,
		expiresAt = now + ATELIER_INVITE_SECONDS,
	}
	services.Remote.FireClient("MetaUpdate", target, {
		kind = "AtelierInvite",
		atelierId = atelier.id,
		fromUserId = player.UserId,
		fromDisplayName = player.DisplayName,
	})
end

local function acceptAtelier(player: Player, atelierId: string): ()
	local invite = pendingAtelierInvites[player]
	local profile = services.Data.GetProfile(player)
	local inviter = if invite then Players:GetPlayerByUserId(invite.invitedBy) else nil
	local inviterProfile = if inviter then services.Data.GetProfile(inviter) else nil
	local inviterAtelier = if inviterProfile then inviterProfile.atelier else nil
	local inviterRole = if type(inviterAtelier) == "table"
		then string.lower(tostring(inviterAtelier.role or ""))
		else ""
	if
		not invite
		or atelierId == ""
		or invite.id ~= atelierId
		or invite.expiresAt < os.time()
		or services.Data.IsReadOnly(player)
		or (profile and type(profile.atelier) == "table" and type(profile.atelier.id) == "string" and profile.atelier.id ~= "")
		or type(inviterAtelier) ~= "table"
		or inviterAtelier.id ~= invite.id
		or (inviterRole ~= "founder" and inviterRole ~= "moderator")
	then
		return
	end
	pendingAtelierInvites[player] = nil
	services.Data.Update(player, function(editable: any)
		local blockedInviters = if type(editable.atelier) == "table"
				and type(editable.atelier.blockedInviters) == "table"
			then editable.atelier.blockedInviters
			else {}
		editable.atelier = {
			id = invite.id,
			ownerUserId = math.max(
				0,
				math.floor(tonumber(inviterAtelier.ownerUserId) or invite.invitedBy)
			),
			role = "Member",
			paletteId = services.Style.GetLoadout(player).palette,
			contributionPeriod = atelierWeek(),
			weeklyContribution = 0,
			personalWeeklyContribution = 0,
			joinedAt = os.time(),
			blockedInviters = blockedInviters,
		}
	end)
	services.Analytics.Log(player, "atelier_joined", 1, nil)
	fireMeta(player)
	task.spawn(hydrateAtelierForPlayer, player)
end

local function declineAtelier(player: Player, blockInviter: boolean): ()
	local invite = pendingAtelierInvites[player]
	if not invite then
		return
	end
	pendingAtelierInvites[player] = nil
	if blockInviter then
		local blocked = atelierInviteBlocks[player]
		if not blocked then
			blocked = {}
			atelierInviteBlocks[player] = blocked
		end
		blocked[invite.invitedBy] = os.time() + ATELIER_INVITE_BLOCK_SECONDS
		if not services.Data.IsReadOnly(player) then
			services.Data.Update(player, function(profile: any)
				if type(profile.atelier) ~= "table" then
					profile.atelier = { id = "", role = "", joinedAt = 0 }
				end
				if type(profile.atelier.blockedInviters) ~= "table" then
					profile.atelier.blockedInviters = {}
				end
				profile.atelier.blockedInviters[tostring(invite.invitedBy)] = os.time()
					+ ATELIER_INVITE_BLOCK_SECONDS
			end)
		end
	end
	services.Analytics.Log(player, "atelier_invite_declined", 1, {
		blocked = tostring(blockInviter),
	})
	services.Remote.FireClient("MetaUpdate", player, { kind = "AtelierInviteDismissed" })
end

local function leaveAtelier(player: Player): ()
	if services.Data.IsReadOnly(player) then
		return
	end
	services.Data.Update(player, function(profile: any)
		local blockedInviters = if type(profile.atelier) == "table"
				and type(profile.atelier.blockedInviters) == "table"
			then profile.atelier.blockedInviters
			else {}
		profile.atelier = { id = "", role = "", joinedAt = 0, blockedInviters = blockedInviters }
	end)
	fireMeta(player)
end

local function scheduleAtelierHydration(player: Player): ()
	task.spawn(function()
		local deadline = os.clock() + 15
		while
			player.Parent == Players
			and not services.Data.IsLoaded(player)
			and os.clock() < deadline
		do
			task.wait(0.1)
		end
		if player.Parent == Players and services.Data.IsLoaded(player) then
			hydrateAtelierForPlayer(player)
		end
	end)
end

function SocialCreationService.Init(context: any): ()
	services = context.Services
	config = context.Config
	styleCatalog = context.StyleCatalog
	atelierStore = nil
	if not RunService:IsStudio() and game.GameId ~= 0 then
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore("AuraRush_AtelierWeeks_v1")
		end)
		if ok then
			atelierStore = store
		else
			warn("[AuraRush/Social] Shared Atelier store unavailable")
		end
	end
	services.Remote.BindEvent("PostcardAction", 2, function(player: Player, payload: any)
		if
			not featureEnabled("Postcards")
			or type(payload) ~= "table"
			or type(payload.action) ~= "string"
		then
			return
		end
		local action = payload.action
		local postcardId = payload.postcardId
		if action == "create" then
			createPostcard(player)
		elseif type(postcardId) == "string" and #postcardId <= 80 then
			if action == "remix" then
				remixPostcard(player, postcardId)
			elseif action == "react" and type(payload.reaction) == "string" then
				reactToPostcard(player, postcardId, payload.reaction)
			elseif action == "delete" then
				deletePostcard(player, postcardId)
			end
		end
	end)
	services.Remote.BindEvent("AtelierAction", 2, function(player: Player, payload: any)
		if
			not featureEnabled("Crews")
			or type(payload) ~= "table"
			or type(payload.action) ~= "string"
		then
			return
		end
		if payload.action == "create" then
			createAtelier(player)
		elseif payload.action == "invite" and type(payload.targetUserId) == "number" then
			inviteToAtelier(player, math.floor(payload.targetUserId))
		elseif payload.action == "accept" and type(payload.atelierId) == "string" then
			acceptAtelier(player, string.sub(payload.atelierId, 1, 80))
		elseif payload.action == "decline" then
			declineAtelier(player, false)
		elseif payload.action == "block_inviter" then
			declineAtelier(player, true)
		elseif payload.action == "leave" then
			leaveAtelier(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		createdForRound[player] = nil
		pendingAtelierInvites[player] = nil
		atelierInviteBlocks[player] = nil
		for target, invite in pendingAtelierInvites do
			if invite.invitedBy == player.UserId then
				pendingAtelierInvites[target] = nil
			end
		end
		local userIdText = tostring(player.UserId)
		for key in atelierInviteCooldowns do
			if
				string.find(key, userIdText .. ":", 1, true) == 1
				or string.find(key, ":" .. userIdText, 1, true) ~= nil
			then
				atelierInviteCooldowns[key] = nil
			end
		end
	end)
	Players.PlayerAdded:Connect(scheduleAtelierHydration)
	for _, player in Players:GetPlayers() do
		scheduleAtelierHydration(player)
	end
end

function SocialCreationService.RecordRoundContribution(player: Player): ()
	if services.Data.IsReadOnly(player) then
		return
	end
	local snapshot = if services.Round and type(services.Round.GetSnapshot) == "function"
		then services.Round.GetSnapshot(player)
		else nil
	local roundId = if type(snapshot) == "table" then tostring(snapshot.roundId or "") else ""
	if not qualifiedRound(player, roundId) then
		return
	end
	local profile = services.Data.GetProfile(player)
	local atelier = if profile then profile.atelier else nil
	if type(atelier) ~= "table" then
		return
	end
	local atelierSnapshot = {
		id = atelier.id,
		ownerUserId = atelier.ownerUserId,
	}
	task.spawn(recordSharedAtelierRound, player, atelierSnapshot, roundId)
end

function SocialCreationService.GetRecent(): { any }
	local result: { any } = {}
	for index = math.max(1, #recentOrder - 11), #recentOrder do
		local postcard = recentPostcards[recentOrder[index]]
		if postcard then
			local participantCount = if type(postcard.participantCount) == "number"
				then math.max(1, math.floor(postcard.participantCount))
				else if type(postcard.participants) == "table"
					then #postcard.participants
					else 1
			table.insert(result, {
				id = postcard.id,
				createdAt = postcard.createdAt,
				ownerUserId = postcard.ownerUserId,
				briefId = postcard.briefId,
				worldId = postcard.worldId,
				recipe = cloneLoadout(postcard.recipe),
				participantCount = participantCount,
				cover = postcard.cover,
			})
		end
	end
	return result
end

return SocialCreationService
