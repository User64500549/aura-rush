--!strict

-- Server-side staff policy. This module deliberately has no client input: a
-- visible dashboard is never treated as proof that a player is staff.
local StaffPolicy = {}

export type StaffRole = "Player" | "Support" | "Moderator" | "Admin" | "Owner"

local ROLE_RANKS: { [StaffRole]: number } = table.freeze({
	Player = 0,
	Support = 10,
	Moderator = 20,
	Admin = 30,
	Owner = 40,
})

local ROLE_LABELS: { [StaffRole]: string } = table.freeze({
	Player = "Игрок",
	Support = "Поддержка",
	Moderator = "Модератор",
	Admin = "Администратор",
	Owner = "Владелец",
})

local ROLE_PERMISSIONS: { [StaffRole]: { [string]: boolean } } = table.freeze({
	Player = table.freeze({}),
	Support = table.freeze({
		view_dashboard = true,
		view_health = true,
	}),
	Moderator = table.freeze({
		view_dashboard = true,
		view_health = true,
		view_audit = true,
	}),
	Admin = table.freeze({
		view_dashboard = true,
		view_health = true,
		view_audit = true,
		broadcast_announcement = true,
	}),
	Owner = table.freeze({
		view_dashboard = true,
		view_health = true,
		view_audit = true,
		broadcast_announcement = true,
		manage_staff_policy = true,
	}),
})

local function positiveInteger(value: any): number
	if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

local function hasUserId(values: any, userId: number): boolean
	if type(values) ~= "table" then
		return false
	end
	for _, value in values do
		if positiveInteger(value) == userId then
			return true
		end
	end
	return false
end

local function configuredRank(config: any, name: string, fallback: number): number
	local ranks = if type(config) == "table" then config.GroupRanks else nil
	local value = positiveInteger(if type(ranks) == "table" then ranks[name] else nil)
	if value <= 0 then
		return fallback
	end
	return math.clamp(value, 1, 255)
end

local function groupRole(player: Player, config: any): StaffRole
	local groupId = positiveInteger(if type(config) == "table" then config.GroupId else nil)
	if groupId <= 0 then
		return "Player"
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(groupId)
	end)
	if not ok or type(rank) ~= "number" then
		return "Player"
	end
	local normalizedRank = math.clamp(math.floor(rank), 0, 255)
	local adminRank = configuredRank(config, "Admin", 200)
	local moderatorRank = configuredRank(config, "Moderator", 100)
	local supportRank = configuredRank(config, "Support", 50)
	if adminRank > 0 and normalizedRank >= adminRank then
		return "Admin"
	elseif moderatorRank > 0 and normalizedRank >= moderatorRank then
		return "Moderator"
	elseif supportRank > 0 and normalizedRank >= supportRank then
		return "Support"
	end
	return "Player"
end

function StaffPolicy.ResolveRole(player: Player, config: any): StaffRole
	if type(config) ~= "table" or config.Enabled ~= true then
		return "Player"
	end
	local userId = positiveInteger(player.UserId)
	if userId <= 0 then
		return "Player"
	end
	if hasUserId(config.OwnerUserIds, userId) then
		return "Owner"
	end
	local creatorTypeOk, creatorType = pcall(function()
		return game.CreatorType
	end)
	local creatorIdOk, creatorId = pcall(function()
		return game.CreatorId
	end)
	if
		creatorTypeOk
		and creatorIdOk
		and creatorType == Enum.CreatorType.User
		and positiveInteger(creatorId) == userId
	then
		return "Owner"
	end
	return groupRole(player, config)
end

function StaffPolicy.Can(role: StaffRole, permission: string): boolean
	return ROLE_PERMISSIONS[role][permission] == true
end

function StaffPolicy.GetPermissions(role: StaffRole): { string }
	local permissions = {}
	for permission, enabled in ROLE_PERMISSIONS[role] do
		if enabled then
			table.insert(permissions, permission)
		end
	end
	table.sort(permissions)
	return permissions
end

function StaffPolicy.GetRank(role: StaffRole): number
	return ROLE_RANKS[role]
end

function StaffPolicy.GetLabel(role: StaffRole): string
	return ROLE_LABELS[role]
end

function StaffPolicy.IsStaff(role: StaffRole): boolean
	return ROLE_RANKS[role] > 0
end

return table.freeze(StaffPolicy)
