--!strict

local Players = game:GetService("Players")

local SecretFrameService = {}

local config: any = nil
local catalog: any = nil
local services: any = nil
local promptConnections: { RBXScriptConnection } = {}
local playerRemovingConnection: RBXScriptConnection? = nil
local disconnectFlagListener: (() -> ())? = nil
local cooldowns: { [Player]: number } = {}

local function setting(name: string, fallback: number): number
	local section = config and config.SecretFrames
	local value = if type(section) == "table" then tonumber(section[name]) else nil
	return if value then value else fallback
end

local function enabled(): boolean
	if services and services.Flags and type(services.Flags.IsEnabled) == "function" then
		return services.Flags.IsEnabled("SecretFrames")
	end
	return config ~= nil and config.FeatureFlags.SecretFrames == true
end

local function definitionFor(frameId: string): any
	if catalog and type(catalog.GetSecretFrame) == "function" then
		return catalog.GetSecretFrame(frameId)
	end
	return nil
end

local function contains(values: any, target: string): boolean
	if type(values) ~= "table" then
		return false
	end
	return table.find(values, target) ~= nil
end

function SecretFrameService.IsDistanceAllowed(
	anchorPosition: Vector3,
	characterPosition: Vector3,
	maximumDistance: number,
	padding: number?
): boolean
	if typeof(anchorPosition) ~= "Vector3" or typeof(characterPosition) ~= "Vector3" then
		return false
	end
	local distance = math.clamp(tonumber(maximumDistance) or 0, 1, 50)
	local safePadding = math.clamp(tonumber(padding) or 0, 0, 8)
	return (characterPosition - anchorPosition).Magnitude <= distance + safePadding
end

function SecretFrameService.GetViewForProfile(profile: any): any
	local unlocked = if type(profile) == "table" then profile.photoModeUnlocks else nil
	local found = 0
	local total = if catalog and type(catalog.SecretFrames) == "table"
		then #catalog.SecretFrames
		else 0
	for _, definition in
		if catalog and type(catalog.SecretFrames) == "table" then catalog.SecretFrames else {}
	do
		if contains(unlocked, tostring(definition.id or "")) then
			found += 1
		end
	end
	return {
		version = 1,
		enabled = enabled(),
		foundCount = found,
		total = total,
		complete = total > 0 and found >= total,
	}
end

function SecretFrameService.GetView(player: Player): any
	local profile = if services and services.Data then services.Data.GetProfile(player) else nil
	return SecretFrameService.GetViewForProfile(profile)
end

local function toast(player: Player, key: string, tone: string, args: any?): ()
	services.Remote.FireClient("Toast", player, {
		key = key,
		tone = tone,
		args = args,
	})
end

local function addUnlock(profile: any, frameId: string): ()
	if type(profile.photoModeUnlocks) ~= "table" then
		profile.photoModeUnlocks = {}
	end
	if not contains(profile.photoModeUnlocks, frameId) then
		table.insert(profile.photoModeUnlocks, frameId)
	end
end

