--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CityPulseService = {}

local config: any = nil
local catalog: any = nil
local services: any = nil
local running = false
local eventIndex = 0
local currentEvent: any = nil
local progress = 0
local target = 10
local requiredContributors = 1
local startedAt = 0
local endsAt = 0
local completedAt = 0
local complete = false
local contributors: { [number]: boolean } = {}
local cooldowns: { [Player]: number } = {}
local impressionEventByUser: { [number]: string } = {}
local interactionEventByUser: { [number]: string } = {}
local connections: { RBXScriptConnection } = {}
local publishEpoch = 0
local progressPublishQueued = false
local lastProgressPublishAt = 0
local lifecycleEpoch = 0
local flagDisconnect: (() -> ())? = nil

local function featureEnabled(): boolean
	local flags = services and services.Flags
	if flags and type(flags.IsEnabled) == "function" then
		return flags.IsEnabled("CityPulse")
	end
	return type(config) == "table"
		and type(config.FeatureFlags) == "table"
		and config.FeatureFlags.CityPulse == true
end

local function rule(name: string, fallback: number): number
	local rules = catalog and catalog.PulseRules
	local value = if type(rules) == "table" then tonumber(rules[name]) else nil
	return if value and value == value then value else fallback
end

local function contributorCount(): number
	local count = 0
	for _ in contributors do
		count += 1
	end
	return count
end

local function analyticsLog(player: Player, eventName: string, value: number, fields: any): ()
	if services and services.Analytics and type(services.Analytics.Log) == "function" then
		services.Analytics.Log(player, eventName, value, fields)
	end
end

local function logImpression(player: Player): ()
	if not currentEvent or player.Parent ~= Players then
		return
	end
	local eventId = tostring(currentEvent.id)
	if impressionEventByUser[player.UserId] == eventId then
		return
	end
	impressionEventByUser[player.UserId] = eventId
	analyticsLog(player, "city_pulse_impression", 1, { eventId = eventId })
end

local function snapshot(): any
	local event = currentEvent
	local preferredPadNameRu = ""
	local preferredPadIndex = 0
	if event and catalog and type(catalog.PulsePads) == "table" then
		for index, definition in catalog.PulsePads do
			if definition.id == event.preferredPadId then
				preferredPadNameRu = tostring(definition.nameRu or "")
				preferredPadIndex = index
				break
			end
		end
	end
	return {
		version = 1,
		enabled = running and featureEnabled() and type(event) == "table",
		eventId = if event then event.id else "",
		nameRu = if event then event.nameRu else "Городской пульс",
		cueRu = if event then event.cueRu else "",
		accentHex = if event then event.accentHex else "D6FF49",
		preferredPadId = if event then event.preferredPadId else "",
		preferredPadNameRu = preferredPadNameRu,
		preferredPadIndex = preferredPadIndex,
		progress = progress,
		target = target,
		requiredContributors = requiredContributors,
		complete = complete,
		contributors = contributorCount(),
		startedAt = startedAt,
		endsAt = endsAt,
		serverNow = Workspace:GetServerTimeNow(),
	}
end

local function maximumUpdateRate(): number
	local budget = catalog and catalog.PerformanceBudget
	local configured = if type(budget) == "table"
		then tonumber(budget.maximumPulseUpdatesPerSecond)
		else nil
	return math.clamp(math.floor(configured or 8), 1, 30)
end

local function sendBroadcast(kind: string): ()
	if not services or not services.Remote or type(services.Remote.FireAll) ~= "function" then
		return
	end
	services.Remote.FireAll("RemixUpdate", {
		kind = kind,
		data = snapshot(),
	})
end

local function applyWorld(): ()
	if not services or not services.World or type(services.World.SetCityPulse) ~= "function" then
		return
	end
	local event = currentEvent
	services.World.SetCityPulse(
		math.clamp(progress / math.max(target, 1), 0, 1),
		if event then event.id else "",
		if event then event.accentHex else "D6FF49",
		complete,
		if event then event.preferredPadId else ""
	)
