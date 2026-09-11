--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local StyleService = {}

local dataService: any = nil
local remoteService: any = nil
local styleCatalog: any = nil
local economyService: any = nil
local progressionService: any = nil
local analyticsService: any = nil
local config: any = nil
local readyPlayers: { [Player]: boolean } = {}

local VALID_CATEGORIES: { [string]: boolean } = {
	palette = true,
	material = true,
	aura = true,
	pose = true,
	accent = true,
}

local FALLBACK_LOADOUT = {
	palette = "palette_prism",
	material = "material_smooth",
	aura = "aura_spark",
	pose = "pose_hero",
	accent = "accent_orbit",
}

local function getItem(itemId: string): any
	if type(styleCatalog.GetById) == "function" then
		return styleCatalog.GetById(itemId)
	end
	if type(styleCatalog.ById) == "table" then
		return styleCatalog.ById[itemId]
	end
	return nil
end

local function maximumItemIdLength(): number
	local networkLimits = config and config.NetworkLimits
	return math.max(
		1,
		math.floor(tonumber(networkLimits and networkLimits.MaximumItemIdLength) or 48)
	)
end

local function getCategory(item: any): string?
	if type(item) ~= "table" then
		return nil
	end
	local value = item.Category or item.category
	return if type(value) == "string" then string.lower(value) else nil
end

local function getDefaultLoadout(): { [string]: string }
	if type(styleCatalog.GetDefaultLoadout) == "function" then
		local result = styleCatalog.GetDefaultLoadout()
		if type(result) == "table" then
			return result
		end
	end
	return table.clone(FALLBACK_LOADOUT)
end

local function hasUnlocked(player: Player, category: string, itemId: string, item: any): boolean
	if item.IsStarter == true or item.isStarter == true then
		return true
	end
	if type(styleCatalog.IsStarter) == "function" and styleCatalog.IsStarter(itemId) then
		return true
	end
	local profile = dataService.GetProfile(player)
	if not profile then
		return false
	end
	local values = profile.unlocks[category]
	if type(values) ~= "table" then
		return false
	end
	for _, unlockedId in values do
		if unlockedId == itemId then
			return true
		end
	end
	return false
end

local function contains(values: { string }, target: string): boolean
	for _, value in values do
		if value == target then
			return true
		end
	end
	return false
end

local function sameLoadout(left: any, right: any): boolean
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for category in VALID_CATEGORIES do
		if left[category] ~= right[category] then
			return false
		end
	end
	return true
end

local function truncateUtf8(value: string, maximumCharacters: number): string
	local cutoff = utf8.offset(value, maximumCharacters + 1)
	return if cutoff then string.sub(value, 1, cutoff - 1) else value
end

local function filterLookName(player: Player, requestedName: string?, fallbackName: string): string
	if type(requestedName) ~= "string" then
		return fallbackName
	end
	local trimmed = string.gsub(requestedName, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return fallbackName
	end
	local maximum = if config and type(config.DataLimits) == "table"
		then math.clamp(math.floor(tonumber(config.DataLimits.MaximumLookNameLength) or 24), 1, 40)
		else 24
	trimmed = truncateUtf8(trimmed, maximum)
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(
			trimmed,
			player.UserId,
			Enum.TextFilterContext.PrivateChat
		)
		return result:GetNonChatStringForUserAsync(player.UserId)
	end)
	if not ok or type(filtered) ~= "string" or filtered == "" then
		return fallbackName
	end
	return truncateUtf8(filtered, maximum)
end

local function colorFromItem(item: any): Color3
	if type(item) == "table" then
		local direct = item.Color or item.PrimaryColor or item.color
		if typeof(direct) == "Color3" then
			return direct
		end
		local hex = item.ColorHex or item.colorHex
		if type(hex) == "string" then
			local normalized = string.gsub(hex, "#", "")
			local ok, result = pcall(Color3.fromHex, normalized)
			if ok then
				return result
			end
		end
	end
	return Color3.fromRGB(130, 72, 255)
end

local function materialFromItem(item: any): Enum.Material
	if type(item) == "table" then
		local value = item.Material or item.material
		if typeof(value) == "EnumItem" and value.EnumType == Enum.Material then
			return value
		end
		if type(value) == "string" then
			local enumValue = (Enum.Material :: any)[value]
			if enumValue then
				return enumValue
			end
		end
	end
	return Enum.Material.SmoothPlastic
end

