--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local StaffPolicy = require(sharedRoot:WaitForChild("StaffPolicy"))
type StaffRole = StaffPolicy.StaffRole

local AdminService = {}

type RoleCache = {
	role: StaffRole,
	expiresAt: number,
}

type AuditEntry = {
	id: number,
	at: number,
	actor: string,
	role: StaffRole,
	action: string,
	result: string,
	detail: string,
}

local services: any = nil
local gameConfig: any = nil
local adminConfig: any = nil
local roleCache: { [Player]: RoleCache } = {}
local actionCooldowns: { [Player]: number } = {}
local auditEntries: { AuditEntry } = {}
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local nextAuditId = 0
local startedAt = 0

local ROLE_CACHE_SECONDS = 60

local function positiveInteger(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value <= 0 then
		return fallback
	end
	return math.max(1, math.floor(value))
end

local function staffRole(player: Player, forceRefresh: boolean?): StaffRole
	local cached = roleCache[player]
	if not forceRefresh and cached and cached.expiresAt > os.clock() then
		return cached.role
	end
	local role = StaffPolicy.ResolveRole(player, adminConfig)
	roleCache[player] = {
		role = role,
		expiresAt = os.clock() + ROLE_CACHE_SECONDS,
	}
	player:SetAttribute("AuraRushStaffRole", role)
	return role
end

local function auditCapacity(): number
	return math.clamp(positiveInteger(adminConfig and adminConfig.AuditCapacity, 80), 10, 300)
end

local function record(
	player: Player,
	role: StaffRole,
	action: string,
	result: string,
	detail: string
): ()
	nextAuditId += 1
	table.insert(auditEntries, {
		id = nextAuditId,
		at = os.time(),
		actor = string.sub(player.DisplayName, 1, 48),
		role = role,
		action = string.sub(action, 1, 48),
		result = string.sub(result, 1, 32),
		detail = string.sub(detail, 1, 96),
	})
	while #auditEntries > auditCapacity() do
		table.remove(auditEntries, 1)
	end
end

local function getRuntimeValue(name: string, fallback: string): string
	local runtime = ReplicatedStorage:FindFirstChild("AuraRushRuntimeState")
	if not runtime then
		return fallback
	end
	local value = runtime:GetAttribute(name)
	return if type(value) == "string" and value ~= "" then value else fallback
end

local function networkSummary(): any
	local stats = if services
			and services.Remote
			and type(services.Remote.GetStats) == "function"
		then services.Remote.GetStats()
		else {}
	local accepted = 0
	local rejected = 0
	local outbound = 0
	for _, counter in stats do
		if type(counter) == "table" then
			accepted += math.max(0, math.floor(tonumber(counter.accepted) or 0))
			rejected += math.max(0, math.floor(tonumber(counter.rejected) or 0))
			outbound += math.max(0, math.floor(tonumber(counter.outbound) or 0))
		end
	end
	return {
		accepted = accepted,
		rejected = rejected,
		outbound = outbound,
	}
end

local function auditView(): { any }
	local result = {}
	for index = math.max(1, #auditEntries - 11), #auditEntries do
		local entry = auditEntries[index]
		if entry then
			table.insert(result, table.clone(entry))
		end
	end
	return result
end

local function persistenceSummary(): any
	local sources = {}
	local profile = if services
			and services.Data
			and type(services.Data.GetPersistenceDiagnostics) == "function"
		then services.Data.GetPersistenceDiagnostics()
		else {}
	sources.profiles = profile
	if
		services
		and services.Economy
		and type(services.Economy.GetReceiptPersistenceDiagnostics) == "function"
	then
		sources.receipts = services.Economy.GetReceiptPersistenceDiagnostics()
	end
	if
		services
		and services.SocialCreation
		and type(services.SocialCreation.GetSharedPersistenceDiagnostics) == "function"
	then
		sources.atelier = services.SocialCreation.GetSharedPersistenceDiagnostics()
	end
	if
		services
		and services.Community
		and type(services.Community.GetPersistenceDiagnostics) == "function"
	then
		sources.community = services.Community.GetPersistenceDiagnostics()
	end

	local summary = {
		requests = 0,
		attempts = 0,
		retries = 0,
		failures = 0,
		budgetWaits = 0,
		sources = sources,
	}
	for _, source in sources do
		if type(source) == "table" then
			summary.requests += math.max(0, math.floor(tonumber(source.requests) or 0))
			summary.attempts += math.max(0, math.floor(tonumber(source.attempts) or 0))
			summary.retries += math.max(0, math.floor(tonumber(source.retries) or 0))
			summary.failures += math.max(0, math.floor(tonumber(source.failures) or 0))
			summary.budgetWaits += math.max(0, math.floor(tonumber(source.budgetWaits) or 0))
		end
	end
	return summary
end

local function operationsView(): any
	local round = if services
			and services.Round
			and type(services.Round.GetOperationsView) == "function"
		then services.Round.GetOperationsView()
		else {}
	local performance = if services
			and services.Performance
			and type(services.Performance.GetSnapshot) == "function"
		then services.Performance.GetSnapshot()
		else {}
	return {
		server = {
			state = getRuntimeValue("ServerState", "unknown"),
			step = getRuntimeValue("ServerStep", "unknown"),
			detail = getRuntimeValue("ServerDetail", "Нет данных"),
			uptimeSeconds = math.max(0, math.floor(os.clock() - startedAt)),
			players = #Players:GetPlayers(),
			maximumPlayers = math.max(1, math.floor(tonumber(gameConfig.MaximumPlayers) or 12)),
		},
		round = round,
		performance = performance,
		network = networkSummary(),
		persistence = persistenceSummary(),
	}
end

local function findTemplate(templateId: string): any
	local templates = adminConfig and adminConfig.AnnouncementTemplates
	if type(templates) ~= "table" then
		return nil
	end
	for _, template in templates do
		if type(template) == "table" and template.id == templateId then
			return template
		end
	end
	return nil
end

local function cooldownSeconds(): number
	return math.clamp(
		positiveInteger(adminConfig and adminConfig.BroadcastCooldownSeconds, 20),
		5,
		300
	)
end

local function pushSnapshot(player: Player, kind: string, result: string?): ()
	services.Remote.FireClient("AdminUpdate", player, {
		kind = kind,
		result = result,
		data = AdminService.GetSnapshot(player),
	})
end

local function handleAction(player: Player, payload: any): ()
	local role = staffRole(player)
	if not StaffPolicy.Can(role, "view_dashboard") then
		return
	end
	if type(payload) ~= "table" or payload.action ~= "BroadcastTemplate" then
		record(player, role, "unknown", "rejected", "unsupported action")
		pushSnapshot(player, "ActionResult", "unsupported_action")
		return
	end
	if not StaffPolicy.Can(role, "broadcast_announcement") then
		record(player, role, "broadcast", "denied", "missing permission")
		pushSnapshot(player, "ActionResult", "permission_denied")
		return
	end
	if payload.confirmed ~= true or type(payload.templateId) ~= "string" then
		record(player, role, "broadcast", "rejected", "confirmation or template missing")
		pushSnapshot(player, "ActionResult", "confirmation_required")
		return
	end
	local templateId = string.sub(payload.templateId, 1, 48)
	local template = findTemplate(templateId)
	if
		type(template) ~= "table"
		or type(template.toastKey) ~= "string"
		or #template.toastKey == 0
	then
		record(player, role, "broadcast", "rejected", "template unavailable")
		pushSnapshot(player, "ActionResult", "template_unavailable")
		return
	end
	local now = os.clock()
	if (actionCooldowns[player] or 0) > now then
		record(player, role, "broadcast", "rejected", "cooldown")
		pushSnapshot(player, "ActionResult", "cooldown")
		return
	end
	actionCooldowns[player] = now + cooldownSeconds()
	services.Remote.FireAll("Toast", {
		key = template.toastKey,
		tone = if type(template.tone) == "string" then template.tone else "Info",
	})
	record(player, role, "broadcast", "accepted", templateId)
	if services.Analytics and type(services.Analytics.Log) == "function" then
		services.Analytics.Log(player, "admin_announcement", 1, { template = templateId })
	end
	pushSnapshot(player, "ActionResult", "ok")
end

function AdminService.GetSnapshot(player: Player): any
	local role = staffRole(player)
	if not StaffPolicy.Can(role, "view_dashboard") then
		return { authorized = false }
	end
	local snapshot = operationsView()
	snapshot.authorized = true
	snapshot.role = role
	snapshot.roleLabel = StaffPolicy.GetLabel(role)
	snapshot.permissions = StaffPolicy.GetPermissions(role)
	snapshot.generatedAt = os.time()
	snapshot.announcements = if StaffPolicy.Can(role, "broadcast_announcement")
		then adminConfig.AnnouncementTemplates
		else {}
	if StaffPolicy.Can(role, "view_audit") then
		snapshot.audit = auditView()
	end
	return snapshot
end

function AdminService.GetPolicySummary(): any
	return {
		enabled = type(adminConfig) == "table" and adminConfig.Enabled == true,
		auditCapacity = auditCapacity(),
		announcementCount = if type(adminConfig) == "table"
				and type(adminConfig.AnnouncementTemplates) == "table"
			then #adminConfig.AnnouncementTemplates
			else 0,
	}
end

function AdminService.Init(context: any): ()
	AdminService.Destroy()
	services = context.Services
	gameConfig = context.Config
	adminConfig = context.Config.Admin or { Enabled = false }
	startedAt = os.clock()
	playerAddedConnection = Players.PlayerAdded:Connect(function(player: Player)
		staffRole(player, true)
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		roleCache[player] = nil
		actionCooldowns[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		staffRole(player, true)
	end
	services.Remote.BindFunction("RequestAdminSnapshot", 1, function(player: Player, _payload: any)
		return AdminService.GetSnapshot(player)
	end)
	services.Remote.BindEvent("AdminAction", 1, handleAction)
end

function AdminService.Destroy(): ()
	if playerAddedConnection then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	table.clear(roleCache)
	table.clear(actionCooldowns)
	table.clear(auditEntries)
	nextAuditId = 0
	startedAt = 0
	services = nil
	gameConfig = nil
	adminConfig = nil
end

return AdminService