end

local function publish(kind: string): ()
	if kind ~= "CityPulseProgress" then
		-- Start/completion must be immediate and invalidate a delayed progress
		-- packet from the previous state or event.
		publishEpoch += 1
		progressPublishQueued = false
		lastProgressPublishAt = os.clock()
		applyWorld()
		sendBroadcast(kind)
		return
	end

	local now = os.clock()
	local interval = 1 / maximumUpdateRate()
	local remaining = interval - (now - lastProgressPublishAt)
	if remaining <= 0 then
		lastProgressPublishAt = now
		applyWorld()
		sendBroadcast(kind)
		return
	end
	if progressPublishQueued then
		return
	end

	progressPublishQueued = true
	local epoch = publishEpoch
	task.delay(remaining, function()
		if not running or epoch ~= publishEpoch then
			return
		end
		progressPublishQueued = false
		lastProgressPublishAt = os.clock()
		-- Snapshot and world visuals are read here, so multiple accepted touches
		-- coalesce into the newest authoritative state instead of going stale.
		applyWorld()
		sendBroadcast("CityPulseProgress")
	end)
end

local function startNextEvent(): ()
	local events = if catalog and type(catalog.PulseEvents) == "table"
		then catalog.PulseEvents
		else {}
	if #events == 0 then
		currentEvent = nil
		return
	end
	eventIndex = (eventIndex % #events) + 1
	currentEvent = events[eventIndex]
	progress = 0
	complete = false
	completedAt = 0
	table.clear(contributors)
	local playerCount = math.max(#Players:GetPlayers(), 1)
	requiredContributors =
		math.clamp(math.floor(rule("minimumContributorsWhenAvailable", 2)), 1, playerCount)
	target = math.clamp(
		math.floor(
			rule("baseTarget", 10) + (playerCount - 1) * rule("targetPerAdditionalPlayer", 2)
		),
		1,
		math.floor(rule("maximumTarget", 28))
	)
	startedAt = Workspace:GetServerTimeNow()
	endsAt = startedAt + math.max(15, rule("eventDurationSeconds", 75))
	publish("CityPulseStarted")
	for _, player in Players:GetPlayers() do
		logImpression(player)
	end
end

function CityPulseService.ResolveContribution(padId: string, preferredPadId: string): number
	local base = 1
	if padId ~= "" and padId == preferredPadId then
		base += math.max(0, math.floor(rule("preferredPadBonus", 1)))
	end
	return base
end

local function onPadTouched(pad: BasePart, hit: BasePart): ()
	if not running or complete or not featureEnabled() or not currentEvent then
		return
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = if character then Players:GetPlayerFromCharacter(character) else nil
	if not player or player.Parent ~= Players then
		return
	end
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - pad.Position).Magnitude > 13 then
		return
	end
	local now = os.clock()
	if now < (cooldowns[player] or 0) then
		return
	end
	cooldowns[player] = now + math.max(0.25, rule("actionCooldownSeconds", 0.8))
	local padId = tostring(pad:GetAttribute("PulsePadId") or "")
	local amount =
		CityPulseService.ResolveContribution(padId, tostring(currentEvent.preferredPadId or ""))
	local firstContribution = contributors[player.UserId] ~= true
	contributors[player.UserId] = true
	interactionEventByUser[player.UserId] = tostring(currentEvent.id)
	progress = math.min(target, progress + amount)
	if progress >= target and contributorCount() >= requiredContributors then
		complete = true
		completedAt = Workspace:GetServerTimeNow()
	end
	analyticsLog(player, "city_pulse_step", amount, {
		eventId = tostring(currentEvent.id),
		padId = padId,
		progressBucket = tostring(math.floor(progress / math.max(target, 1) * 4)),
	})
	if firstContribution then
		analyticsLog(player, "city_pulse_first_pad", 1, {
			eventId = tostring(currentEvent.id),
			padId = padId,
		})
	end
	if complete then
		for _, contributor in Players:GetPlayers() do
			if contributors[contributor.UserId] then
				analyticsLog(contributor, "city_pulse_complete", 1, {
					eventId = tostring(currentEvent.id),
					contributors = tostring(contributorCount()),
				})
			end
		end
	end
	publish(if complete then "CityPulseComplete" else "CityPulseProgress")
end

function CityPulseService.Init(context: any): ()
	CityPulseService.Stop()
	config = context.Config
	catalog = context.PremiumCityCatalog
	services = context.Services
	eventIndex = 0
	publishEpoch += 1
	progressPublishQueued = false
	lastProgressPublishAt = 0
	if services.Flags and type(services.Flags.OnChanged) == "function" then
		local restartContext = context
		local subscriptionEpoch = lifecycleEpoch
		flagDisconnect = services.Flags.OnChanged(function(key: string, _value: any)
			if key ~= "CityPulse" then
				return
			end
			task.defer(function()
				if flagDisconnect and subscriptionEpoch == lifecycleEpoch then
					CityPulseService.Init(restartContext)
				end
			end)
		end)
	end
	if not featureEnabled() or type(catalog) ~= "table" then
		return
	end
	local pads = if services.World and type(services.World.GetCityPulsePads) == "function"
		then services.World.GetCityPulsePads()
		else {}
	for _, pad in pads do
		if pad:IsA("BasePart") then
			table.insert(
				connections,
				pad.Touched:Connect(function(hit: BasePart)
					onPadTouched(pad, hit)
				end)
			)
		end
	end
	table.insert(
		connections,
		Players.PlayerAdded:Connect(function(player: Player)
			logImpression(player)
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			cooldowns[player] = nil
			impressionEventByUser[player.UserId] = nil
			interactionEventByUser[player.UserId] = nil
			-- PlayerRemoving still includes the departing player in GetPlayers().
			-- A remaining solo player must not wait for an absent second contributor.
			requiredContributors =
				math.min(requiredContributors, math.max(#Players:GetPlayers() - 1, 1))
			if contributors[player.UserId] then
				contributors[player.UserId] = nil
				publish("CityPulseProgress")
			end
		end)
	)
	running = true
	local epoch = lifecycleEpoch
	startNextEvent()
	task.spawn(function()
		while running and epoch == lifecycleEpoch do
			task.wait(0.5)
			if not running or epoch ~= lifecycleEpoch then
				break
			end
			local now = Workspace:GetServerTimeNow()
			if complete then
				if now - completedAt >= math.max(2, rule("celebrationSeconds", 7)) then
					startNextEvent()
				end
			elseif currentEvent and now >= endsAt then
				startNextEvent()
			end
		end
	end)
end

function CityPulseService.GetSnapshot(_player: Player?): any
	return snapshot()
end

function CityPulseService.GetMaximumUpdateRate(): number
	return maximumUpdateRate()
end

function CityPulseService.OnRunStarted(players: { Player }): ()
	for _, player in players do
		local eventId = interactionEventByUser[player.UserId]
		if eventId then
			analyticsLog(player, "city_pulse_next_run", 1, { eventId = eventId })
			interactionEventByUser[player.UserId] = nil
		end
	end
end

function CityPulseService.Stop(): ()
	local wasActive = running or currentEvent ~= nil
	running = false
	lifecycleEpoch += 1
	if flagDisconnect then
		flagDisconnect()
		flagDisconnect = nil
	end
	publishEpoch += 1
	progressPublishQueued = false
	lastProgressPublishAt = 0
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(contributors)
	table.clear(cooldowns)
	table.clear(impressionEventByUser)
	table.clear(interactionEventByUser)
	currentEvent = nil
	progress = 0
	requiredContributors = 1
	complete = false
	startedAt = 0
	endsAt = 0
	completedAt = 0
	if wasActive then
		-- A hot kill switch must clear already-visible client/world state now,
		-- even when no further round snapshot or pad touch ever arrives.
		applyWorld()
		sendBroadcast("CityPulseStopped")
	end
end

return CityPulseService