local function weldAdornment(
	styleFolder: Folder,
	target: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Shape = shape or Enum.PartType.Block
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = target.CFrame * offset
	part.Parent = styleFolder

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function applyAdornment(
	character: Model,
	styleFolder: Folder,
	color: Color3,
	material: Enum.Material,
	accentItem: any
): ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")
	if not root or not root:IsA("BasePart") or not torso or not torso:IsA("BasePart") then
		return
	end

	local variant = if type(accentItem) == "table"
		then tostring(accentItem.Variant or accentItem.variant or accentItem.Id or "orbit")
		else "orbit"
	if string.find(string.lower(variant), "wing") then
		for side = -1, 1, 2 do
			local wing = weldAdornment(
				styleFolder,
				torso,
				"PrismWing",
				Vector3.new(0.6, 5.5, 2.3),
				CFrame.new(side * 2.2, 0.3, 1.2) * CFrame.Angles(0, 0, math.rad(side * -24)),
				color,
				Enum.Material.Glass
			)
			wing.Transparency = 0.22
		end
	elseif string.find(string.lower(variant), "crown") and head and head:IsA("BasePart") then
		for index = 1, 5 do
			local angle = (index / 5) * math.pi * 2
			weldAdornment(
				styleFolder,
				head,
				"CrownPrism",
				Vector3.new(0.45, 1.6, 0.45),
				CFrame.new(math.cos(angle) * 1.15, 1.25, math.sin(angle) * 1.15)
					* CFrame.Angles(0, 0, math.rad(12)),
				color,
				material
			)
		end
	else
		for index = 1, 3 do
			local angle = (index / 3) * math.pi * 2
			weldAdornment(
				styleFolder,
				root,
				"OrbitGem",
				Vector3.new(1.1, 1.1, 1.1),
				CFrame.new(math.cos(angle) * 3, 1 + index * 0.35, math.sin(angle) * 3),
				color,
				material,
				Enum.PartType.Ball
			)
		end
	end

	for side = -1, 1, 2 do
		local shoulder = weldAdornment(
			styleFolder,
			torso,
			"ShoulderPrism",
			Vector3.new(1.5, 0.7, 1.8),
			CFrame.new(side * (torso.Size.X * 0.55 + 0.5), torso.Size.Y * 0.28, 0)
				* CFrame.Angles(0, 0, math.rad(side * 18)),
			color,
			material
		)
		shoulder.Transparency = if material == Enum.Material.Glass then 0.2 else 0
	end
end

local function applyAura(character: Model, styleFolder: Folder, color: Color3, auraItem: any): ()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "AuraHighlight"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = color
	highlight.FillTransparency = 0.82
	highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.45)
	highlight.OutlineTransparency = 0.15
	highlight.Parent = styleFolder

	local variant = if type(auraItem) == "table"
		then tostring(auraItem.Variant or auraItem.variant or auraItem.Id or "spark")
		else "spark"
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "AuraParticles"
	particles.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.65))
	particles.LightEmission = 0.8
	particles.LightInfluence = 0
	particles.Lifetime = NumberRange.new(0.55, 1.15)
	particles.Rate = if string.find(string.lower(variant), "pulse") then 8 else 14
	particles.Rotation = NumberRange.new(0, 360)
	particles.RotSpeed = NumberRange.new(-60, 60)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.45, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Speed = NumberRange.new(0.4, 1.7)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = root

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "AuraTrailLow"
	attachment0.Position = Vector3.new(0, -1.5, 0)
	attachment0.Parent = root
	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "AuraTrailHigh"
	attachment1.Position = Vector3.new(0, 1.5, 0)
	attachment1.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "AuraTrail"
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 0.9
	trail.Lifetime = 0.2
	trail.MinLength = 0.1
	trail.Transparency = NumberSequence.new(0.25, 1)
	trail.Parent = styleFolder
end

function StyleService.Init(context: any): ()
	dataService = context.Services.Data
	remoteService = context.Services.Remote
	styleCatalog = context.StyleCatalog
	economyService = context.Services.Economy
	progressionService = context.Services.Progression
	analyticsService = context.Services.Analytics
	config = context.Config

	remoteService.BindEvent("SetStyle", 8, function(player: Player, payload: any)
		if type(payload) ~= "table" then
			return
		end
		local category = payload.category
		local itemId = payload.itemId
		if type(category) ~= "string" or type(itemId) ~= "string" then
			return
		end
		local ok, reason = StyleService.SetChoice(player, category, itemId)
		if not ok then
			remoteService.FireClient("Toast", player, { key = "style_rejected", detail = reason })
		end
	end)

	remoteService.BindEvent("UnlockStyle", 4, function(player: Player, payload: any)
		if type(payload) ~= "table" then
			return
		end
		local category = payload.category
		local itemId = payload.itemId
		if type(category) ~= "string" or type(itemId) ~= "string" then
			return
		end
		local ok, reason = StyleService.UnlockChoice(player, category, itemId)
		if not ok then
			remoteService.FireClient("Toast", player, { key = reason or "style_rejected" })
		end
	end)

	remoteService.BindEvent("SetStyleReady", 2, function(player: Player, payload: any)
		readyPlayers[player] = payload == true
			or (type(payload) == "table" and payload.ready == true)
	end)

	Players.PlayerRemoving:Connect(function(player)
		readyPlayers[player] = nil
	end)
