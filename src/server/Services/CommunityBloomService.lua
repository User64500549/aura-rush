--!strict

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

local DataStoreOperation = require(script.Parent.Parent.Util.DataStoreOperation)

local CommunityBloomService = {}

local services: any = nil
local config: any = nil
local enabled = false
local flagService: any = nil
local manifestAllowed = true
local manifestReason: string? = nil
local durableStore: any = nil
local cache: any = nil
local subscription: any = nil
local running = false
local pendingByEvent: { [string]: { [string]: number } } = {}
local totals: { [string]: number } = {}
local persistenceConfig: any = nil
local durableDiagnostics = DataStoreOperation.NewDiagnostics()

local MAX_DURABLE_RECEIPTS = 1_000

local function validIdentifier(value: any, maximumLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maximumLength
end

local function isEnabled(): boolean
	return enabled
		and manifestAllowed
		and (
			not flagService
			or type(flagService.IsEnabled) ~= "function"
			or flagService.IsEnabled("CommunityBloom")
		)
end

local function isQualifiedRound(player: Player, contributionId: string): boolean
	if not services.Economy or type(services.Economy.HasGrant) ~= "function" then
		return false
	end
	return services.Economy.HasGrant(player, "system", "qualified_round:" .. contributionId)
end

local function milestoneScope(eventId: string, milestoneId: string): string
	if not services.LiveOps or type(services.LiveOps.GetManifest) ~= "function" then
		return "personal"
	end
	local activeManifest = services.LiveOps.GetManifest()
	for _, event in
		if type(activeManifest) == "table" and type(activeManifest.events) == "table"
			then activeManifest.events
			else {}
	do
		if type(event) == "table" and event.id == eventId and type(event.milestones) == "table" then
			for _, milestone in event.milestones do
				if type(milestone) == "table" and milestone.id == milestoneId then
					return if milestone.scope == "global" then "global" else "personal"
				end
			end
		end
	end
	return "personal"
end

local function eventKey(eventId: string): string
	return "event:" .. eventId
end

local function trimTimestampMap(values: { [string]: number }, maximum: number): ()
	local entries = {}
	for id, timestamp in values do
		table.insert(entries, { id = id, timestamp = tonumber(timestamp) or 0 })
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

local function normalizeEventRecord(current: any): any
	local record = if type(current) == "table" then current else {}
	record.total = math.max(0, math.floor(tonumber(record.total) or 0))
	record.receipts = if type(record.receipts) == "table" then record.receipts else {}
	return record
end

local function publish(eventId: string, total: number): ()
	if RunService:IsStudio() or game.GameId == 0 then
		return
	end
	pcall(function()
		MessagingService:PublishAsync(config.LiveOps.AnnouncementTopic, {
			eventId = eventId,
			total = total,
		})
	end)
end

local function flushEvent(eventId: string): ()
	local queued = pendingByEvent[eventId]
	if type(queued) ~= "table" or next(queued) == nil then
		return
	end
	local pending = table.clone(queued)
	if not durableStore then
		for contributionId, amount in pending do
			if queued[contributionId] == amount then
				queued[contributionId] = nil
			end
		end
		if next(queued) == nil then
			pendingByEvent[eventId] = nil
		end
		return
	end
	local ok, result = DataStoreOperation.Update(
		durableStore,
		eventKey(eventId),
		function(current: any): any
			local record = normalizeEventRecord(current)
			for contributionId, amount in pending do
				if record.receipts[contributionId] == nil then
					record.receipts[contributionId] = os.time()
					record.total += math.max(0, math.floor(tonumber(amount) or 0))
				end
			end
			trimTimestampMap(record.receipts, MAX_DURABLE_RECEIPTS)
			record.updatedAt = os.time()
			record.version = 2
			return record
		end,
		persistenceConfig,
		durableDiagnostics
	)
	if not ok or type(result) ~= "table" then
		warn("[AuraRush/CommunityBloom] Durable flush deferred")
		return
	end
	for contributionId, amount in pending do
		if queued[contributionId] == amount then
			queued[contributionId] = nil
		end
	end
	if next(queued) == nil then
		pendingByEvent[eventId] = nil
	end
	local total = math.max(0, math.floor(tonumber(result.total) or 0))
	totals[eventId] = total
	if cache then
		pcall(function()
			local cacheSeconds = if type(config.LiveOps) == "table"
				then math.max(15, math.floor(tonumber(config.LiveOps.MemoryCacheSeconds) or 45))
				else 45
			cache:SetAsync(eventKey(eventId), total, cacheSeconds)
		end)
	end
	publish(eventId, total)
end

local function hydrateEvent(eventId: string): ()
	local cachedTotal: number? = nil
	if cache then
		local cacheOk, cacheValue = pcall(function()
			return cache:GetAsync(eventKey(eventId))
		end)
		if cacheOk and type(cacheValue) == "number" then
			cachedTotal = math.max(0, math.floor(cacheValue))
			totals[eventId] = cachedTotal
		end
	end
	if not durableStore then
		return
	end
	local storeOk, record = DataStoreOperation.Read(
		durableStore,
		eventKey(eventId),
		persistenceConfig,
		durableDiagnostics
	)
	if storeOk and type(record) == "table" then
		local durableTotal = math.max(0, math.floor(tonumber(record.total) or 0))
		totals[eventId] = math.max(cachedTotal or 0, durableTotal)
	end
end

function CommunityBloomService.Init(context: any): ()
	CommunityBloomService.Stop()
	services = context.Services
	config = context.Config
	persistenceConfig = if type(config) == "table" then config.Persistence else nil
	durableDiagnostics = DataStoreOperation.NewDiagnostics()
	table.clear(pendingByEvent)
	table.clear(totals)
	durableStore = nil
	cache = nil
	local flags = config.FeatureFlags
	flagService = services.Flags
	enabled = type(flags) == "table" and flags.CommunityBloom == true
	manifestAllowed = true
	manifestReason = nil
	if
		type(context.LiveOpsManifest) == "table"
		and type(context.LiveOpsManifest.Validate) == "function"
	then
		local ok, valid, reason = pcall(context.LiveOpsManifest.Validate, context.Config)
		manifestAllowed = ok and valid == true
		manifestReason = if manifestAllowed then nil else tostring(if ok then reason else valid)
		if not manifestAllowed then
			warn("[AuraRush/CommunityBloom] Manifest rejected: " .. tostring(manifestReason))
		end
	end
	if not enabled or not manifestAllowed then
		return
	end
	if not RunService:IsStudio() and game.GameId ~= 0 then
		durableStore = DataStoreService:GetDataStore("AuraRush_CommunityBloom_v1")
		local cacheOk, cacheResult = pcall(function()
			return MemoryStoreService:GetHashMap("AuraRush_CommunityBloom_v1")
		end)
		if cacheOk then
			cache = cacheResult
		end
		local subscribed, result = pcall(function()
			return MessagingService:SubscribeAsync(
				config.LiveOps.AnnouncementTopic,
				function(message: any)
					local data = message.Data
					if
						type(data) == "table"
						and type(data.eventId) == "string"
						and type(data.total) == "number"
					then
						totals[data.eventId] =
							math.max(totals[data.eventId] or 0, math.floor(data.total))
					end
				end
			)
		end)
		if subscribed then
			subscription = result
		end
		if services.LiveOps and type(services.LiveOps.GetActiveEvents) == "function" then
			for _, event in services.LiveOps.GetActiveEvents() do
				if type(event) == "table" and type(event.id) == "string" then
					task.spawn(hydrateEvent, event.id)
				end
			end
		end
	end
	running = true
	task.spawn(function()
		while running do
			task.wait(20)
			for eventId in pendingByEvent do
				flushEvent(eventId)
			end
		end
	end)
end

function CommunityBloomService.Contribute(
	player: Player,
	eventId: string,
	contributionId: string,
	amountValue: number
): any
	if not isEnabled() or not services.LiveOps then
		return { ok = false, reason = "community_bloom_disabled" }
	end
	if not validIdentifier(eventId, 80) or not validIdentifier(contributionId, 100) then
		return { ok = false, reason = "invalid_contribution" }
	end
	if not isQualifiedRound(player, contributionId) then
		return {
			ok = false,
			reason = "participation_unqualified",
			globalTotal = totals[eventId] or 0,
		}
	end
	local amount = math.clamp(math.floor(tonumber(amountValue) or 0), 1, 100)
	local result = services.LiveOps.Contribute(player, eventId, contributionId, amount)
	local appliedAmount = if type(result.result) == "table"
		then math.max(0, math.floor(tonumber(result.result.contributed) or 0))
		else 0
	if result.ok == true and result.alreadyApplied ~= true then
		if appliedAmount > 0 then
			local receiptId = string.format("%d:%s", math.max(0, player.UserId), contributionId)
			local queued = pendingByEvent[eventId]
			if not queued then
				queued = {}
				pendingByEvent[eventId] = queued
			end
			if queued[receiptId] == nil then
				queued[receiptId] = appliedAmount
				totals[eventId] = (totals[eventId] or 0) + appliedAmount
			end
		end
	end
	return {
		ok = result.ok == true,
		alreadyApplied = result.alreadyApplied == true,
		personal = result.result,
		globalTotal = totals[eventId] or 0,
	}
end

function CommunityBloomService.ClaimMilestone(
	player: Player,
	eventId: string,
	milestoneId: string
): any
	if not isEnabled() or not services.LiveOps then
		return { ok = false, reason = "community_bloom_disabled" }
	end
	if not validIdentifier(eventId, 80) or not validIdentifier(milestoneId, 100) then
		return { ok = false, reason = "invalid_milestone" }
	end
	local globalTotal = math.max(0, math.floor(totals[eventId] or 0))
	local scope = milestoneScope(eventId, milestoneId)
	local result = services.LiveOps.ClaimMilestone(
		player,
		eventId,
		milestoneId,
		if scope == "global" then globalTotal else nil
	)
	result.globalTotal = globalTotal
	result.scope = scope
	return result
end

function CommunityBloomService.GetView(): any
	return {
		enabled = isEnabled(),
		manifestReason = manifestReason,
		totals = table.clone(totals),
	}
end

function CommunityBloomService.GetPersistenceDiagnostics(): any
	return DataStoreOperation.Snapshot(durableDiagnostics)
end

function CommunityBloomService.Stop(): ()
	running = false
	local pendingEventIds = {}
	for eventId in pendingByEvent do
		table.insert(pendingEventIds, eventId)
	end
	for _, eventId in pendingEventIds do
		flushEvent(eventId)
	end
	if subscription then
		pcall(function()
			subscription:Disconnect()
		end)
		subscription = nil
	end
end

return CommunityBloomService
