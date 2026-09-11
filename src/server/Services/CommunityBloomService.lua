--!strict

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

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
local pendingByEvent: { [string]: number } = {}
local totals: { [string]: number } = {}

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
	local amount = math.max(0, math.floor(pendingByEvent[eventId] or 0))
	if amount <= 0 then
		return
	end
	pendingByEvent[eventId] = 0
	if not durableStore then
		totals[eventId] = math.max(0, totals[eventId] or 0)
		return
	end
	local ok, result = pcall(function()
		return durableStore:UpdateAsync(eventKey(eventId), function(current: any)
			local previous = if type(current) == "table"
				then math.max(0, math.floor(tonumber(current.total) or 0))
				else 0
			return {
				total = previous + amount,
				updatedAt = os.time(),
				version = 1,
			}
		end)
	end)
	if not ok or type(result) ~= "table" then
		pendingByEvent[eventId] = (pendingByEvent[eventId] or 0) + amount
		warn("[AuraRush/CommunityBloom] Durable flush deferred")
		return
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
	local storeOk, record = pcall(function()
		return durableStore:GetAsync(eventKey(eventId))
	end)
	if storeOk and type(record) == "table" then
		local durableTotal = math.max(0, math.floor(tonumber(record.total) or 0))
		totals[eventId] = math.max(cachedTotal or 0, durableTotal)
	end
end

function CommunityBloomService.Init(context: any): ()
	services = context.Services
	config = context.Config
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
		pendingByEvent[eventId] = (pendingByEvent[eventId] or 0) + appliedAmount
		totals[eventId] = (totals[eventId] or 0) + appliedAmount
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

function CommunityBloomService.Stop(): ()
	running = false
	for eventId in pendingByEvent do
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