end

function StyleService.UnlockChoice(
	player: Player,
	categoryValue: string,
	itemId: string
): (boolean, string?)
	local category = string.lower(categoryValue)
	if not VALID_CATEGORIES[category] or #itemId > maximumItemIdLength() then
		return false, "invalid_style"
	end
	local item = getItem(itemId)
	if not item or getCategory(item) ~= category then
		return false, "invalid_style"
	end
	if hasUnlocked(player, category, itemId, item) then
		return StyleService.SetChoice(player, category, itemId)
	end
	if dataService.IsReadOnly(player) then
		return false, "data_read_only"
	end

	local unlockKind = item.UnlockKind or item.unlockKind
	local cost = math.max(0, math.floor(tonumber(item.UnlockCost or item.price) or 0))
	local unlocked = false
	if unlockKind == "GlowDust" and cost > 0 then
		local transaction = economyService.SpendCurrency(
			player,
			"style:" .. itemId,
			cost,
			function(editable: any)
				local values = editable.unlocks[category]
				if type(values) ~= "table" then
					values = {}
					editable.unlocks[category] = values
				end
				if not contains(values, itemId) then
					table.insert(values, itemId)
				end
				editable.equipped[category] = itemId
				unlocked = true
			end
		)
		if transaction.ok ~= true or transaction.alreadyApplied == true or not unlocked then
			return false, transaction.reason or "style_transaction_rejected"
		end
		if analyticsService and type(analyticsService.Economy) == "function" then
			analyticsService.Economy(
				player,
				false,
				cost,
				transaction.balance,
				"CosmeticUnlock",
				itemId,
				{ category = category }
			)
		end
	elseif unlockKind == "Mastery" then
		local eligible, reason = progressionService.CanUnlockItem(player, item)
		if not eligible then
			return false, reason or "mastery_required"
		end
		local updated = dataService.Update(player, function(editable: any)
			local values = editable.unlocks[category]
			if type(values) ~= "table" then
				values = {}
				editable.unlocks[category] = values
			end
			if not contains(values, itemId) then
				table.insert(values, itemId)
			end
			editable.ledgers.grants.mastery["item:" .. itemId] = os.time()
			editable.equipped[category] = itemId
			unlocked = true
		end)
		if not updated or not unlocked then
			return false, "profile_unavailable"
		end
	else
		return false, "style_not_purchasable"
	end

	StyleService.ApplyToCharacter(player)
	remoteService.FireClient("ProgressUpdate", player, {
		kind = "Profile",
		profile = dataService.GetClientView(player),
	})
	remoteService.FireClient("Toast", player, { key = "style_unlocked" })
	return true, nil
end

function StyleService.SetChoice(
	player: Player,
	categoryValue: string,
	itemId: string
): (boolean, string?)
	local category = string.lower(categoryValue)
	if not VALID_CATEGORIES[category] or #itemId > maximumItemIdLength() then
		return false, "invalid_category"
	end
	local item = getItem(itemId)
	if not item or getCategory(item) ~= category then
		return false, "invalid_item"
	end
	if not hasUnlocked(player, category, itemId, item) then
		return false, "locked"
	end

	local updated = dataService.Update(player, function(profile: any)
		profile.equipped[category] = itemId
	end)
	if not updated then
		return false, "profile_unavailable"
	end
	StyleService.ApplyToCharacter(player)
	return true, nil
end

function StyleService.GetLoadout(player: Player): { [string]: string }
	local profile = dataService.GetProfile(player)
	if profile and type(profile.equipped) == "table" then
		local result = getDefaultLoadout()
		for category, itemId in profile.equipped do
			if type(category) == "string" and type(itemId) == "string" then
				result[category] = itemId
			end
		end
		return result
	end
	return getDefaultLoadout()
end