local function characterPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function handlePrompt(player: Player, prompt: ProximityPrompt): string
	if not enabled() or player.Parent ~= Players then
		return "disabled_or_invalid_player"
	end
	local now = os.clock()
	if now < (cooldowns[player] or 0) then
		return "cooldown"
	end
	cooldowns[player] = now + math.max(0.5, setting("ActionCooldownSeconds", 1.5))

	local anchor = prompt.Parent
	if
		not anchor
		or not anchor:IsA("BasePart")
		or anchor:GetAttribute("SecretFrameAnchor") ~= true
	then
		return "invalid_anchor"
	end
	local frameId = tostring(prompt:GetAttribute("SecretFrameId") or "")
	local definition = definitionFor(frameId)
	if not definition or not services then
		return "invalid_frame"
	end
	local rootPosition = characterPosition(player)
	if
		not rootPosition
		or not SecretFrameService.IsDistanceAllowed(
			anchor.Position,
			rootPosition,
			prompt.MaxActivationDistance,
			setting("DistancePaddingStuds", 3)
		)
	then
		return "too_far"
	end
	if not services.Data.IsLoaded(player) then
		toast(player, "profile_unavailable", "Warning", nil)
		return "profile_unavailable"
	end
	local profile = services.Data.GetProfile(player)
	if not profile then
		return "profile_unavailable"
	end
	local grantId = "secret_frame_v1:" .. frameId
	if
		contains(profile.photoModeUnlocks, frameId)
		or services.Economy.HasGrant(player, "system", grantId)
	then
		if not contains(profile.photoModeUnlocks, frameId) then
			services.Data.Update(player, function(editable: any)
				addUnlock(editable, frameId)
			end)
		end
		toast(player, "secret_frame_repeat", "Info", nil)
		return "already_found"
	end

	local cameraXp = math.max(0, math.floor(setting("DiscoveryCameraXp", 15)))
	local reward = math.max(0, math.floor(setting("DiscoveryGlowDust", 35)))
	local result = services.Economy.GrantCurrency(
		player,
		"system",
		grantId,
		reward,
		function(editable: any): any
			addUnlock(editable, frameId)
			return services.Progression.ApplySchoolXp(editable, "Camera", cameraXp)
		end
	)
	if result.ok ~= true then
		toast(player, "profile_unavailable", "Warning", nil)
		return "grant_failed"
	end
	if result.alreadyApplied == true then
		services.Data.Update(player, function(editable: any)
			addUnlock(editable, frameId)
		end)
		toast(player, "secret_frame_repeat", "Info", nil)
		return "already_found"
	end

	services.World.RevealSecretFrame(frameId)
	local view = SecretFrameService.GetView(player)
	local totalReward = math.max(0, math.floor(tonumber(result.amount) or 0))
	if result.amount > 0 then
		services.Analytics.Economy(
			player,
			true,
			result.amount,
			result.balance,
			"SecretFrameDiscovery",
			frameId,
			{ worldId = tostring(definition.worldId or "") }
		)
	end
	if view.complete then
		local bonus = services.Economy.GrantCurrency(
			player,
			"system",
			"secret_frame_collection_v1",
			math.max(0, math.floor(setting("CollectionBonusGlowDust", 120))),
			function(editable: any)
				if type(editable.achievements) ~= "table" then
					editable.achievements = {}
				end
				editable.achievements.secret_frame_collection = true
			end
		)
		if bonus.ok == true and bonus.alreadyApplied ~= true then
			totalReward += math.max(0, math.floor(tonumber(bonus.amount) or 0))
			services.Analytics.Economy(
				player,
				true,
				bonus.amount,
				bonus.balance,
				"SecretFrameCollection",
				"secret_frame_collection_v1",
				nil
			)
		end
	end

	services.Analytics.Log(player, "secret_frame_discovered", 1, {
		frameId = frameId,
		worldId = tostring(definition.worldId or ""),
		readOnly = result.readOnly == true,
	})
	toast(
		player,
		if view.complete then "secret_frame_collection_complete" else "secret_frame_found",
		"Success",
		{
			frame = tostring(definition.nameRu or "Секретный кадр"),
			amount = totalReward,
		}
	)
	if services.Meta and type(services.Meta.Push) == "function" then
		services.Meta.Push(player, "SecretFrames")
	end
	return if view.complete then "collection_complete" else "discovered"
end

function SecretFrameService.TryDiscover(player: Player, prompt: ProximityPrompt): string
	return handlePrompt(player, prompt)
end

local function setPromptAvailability(): ()
	local frameAnchors = if services and services.World
		then services.World.GetSecretFrames()
		else {}
	for _, anchor in frameAnchors do
		local prompt = anchor:FindFirstChild("SecretFramePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = enabled()
		end
	end
end

function SecretFrameService.Init(context: any): ()
	SecretFrameService.Destroy()
	config = context.Config
	catalog = context.PremiumCityCatalog
	services = context.Services
	for _, anchor in services.World.GetSecretFrames() do
		local prompt = anchor:FindFirstChild("SecretFramePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			table.insert(
				promptConnections,
				prompt.Triggered:Connect(function(player: Player)
					handlePrompt(player, prompt)
				end)
			)
		end
	end
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		cooldowns[player] = nil
	end)
	if services.Flags and type(services.Flags.OnChanged) == "function" then
		disconnectFlagListener = services.Flags.OnChanged(function(key: string, _value: any)
			if key == "SecretFrames" then
				setPromptAvailability()
			end
		end)
	end
	setPromptAvailability()
end

function SecretFrameService.Destroy(): ()
	for _, connection in promptConnections do
		connection:Disconnect()
	end
	table.clear(promptConnections)
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	if disconnectFlagListener then
		disconnectFlagListener()
		disconnectFlagListener = nil
	end
	table.clear(cooldowns)
end

return SecretFrameService