function StyleService.SaveLook(player: Player, requestedName: string?): (boolean, string?, string?)
	if dataService.IsReadOnly(player) then
		return false, "data_read_only", nil
	end
	local profile = dataService.GetProfile(player)
	if not profile then
		return false, "profile_unavailable", nil
	end
	local maximum = if config and type(config.DataLimits) == "table"
		then math.max(1, math.floor(tonumber(config.DataLimits.MaximumSavedLooks) or 8))
		else 8
	if #profile.savedLooks >= maximum then
		return false, "lookbook_full", nil
	end
	local loadout = StyleService.GetLoadout(player)
	for _, saved in profile.savedLooks do
		if type(saved) == "table" and sameLoadout(saved.loadout, loadout) then
			return false, "look_already_saved", saved.id
		end
	end

	local lookId = HttpService:GenerateGUID(false)
	local fallbackName = string.format("Look %d", #profile.savedLooks + 1)
	local filteredName = filterLookName(player, requestedName, fallbackName)
	local saved = false
	local updated = dataService.Update(player, function(editable: any)
		if #editable.savedLooks >= maximum then
			return
		end
		for _, existing in editable.savedLooks do
			if type(existing) == "table" and sameLoadout(existing.loadout, loadout) then
				return
			end
		end
		table.insert(editable.savedLooks, {
			id = lookId,
			name = filteredName,
			createdAt = os.time(),
			loadout = table.clone(loadout),
		})
		saved = true
	end)
	if not updated or not saved then
		return false, "look_save_rejected", nil
	end
	return true, nil, lookId
end

function StyleService.DeleteLook(player: Player, lookId: string): (boolean, string?)
	if dataService.IsReadOnly(player) then
		return false, "data_read_only"
	end
	if type(lookId) ~= "string" or #lookId > 80 then
		return false, "invalid_look"
	end
	local deleted = false
	local updated = dataService.Update(player, function(profile: any)
		for index, saved in profile.savedLooks do
			if type(saved) == "table" and saved.id == lookId then
				table.remove(profile.savedLooks, index)
				deleted = true
				break
			end
		end
	end)
	return updated and deleted, if deleted then nil else "look_not_found"
end

function StyleService.EquipSavedLook(player: Player, lookId: string): (boolean, string?)
	local profile = dataService.GetProfile(player)
	if not profile or type(lookId) ~= "string" then
		return false, "invalid_look"
	end
	local selected: any = nil
	for _, saved in profile.savedLooks do
		if type(saved) == "table" and saved.id == lookId then
			selected = saved
			break
		end
	end
	if not selected or type(selected.loadout) ~= "table" then
		return false, "look_not_found"
	end
	for category in VALID_CATEGORIES do
		local itemId = selected.loadout[category]
		local item = if type(itemId) == "string" then getItem(itemId) else nil
		if not item or not hasUnlocked(player, category, itemId, item) then
			return false, "look_contains_locked_item"
		end
	end
	local updated = dataService.Update(player, function(editable: any)
		for category in VALID_CATEGORIES do
			editable.equipped[category] = selected.loadout[category]
		end
	end)
	if not updated then
		return false, "profile_unavailable"
	end
	StyleService.ApplyToCharacter(player)
	return true, nil
end

function StyleService.ApplyToCharacter(player: Player): ()
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, childName in { "AuraParticles", "AuraTrailLow", "AuraTrailHigh" } do
			local child = root:FindFirstChild(childName)
			if child then
				child:Destroy()
			end
		end
	end
	local old = character:FindFirstChild("AuraRushStyle")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "AuraRushStyle"
	folder.Parent = character

	local loadout = StyleService.GetLoadout(player)
	local paletteItem = getItem(loadout.palette)
	local materialItem = getItem(loadout.material)
	local accentItem = getItem(loadout.accent)
	local auraItem = getItem(loadout.aura)
	local color = colorFromItem(paletteItem)
	local material = materialFromItem(materialItem)
	applyAdornment(character, folder, color, material, accentItem)
	applyAura(character, folder, color, auraItem)
	character:SetAttribute("AuraPose", loadout.pose or "pose_hero")
end

function StyleService.GetSummary(players: { Player }): any
	local red, green, blue, count = 0, 0, 0, 0
	local loadouts = {}
	for _, player in players do
		local loadout = StyleService.GetLoadout(player)
		loadouts[tostring(player.UserId)] = loadout
		local color = colorFromItem(getItem(loadout.palette))
		red += color.R
		green += color.G
		blue += color.B
		count += 1
	end
	local average = if count > 0
		then Color3.new(red / count, green / count, blue / count)
		else Color3.fromRGB(130, 72, 255)
	return { color = average, loadouts = loadouts }
end

function StyleService.IsReady(player: Player): boolean
	return readyPlayers[player] == true
end

function StyleService.ResetReady(): ()
	table.clear(readyPlayers)
end

return StyleService
