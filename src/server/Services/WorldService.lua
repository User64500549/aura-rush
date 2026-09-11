--!strict

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WorldService = {}

local WORLD_NAME = "AuraRushWorld"
local BLOOM_TAG = "AuraRushBloomable"
local COLLECTIBLE_TAG = "AuraRushThreadCollectible"

local rootModel: Model? = nil
local spawns: { [string]: CFrame } = {}
local activeRunSpawns: { [string]: CFrame } = {}
local collectibles: { BasePart } = {}
local activeRunCollectibles: { BasePart } = {}
local guardianAnchors: { [string]: BasePart } = {}
local heroLandmarks: { BasePart } = {}
local cityPulsePads: { BasePart } = {}
local cityPulseVisuals: { BasePart } = {}
local cityPulseCore: BasePart? = nil
local secretFrames: { BasePart } = {}
local secretFrameById: { [string]: BasePart } = {}
local glowstormToken = 0
local bloomToken = 0
local activeBloomRecipe: any = nil
local artDirectionRegistry: any = nil
local remixCatalog: any = nil
local premiumCityCatalog: any = nil

local ROUTE_PRESENTATION = {
	kinetic_cascade = {
		pattern = "cascade",
		accent = Color3.fromRGB(194, 255, 77),
		lateral = -6,
	},
	precision_atelier = {
		pattern = "precision_grid",
		accent = Color3.fromRGB(56, 232, 255),
		lateral = 0,
	},
	wild_remix = {
		pattern = "split_remix",
		accent = Color3.fromRGB(255, 107, 139),
		lateral = 6,
	},
	classic_bloom = {
		pattern = "classic",
		accent = Color3.fromRGB(140, 108, 255),
		lateral = 0,
	},
}

local PALETTE = {
	Ink = Color3.fromRGB(9, 12, 20),
	Deep = Color3.fromRGB(21, 26, 39),
	Purple = Color3.fromRGB(116, 97, 255),
	Pink = Color3.fromRGB(255, 105, 105),
	Cyan = Color3.fromRGB(78, 146, 255),
	Mint = Color3.fromRGB(194, 255, 77),
	Gold = Color3.fromRGB(226, 190, 94),
	White = Color3.fromRGB(246, 242, 229),
	Milk = Color3.fromRGB(246, 242, 229),
	Acid = Color3.fromRGB(194, 255, 77),
	Coral = Color3.fromRGB(255, 105, 105),
	ColdBlue = Color3.fromRGB(78, 146, 255),
	Chrome = Color3.fromRGB(180, 194, 207),
	Smoke = Color3.fromRGB(93, 103, 119),
}

local WORLD_RUSSIAN_NAMES = {
	prism_metro = "Призма-метро",
	cloud_bazaar = "Облачный квартал",
	moonlit_greenhouse = "Лунная оранжерея",
	orbital_boardwalk = "Орбитальная набережная",
	velvet_archive = "Бархатный архив",
	solar_cathedral = "Солнечный собор",
}

local function colorFromHex(hex: any, fallback: Color3): Color3
	if type(hex) == "string" then
		local ok, parsed = pcall(Color3.fromHex, hex)
		if ok then
			return parsed
		end
	end
	return fallback
end

local function stableHash(value: string): number
	local hash = 5381
	for index = 1, #value do
		hash = (hash * 33 + string.byte(value, index)) % 2147483646
	end
	return math.max(math.floor(hash), 1)
end

local function getArtProfile(worldId: string): any
	if artDirectionRegistry and type(artDirectionRegistry.GetWorld) == "function" then
		local ok, profile = pcall(artDirectionRegistry.GetWorld, worldId)
		if ok and type(profile) == "table" then
			return profile
		end
	end
	return nil
end

local function profileColor(profile: any, index: number, fallback: Color3): Color3
	if type(profile) == "table" and type(profile.palette) == "table" then
		return colorFromHex(profile.palette[index], fallback)
	end
	return fallback
end

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?
): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.Anchored = true
	item.CanCollide = if canCollide == nil then true else canCollide
	item.CanTouch = true
	item.CanQuery = true
	item.CastShadow = item.Material ~= Enum.Material.Neon
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function createWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	canCollide: boolean?
): WedgePart
	local item = Instance.new("WedgePart")
	item.Name = name
	item.Size = size
	item.CFrame = cframe
	item.Color = color
	item.Material = material or Enum.Material.SmoothPlastic
	item.Anchored = true
	item.CanCollide = if canCollide == nil then true else canCollide
	item.CanTouch = item.CanCollide
	item.CanQuery = true
	item.CastShadow = item.Material ~= Enum.Material.Neon
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function createDisc(
	parent: Instance,
	name: string,
	position: Vector3,
	radius: number,
	height: number,
	color: Color3
): Part
	local disc = createPart(
		parent,
		name,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.Material.SmoothPlastic
	)
	disc.Shape = Enum.PartType.Cylinder
	return disc
end

local function createSign(
	parent: Instance,
	adornee: BasePart,
	title: string,
	subtitle: string,
	accent: Color3?
): ()
	local resolvedAccent = accent or PALETTE.Acid
	adornee:SetAttribute("NavigationTitle", title)
	adornee:SetAttribute("NavigationHint", subtitle)
	adornee:SetAttribute("AccessibilityCue", "Текстовый указатель")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldLabel"
	billboard.AutoLocalize = false
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 64
	billboard.Size = UDim2.fromOffset(280, 84)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, math.clamp(adornee.Size.Y * 0.5 + 5, 7, 16), 0)
	billboard.Parent = parent

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = PALETTE.Ink
	panel.BackgroundTransparency = 0.03
	panel.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = PALETTE.Chrome
	stroke.Thickness = 1
	stroke.Transparency = 0.48
	stroke.Parent = panel

	local accentBar = Instance.new("Frame")
	accentBar.Name = "RouteColor"
	accentBar.BackgroundColor3 = resolvedAccent
	accentBar.BorderSizePixel = 0
	accentBar.Position = UDim2.fromOffset(0, 0)
	accentBar.Size = UDim2.new(0, 5, 1, 0)
	accentBar.Parent = panel
	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 12)
	accentCorner.Parent = accentBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(16, 7)
	titleLabel.Size = UDim2.new(1, -28, 0, 30)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = title
	titleLabel.TextColor3 = PALETTE.White
	titleLabel.TextSize = 20
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Parent = panel

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromOffset(16, 38)
	subtitleLabel.Size = UDim2.new(1, -28, 0, 36)
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(203, 207, 214)
	subtitleLabel.TextSize = 13
	subtitleLabel.TextWrapped = true
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = panel
end

local function createNumberCue(
	parent: Instance,
	adornee: BasePart,
	number: number,
	accent: Color3
): ()
	adornee:SetAttribute("ColorIndependentCue", `Площадка {number}`)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NumberCue"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 36
	billboard.Size = UDim2.fromOffset(54, 54)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	billboard.Parent = parent

	local numberLabel = Instance.new("TextLabel")
	numberLabel.BackgroundColor3 = PALETTE.Ink
	numberLabel.BackgroundTransparency = 0.04
	numberLabel.BorderSizePixel = 0
	numberLabel.Size = UDim2.fromScale(1, 1)
	numberLabel.Font = Enum.Font.GothamBold
	numberLabel.Text = tostring(number)
	numberLabel.TextColor3 = PALETTE.Milk
	numberLabel.TextSize = 28
	numberLabel.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = numberLabel
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 3
	stroke.Parent = numberLabel
end

local function tagBloomable(instance: BasePart, group: string): ()
	instance:SetAttribute("BloomGroup", group)
	instance:SetAttribute("BaseColor", instance.Color:ToHex())
	instance:SetAttribute("BaseMaterial", instance.Material.Name)
	instance:SetAttribute("BaseTransparency", instance.Transparency)
	instance:SetAttribute("BaseReflectance", instance.Reflectance)
	local owner: Instance? = instance
	while owner do
		local worldId = owner:GetAttribute("WorldId")
		if type(worldId) == "string" then
			instance:SetAttribute("WorldId", worldId)
			break
		end
		owner = owner.Parent
	end
	CollectionService:AddTag(instance, BLOOM_TAG)
end

local function tagBloomStory(
	instance: BasePart,
	group: string,
	revealStage: number,
	targetColor: Color3,
	targetTransparency: number?,
	targetMaterial: Enum.Material?
): ()
	tagBloomable(instance, group)
	instance:SetAttribute("BloomStoryRole", "DistrictReveal")
	instance:SetAttribute("BloomRevealStage", math.clamp(math.floor(revealStage), 1, 3))
	instance:SetAttribute("BloomTargetColor", targetColor:ToHex())
	instance:SetAttribute("BloomTargetTransparency", targetTransparency or 0)
	if targetMaterial then
		instance:SetAttribute("BloomTargetMaterial", targetMaterial.Name)
	end
end

local function tagLandmark(instance: BasePart, landmarkId: string): ()
	instance:SetAttribute("HeroLandmark", landmarkId)
	if not CollectionService:HasTag(instance, BLOOM_TAG) then
		tagBloomable(instance, "Landmark")
	end
	table.insert(heroLandmarks, instance)
end

local function configureStreamingZone(model: Model, zoneId: string): ()
	model:SetAttribute("ZoneId", zoneId)
	model:SetAttribute("StreamingFriendly", true)
	model:SetAttribute("ReducedMotionSafe", true)
	-- Atomic zones prevent a streamed-in challenge from arriving without its
	-- collision floor. Older engine builds safely keep the default behavior.
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
end

local function createWorldModel(root: Model, name: string, worldId: string): (Model, any)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("WorldId", worldId)
	model:SetAttribute("WorldNameRu", WORLD_RUSSIAN_NAMES[worldId] or worldId)
	model:SetAttribute("PresentationTier", "MobileFirst")
	model:SetAttribute("AccessibilityRoutes", true)
	model.Parent = root
	configureStreamingZone(model, worldId)

	local profile = getArtProfile(worldId)
	if type(profile) == "table" then
		model:SetAttribute("ArtProfileId", tostring(profile.id or worldId))
		model:SetAttribute("ArtAccentHex", tostring(profile.accentHex or ""))
		model:SetAttribute("SoundMotif", tostring(profile.soundMotif or ""))
		if type(profile.silhouetteLanguage) == "table" then
			model:SetAttribute("SilhouetteLanguage", table.concat(profile.silhouetteLanguage, ","))
		end
	end
	return model, profile
end

local function buildArch(parent: Instance, center: Vector3, width: number, color: Color3): ()
	local left = createPart(
		parent,
		"ArchLeft",
		Vector3.new(2, 18, 2),
		CFrame.new(center + Vector3.new(-width / 2, 9, 0)),
		PALETTE.Chrome,
		Enum.Material.Metal
	)
	local right = createPart(
		parent,
		"ArchRight",
		Vector3.new(2, 18, 2),
		CFrame.new(center + Vector3.new(width / 2, 9, 0)),
		PALETTE.Chrome,
		Enum.Material.Metal
	)
	local top = createPart(
		parent,
		"ArchTop",
		Vector3.new(width + 2, 2, 2),
		CFrame.new(center + Vector3.new(0, 18, 0)),
		color,
		Enum.Material.SmoothPlastic
	)
	tagLandmark(left, parent.Name .. "_arch")
	tagLandmark(right, parent.Name .. "_arch")
	tagLandmark(top, parent.Name .. "_arch")
end

local function createFinaleCamera(
	parent: Instance,
	worldId: string,
	position: Vector3,
	lookAt: Vector3
): ()
	local anchor = createPart(
		parent,
		"FinaleCamera_" .. worldId,
		Vector3.one,
		CFrame.lookAt(position, lookAt),
		PALETTE.White,
		Enum.Material.SmoothPlastic,
		false
	)
	anchor.Transparency = 1
	anchor.CanTouch = false
	anchor.CanQuery = false
end

local function createConnector(
	parent: Instance,
	name: string,
	from: Vector3,
	to: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
): Part
	local delta = to - from
	local connector = createPart(
		parent,
		name,
		Vector3.new(thickness, thickness, math.max(delta.Magnitude, 0.1)),
		CFrame.lookAt(from:Lerp(to, 0.5), to),
		color,
		material or Enum.Material.Neon,
		false
	)
	connector.CanTouch = false
	return connector
end

local function createRouteStripe(
	parent: Instance,
	name: string,
	from: Vector3,
	to: Vector3,
	color: Color3,
	width: number?
): Part
	local stripe =
		createConnector(parent, name, from, to, width or 1.2, color, Enum.Material.SmoothPlastic)
	stripe:SetAttribute("NavigationRoute", true)
	stripe:SetAttribute(
		"ColorIndependentCue",
		"Непрерывная напольная линия"
	)
	stripe.CastShadow = false
	return stripe
end

local function createGlowLamp(
	parent: Instance,
	name: string,
	position: Vector3,
	accent: Color3,
	height: number?,
	bloomGroup: string?
): Model
	local resolvedHeight = height or 7.5
	local resolvedGroup = bloomGroup or "Metro"
	local lamp = Instance.new("Model")
	lamp.Name = name
	lamp:SetAttribute("SetDressing", "TransitLamp")
	lamp:SetAttribute("VisualPriority", "Medium")
	lamp.Parent = parent

	local pole = createPart(
		lamp,
		"Pole",
		Vector3.new(0.55, resolvedHeight, 0.55),
		CFrame.new(position + Vector3.new(0, resolvedHeight * 0.5, 0)),
		PALETTE.Chrome,
		Enum.Material.Metal,
		false
	)
	pole.CanTouch = false
	tagBloomable(pole, resolvedGroup)
	local head = createPart(
		lamp,
		"Signal",
		Vector3.new(1.5, 0.7, 1.5),
		CFrame.new(position + Vector3.new(0, resolvedHeight + 0.15, 0)),
		accent,
		Enum.Material.Neon,
		false
	)
	head.CanTouch = false
	head.CastShadow = false
	tagBloomStory(head, resolvedGroup, 2, accent, 0, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Name = "LocalFill"
	light.Color = accent
	light.Brightness = 0.75
	light.Range = 18
	light.Shadows = false
	light.Parent = head
	return lamp
end

local function buildTransitFacade(
	parent: Instance,
	name: string,
	center: Vector3,
	side: number,
	height: number,
	accent: Color3,
	highlight: Color3
): Model
	local facade = Instance.new("Model")
	facade.Name = name
	facade:SetAttribute("ModularKit", "PrismTransitFacade")
	facade:SetAttribute("VisualPriority", "Medium")
	facade.Parent = parent

	local mass = createPart(
		facade,
		"FacadeMass",
		Vector3.new(9, height, 18),
		CFrame.new(center),
		Color3.fromRGB(20, 27, 40):Lerp(highlight, 0.07),
		Enum.Material.Concrete,
		true
	)
	mass:SetAttribute("CollisionProxy", true)
	tagBloomable(mass, "Metro")

	local faceX = center.X - side * 4.62
	local rowCount = math.clamp(math.floor((height - 6) / 5.6), 2, 4)
	for row = 1, rowCount do
		for column = 1, 2 do
			local window = createPart(
				facade,
				`Window_{row}_{column}`,
				Vector3.new(0.28, 3.35, 5.8),
				CFrame.new(
					faceX,
					center.Y - height * 0.5 + 4 + (row - 1) * 5.35,
					center.Z + (column == 1 and -4.2 or 4.2)
				),
				if (row + column) % 3 == 0 then highlight else accent,
				Enum.Material.Glass,
				false
			)
			window.Transparency = 0.32
			window.CastShadow = false
			window:SetAttribute("VisualPriority", "Low")
			tagBloomStory(window, "Metro", 2, accent, 0.12, Enum.Material.Glass)
		end
	end

	local spine = createPart(
		facade,
		"RouteSpine",
		Vector3.new(0.42, math.max(height - 5, 8), 0.7),
		CFrame.new(faceX - side * 0.12, center.Y, center.Z - 8.25),
		accent,
		Enum.Material.Neon,
		false
	)
	spine.CastShadow = false
	spine:SetAttribute("AmbientSignal", true)
	tagBloomStory(spine, "Metro", 3, highlight, 0, Enum.Material.Neon)

	local crown = createPart(
		facade,
		"RoofCrown",
		Vector3.new(10.5, 0.7, 19.5),
		CFrame.new(center + Vector3.new(0, height * 0.5 + 0.45, 0)),
		highlight,
		Enum.Material.Metal,
		false
	)
	crown.Transparency = 0.12
	tagBloomStory(crown, "Metro", 3, accent, 0.02, Enum.Material.Metal)
	return facade
end

local function buildHubFacade(
	parent: Instance,
	name: string,
	center: Vector3,
	width: number,
	height: number,
	accent: Color3
): Model
	local facade = Instance.new("Model")
	facade.Name = name
	facade:SetAttribute("ModularKit", "StylePlazaFacade")
	facade.Parent = parent
	local mass = createPart(
		facade,
		"BuildingMass",
		Vector3.new(width, height, 11),
		CFrame.new(center),
		Color3.fromRGB(22, 29, 43),
		Enum.Material.Concrete,
		true
	)
	tagBloomable(mass, "Hub")
	local columns = math.max(2, math.floor(width / 7))
	local rows = math.clamp(math.floor(height / 7), 2, 5)
	for row = 1, rows do
		for column = 1, columns do
			local x = center.X - width * 0.5 + (column - 0.5) * (width / columns)
			local y = center.Y - height * 0.5 + 4 + (row - 1) * 5.6
			local window = createPart(
				facade,
				`Window_{row}_{column}`,
				Vector3.new(math.max(width / columns - 1.6, 2.2), 3.2, 0.26),
				CFrame.new(x, y, center.Z - 5.62),
				accent:Lerp(PALETTE.Ink, 0.28 + ((row + column) % 3) * 0.16),
				Enum.Material.Glass,
				false
			)
			window.Transparency = 0.3
			window.CastShadow = false
			window:SetAttribute("VisualPriority", "Low")
			tagBloomable(window, "Hub")
		end
	end
	local roof = createPart(
		facade,
		"RoofSignal",
		Vector3.new(width + 1.2, 0.65, 12.2),
		CFrame.new(center + Vector3.new(0, height * 0.5 + 0.38, 0)),
		accent,
		Enum.Material.Neon,
		false
	)
	roof.CastShadow = false
	tagBloomable(roof, "Hub")
	return facade
end

local function buildActiveRunGeometry(runPlan: any): ()
	if not rootModel then
		return
	end
	local previous = rootModel:FindFirstChild("ActiveRunGeometry")
	if previous then
		previous:Destroy()
	end
	table.clear(activeRunSpawns)
	table.clear(activeRunCollectibles)
	if type(runPlan) ~= "table" or type(runPlan.acts) ~= "table" then
		return
	end

	local routeId = tostring(runPlan.selectedRouteId or "classic_bloom")
	local route = ROUTE_PRESENTATION[routeId] or ROUTE_PRESENTATION.classic_bloom
	local worldId = tostring(runPlan.worldId or "prism_metro")
	local container = Instance.new("Model")
	container.Name = "ActiveRunGeometry"
	container:SetAttribute("WorldId", worldId)
	container:SetAttribute("RouteId", routeId)
	container:SetAttribute("RoutePattern", route.pattern)
	container:SetAttribute("Seed", math.floor(tonumber(runPlan.seed) or 1))
	container:SetAttribute("Seamless", runPlan.seamless == true)
	container:SetAttribute("EncounterCellCount", #runPlan.acts)
	container.Parent = rootModel
	configureStreamingZone(container, `active_run_{routeId}`)

	local origin = Vector3.new(route.lateral, 16, -420)
	local chunkLength = 94

	for actIndex, act in runPlan.acts do
		if type(act) == "table" then
			local sceneId = tostring(act.sceneId or act.legacyPhase or "ThreadRun")
			local lateral = 0
			if route.pattern == "cascade" then
				lateral = if actIndex % 2 == 0 then 4 else -4
			elseif route.pattern == "split_remix" then
				lateral = if actIndex % 2 == 0 then -6 else 6
			end
			local stageOrigin = origin + Vector3.new(lateral, 0, -(actIndex - 1) * chunkLength)
			local routeSpawn = CFrame.new(stageOrigin + Vector3.new(0, 5, -4))
			do
				activeRunSpawns[sceneId] = routeSpawn
				activeRunSpawns[tostring(act.legacyPhase)] = routeSpawn

				local chunk = Instance.new("Model")
				chunk.Name = `RouteChunk_{actIndex}`
				chunk:SetAttribute("WorldId", worldId)
				chunk:SetAttribute("RouteId", routeId)
				chunk:SetAttribute("ActId", tostring(act.id or "act"))
				chunk:SetAttribute("Mechanic", tostring(act.semantic or "open"))
				chunk:SetAttribute("CellId", tostring(act.cellId or `open_cell_{actIndex}`))
				chunk:SetAttribute(
					"CellTitleRu",
					tostring(act.cellTitle or act.title or "Ремикс")
				)
				chunk:SetAttribute("CellShape", tostring(act.cellShape or "open"))
				chunk:SetAttribute("ArrivalPosition", routeSpawn.Position)
				chunk:SetAttribute("ArrivalDirection", routeSpawn.LookVector)
				chunk.Parent = container

				local mechanicTags = if type(act.mechanicTags) == "table"
					then table.concat(act.mechanicTags, ",")
					else ""
				chunk:SetAttribute("MechanicTags", mechanicTags)
				local floor = createPart(
					chunk,
					"RouteFloor",
					Vector3.new(26, 1.2, 88),
					CFrame.new(stageOrigin + Vector3.new(0, -0.8, -43)),
					PALETTE.Deep,
					Enum.Material.Asphalt,
					true
				)
				floor:SetAttribute("AccessibleRoute", true)
				tagBloomStory(floor, "Route", actIndex, route.accent, 0)

				createRouteStripe(
					chunk,
					"ContinuousGuide",
					stageOrigin + Vector3.new(0, -0.12, -2),
					stageOrigin + Vector3.new(0, -0.12, -85),
					route.accent,
					1.35
				)

				for side = -1, 1, 2 do
					local safetyRail = createConnector(
						chunk,
						`SafetyRail_{side}`,
						stageOrigin + Vector3.new(side * 12.25, 0.9, -2),
						stageOrigin + Vector3.new(side * 12.25, 0.9, -85),
						0.34,
						PALETTE.Chrome,
						Enum.Material.Metal
					)
					safetyRail:SetAttribute("RouteBoundary", true)
					safetyRail:SetAttribute("VisualPriority", "Medium")
					tagBloomable(safetyRail, "Route")

					for facadeIndex = 1, 3 do
						local height = 9 + ((facadeIndex + actIndex) % 3) * 4
						local routeFacade = createPart(
							chunk,
							`RouteFacade_{side}_{facadeIndex}`,
							Vector3.new(5.5, height, 13),
							CFrame.new(
								stageOrigin
									+ Vector3.new(
										side * 17.5,
										height * 0.5 - 0.15,
										-18 - (facadeIndex - 1) * 25
									)
							),
							PALETTE.Deep:Lerp(route.accent, 0.06 + facadeIndex * 0.035),
							Enum.Material.Concrete,
							true
						)
						routeFacade:SetAttribute("CollisionProxy", true)
						routeFacade:SetAttribute("VisualPriority", "Low")
						tagBloomable(routeFacade, "Route")
						local facadeSignal = createPart(
							chunk,
							`RouteWindow_{side}_{facadeIndex}`,
							Vector3.new(0.3, math.max(height - 3.5, 4), 7.5),
							CFrame.new(
								stageOrigin
									+ Vector3.new(
										side * 14.62,
										height * 0.52,
										-18 - (facadeIndex - 1) * 25
									)
							),
							if facadeIndex == 2 then PALETTE.Coral else route.accent,
							Enum.Material.Glass,
							false
						)
						facadeSignal.Transparency = 0.36
						facadeSignal.CastShadow = false
						tagBloomStory(
							facadeSignal,
							"Route",
							2,
							route.accent,
							0.12,
							Enum.Material.Glass
						)
					end
				end

				local exitCrown = createConnector(
					chunk,
					"RouteExitCrown",
					stageOrigin + Vector3.new(-10.5, 10, -84),
					stageOrigin + Vector3.new(10.5, 10, -84),
					0.72,
					route.accent,
					Enum.Material.Neon
				)
				exitCrown:SetAttribute("RouteMilestone", actIndex)
				tagBloomStory(exitCrown, "Route", 3, route.accent, 0, Enum.Material.Neon)

				for step = 1, 10 do
					local zig = if route.pattern == "cascade"
						then (if step % 2 == 0 then 3.2 else -3.2)
						else if route.pattern == "split_remix"
							then (if step <= 5 then -2.6 else 2.6)
							else 0
					local position = stageOrigin + Vector3.new(zig, -0.1, -step * 8)
					local tile = createPart(
						chunk,
						`RouteTile_{step}`,
						Vector3.new(
							if route.pattern == "precision_grid" then 5.2 else 6.4,
							0.24,
							5.4
						),
						CFrame.new(position),
						route.accent:Lerp(PALETTE.Ink, 0.38 + step * 0.035),
						if step % 3 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
						false
					)
					tile.CanTouch = false
					tile:SetAttribute("RouteStep", step)
					tile:SetAttribute("RoutePattern", route.pattern)
					tagBloomStory(
						tile,
						"Route",
						math.clamp(math.ceil(step / 4), 1, 3),
						route.accent,
						0.03
					)
				end

				local marker = createPart(
					chunk,
					"RouteMarker",
					Vector3.new(0.8, 7, 0.8),
					CFrame.new(stageOrigin + Vector3.new(-9.5, 4, -7)),
					route.accent,
					Enum.Material.Neon,
					false
				)
				marker.CanTouch = false
				marker:SetAttribute("RouteSelected", true)
				tagBloomable(marker, "Route")
				createSign(
					chunk,
					marker,
					`{actIndex}. {tostring(act.cellTitle or act.title or "Ремикс")}`,
					tostring(
						act.objective or "Двигайтесь по световой линии"
					),
					route.accent
				)

				if actIndex == 1 then
					for collectibleId = 1, 8 do
						local signalLane = if collectibleId % 2 == 1 then 1 else 2
						local x = if signalLane == 1 then -4.2 else 4.2
						local orb = createPart(
							chunk,
							`Signal_{collectibleId}`,
							Vector3.new(3.4, 3.4, 3.4),
							CFrame.new(stageOrigin + Vector3.new(x, 3.1, -8 - collectibleId * 8.6)),
							if signalLane == 1 then route.accent else PALETTE.Pink,
							Enum.Material.Neon,
							false
						)
						orb.Shape = Enum.PartType.Ball
						orb:SetAttribute("ChallengeAct", tostring(act.id or "thread_run"))
						orb:SetAttribute("CollectibleId", collectibleId)
						orb:SetAttribute("SignalLane", signalLane)
						orb:SetAttribute("ColorIndependentCue", `Сигнал {signalLane}`)
						CollectionService:AddTag(orb, COLLECTIBLE_TAG)
						table.insert(activeRunCollectibles, orb)
						createNumberCue(chunk, orb, collectibleId, orb.Color)
					end
				elseif actIndex == 2 then
					for pairIndex = 1, 4 do
						for side = -1, 1, 2 do
							local pad = createDisc(
								chunk,
								`DuetPad_{pairIndex}_{side}`,
								stageOrigin + Vector3.new(side * 5, 0.4, -12 - pairIndex * 15),
								3.4,
								0.7,
								if side < 0 then route.accent else PALETTE.Pink
							)
							pad.Material = Enum.Material.Neon
							pad:SetAttribute("DuetPair", pairIndex)
							pad:SetAttribute("ColorIndependentCue", `Пара {pairIndex}`)
						end
					end
				else
					local prismColors =
						{ PALETTE.Coral, PALETTE.ColdBlue, PALETTE.Acid, PALETTE.Purple }
					for lane = 1, 4 do
						local x = (lane - 2.5) * 4.8
						local pylon = createPart(
							chunk,
							`PalettePylon_{lane}`,
							Vector3.new(3.4, 9 + lane, 3.4),
							CFrame.new(stageOrigin + Vector3.new(x, 4.5, -45)),
							prismColors[lane],
							Enum.Material.Neon,
							false
						)
						pylon:SetAttribute("PaletteLane", lane)
						createNumberCue(chunk, pylon, lane, prismColors[lane])
					end
				end
			end
		end
	end
end

local function buildSegmentedArc(
	parent: Instance,
	name: string,
	transform: CFrame,
	radius: number,
	startAngle: number,
	endAngle: number,
	segments: number,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	group: string,
	revealStage: number?,
	targetColor: Color3?
): { Part }
	local result = table.create(segments)
	for index = 1, segments do
		local alpha0 = (index - 1) / segments
		local alpha1 = index / segments
		local angle0 = startAngle + (endAngle - startAngle) * alpha0
		local angle1 = startAngle + (endAngle - startAngle) * alpha1
		local from = transform:PointToWorldSpace(
			Vector3.new(math.cos(angle0) * radius, math.sin(angle0) * radius, 0)
		)
		local to = transform:PointToWorldSpace(
			Vector3.new(math.cos(angle1) * radius, math.sin(angle1) * radius, 0)
		)
		local segment =
			createConnector(parent, name .. "_" .. index, from, to, thickness, color, material)
		segment:SetAttribute("VisualPriority", "Medium")
		if revealStage then
			-- Preserve translucency only where the authored material is actually
			-- glass. Metal, marble and plastic rings read better as solid
			-- silhouettes and avoiding dozens of overlapping alpha surfaces keeps
			-- the six streamed districts inexpensive on mobile GPUs.
			local usesLayeredAlpha = material == Enum.Material.Glass
			segment.Transparency = if usesLayeredAlpha then 0.28 else 0
			tagBloomStory(
				segment,
				group,
				revealStage,
				targetColor or color,
				if usesLayeredAlpha then 0.04 else 0,
				material
			)
		else
			tagBloomable(segment, group)
		end
		table.insert(result, segment)
	end
	return result
end

local function createCompactWorldLabel(
	parent: Instance,
	adornee: BasePart,
	title: string,
	subtitle: string,
	accent: Color3
): ()
	adornee:SetAttribute("NavigationTitle", title)
	adornee:SetAttribute("NavigationHint", subtitle)
	adornee:SetAttribute("AccessibilityCue", `Маяк района: {title}`)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DistrictLabel"
	billboard.AutoLocalize = false
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 52
	billboard.Size = UDim2.fromOffset(258, 70)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	billboard.Parent = parent

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = PALETTE.Ink
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = panel

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(12, 5)
	titleLabel.Size = UDim2.new(1, -24, 0, 31)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = title
	titleLabel.TextColor3 = PALETTE.Milk
	titleLabel.TextSize = 18
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = panel

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromOffset(12, 35)
	subtitleLabel.Size = UDim2.new(1, -24, 0, 25)
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = accent:Lerp(PALETTE.Milk, 0.42)
	subtitleLabel.TextSize = 12
	subtitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = panel
end

local function createPulsePadLabel(
	parent: Instance,
	adornee: BasePart,
	text: string,
	accent: Color3
): ()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PulsePadLabel"
	billboard.AutoLocalize = false
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 34
	billboard.Size = UDim2.fromOffset(164, 34)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0)
	billboard.Parent = parent

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = PALETTE.Ink
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.5
	stroke.Transparency = 0.12
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.GothamBold
	title.Text = text
	title.TextColor3 = PALETTE.Milk
	title.TextSize = 14
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = panel
end

local function buildSecretFrame(
	parent: Instance,
	gateFrame: CFrame,
	definition: any,
	index: number,
	accent: Color3
): ()
	local frameId = tostring(definition.id or "")
	if frameId == "" or secretFrameById[frameId] then
		return
	end
	local side = if tonumber(definition.side) and tonumber(definition.side) < 0 then -1 else 1
	local frameCFrame = gateFrame
		* CFrame.new(side * 8.4, 3.2, 2.8)
		* CFrame.Angles(0, math.rad(side * 12), 0)
	local model = Instance.new("Model")
	model.Name = `SecretFrame_{frameId}`
	model:SetAttribute("SecretFrame", true)
	model:SetAttribute("SecretFrameId", frameId)
	model:SetAttribute("WorldId", tostring(definition.worldId or ""))
	model:SetAttribute("NameRu", tostring(definition.nameRu or "Секретный кадр"))
	model:SetAttribute(
		"HintRu",
		tostring(definition.hintRu or "Ищи световую рамку")
	)
	model:SetAttribute("FrameIndex", index)
	model:SetAttribute("RevealToken", 0)
	model.Parent = parent

	local center = createPart(
		model,
		"DiscoverySurface",
		Vector3.new(4.2, 4.8, 0.18),
		frameCFrame,
		accent:Lerp(PALETTE.Ink, 0.35),
		Enum.Material.Glass,
		false
	)
	center.Transparency = 0.76
	center.CanTouch = false
	center.CastShadow = false
	center:SetAttribute("SecretFrameAnchor", true)
	center:SetAttribute("SecretFrameId", frameId)
	center:SetAttribute("WorldId", tostring(definition.worldId or ""))
	center:SetAttribute("BaseColor", center.Color:ToHex())
	center:SetAttribute("BaseTransparency", center.Transparency)
	model.PrimaryPart = center

	local edgeDefinitions = {
		{ name = "Top", size = Vector3.new(5.1, 0.38, 0.38), offset = Vector3.new(0, 2.6, 0) },
		{
			name = "Bottom",
			size = Vector3.new(5.1, 0.38, 0.38),
			offset = Vector3.new(0, -2.6, 0),
		},
		{ name = "Left", size = Vector3.new(0.38, 5.55, 0.38), offset = Vector3.new(-2.36, 0, 0) },
		{ name = "Right", size = Vector3.new(0.38, 5.55, 0.38), offset = Vector3.new(2.36, 0, 0) },
	}
	for _, edgeDefinition in edgeDefinitions do
		local edge = createPart(
			model,
			"Frame" .. edgeDefinition.name,
			edgeDefinition.size,
			frameCFrame * CFrame.new(edgeDefinition.offset),
			accent,
			Enum.Material.Neon,
			false
		)
		edge.CanTouch = false
		edge.CastShadow = false
		edge:SetAttribute("SecretFrameEdge", true)
		edge:SetAttribute("BaseColor", edge.Color:ToHex())
	end

	local glyphGui = Instance.new("SurfaceGui")
	glyphGui.Name = "FrameGlyph"
	glyphGui.Adornee = center
	glyphGui.AlwaysOnTop = false
	glyphGui.Face = Enum.NormalId.Front
	glyphGui.LightInfluence = 0
	glyphGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	glyphGui.PixelsPerStud = 28
	glyphGui.Parent = model
	local glyph = Instance.new("TextLabel")
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Font = Enum.Font.GothamBold
	glyph.Text = "◇"
	glyph.TextColor3 = accent:Lerp(PALETTE.Milk, 0.35)
	glyph.TextScaled = true
	glyph.TextTransparency = 0.25
	glyph.Parent = glyphGui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SecretFramePrompt"
	prompt.ActionText = "Поймать кадр"
	prompt.ObjectText = tostring(definition.nameRu or "Секретный кадр")
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = true
	prompt.ClickablePrompt = true
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("AuraRushSecretFrame", true)
	prompt:SetAttribute("SecretFrameId", frameId)
	prompt.Parent = center

	table.insert(secretFrames, center)
	secretFrameById[frameId] = center
end

local function buildPremiumCityLayer(hub: Model): ()
	if type(premiumCityCatalog) ~= "table" then
		return
	end
	local premium = Instance.new("Model")
	premium.Name = "PremiumCityLayer"
	premium:SetAttribute("Layout", "six_district_ring")
	premium:SetAttribute("MapDesignVersion", 7)
	premium:SetAttribute("NavigationLanguage", "ru")
	premium:SetAttribute("DecorMotion", "client_local_only")
	premium:SetAttribute("SecretFrameVersion", 1)
	premium.Parent = hub

	local heart = Instance.new("Model")
	heart.Name = "HeartOfStyle"
	heart:SetAttribute("HeroLandmark", "heart_of_style")
	heart:SetAttribute("InteractiveSystem", "CityPulse")
	heart.Parent = premium
	local heartCenter = Vector3.new(0, 16, 9)
	local heartColors = {
		PALETTE.ColdBlue,
		PALETTE.Coral,
		PALETTE.Acid,
		PALETTE.Purple,
		PALETTE.Gold,
		Color3.fromRGB(148, 210, 189),
	}
	for index, color in heartColors do
		local angle = (index - 1) / #heartColors * math.pi * 2
		local function ribbonPoint(t: number): Vector3
			local radius = 4.6 + 1.6 * t - math.sin(t * math.pi) * 3.1
			local turn = angle + t * 1.6
			return heartCenter
				+ Vector3.new(math.cos(turn) * radius, -7.5 + t * 18, math.sin(turn) * radius)
		end
		for segmentIndex = 1, 10 do
			local ribbon = createConnector(
				heart,
				`HeartRibbon_{index}_{segmentIndex}`,
				ribbonPoint((segmentIndex - 1) / 10),
				ribbonPoint(segmentIndex / 10),
				1.7,
				color,
				Enum.Material.Metal
			)
			ribbon.Transparency = 0
			ribbon.CastShadow = false
			ribbon:SetAttribute("CityPulseVisual", true)
			ribbon:SetAttribute("PulseBaseColor", color:ToHex())
			ribbon:SetAttribute("PulseBaseTransparency", ribbon.Transparency)
			tagBloomStory(
				ribbon,
				"Hub",
				if segmentIndex <= 5 then 2 else 3,
				color,
				0,
				Enum.Material.Metal
			)
			table.insert(cityPulseVisuals, ribbon)
		end
	end

	local legacyCore = hub:FindFirstChild("SignatureCore", true)
	if legacyCore and legacyCore:IsA("BasePart") then
		legacyCore.Name = "SignatureCore"
		legacyCore:SetAttribute("CityPulseCore", true)
		legacyCore:SetAttribute("PulseBaseColor", legacyCore.Color:ToHex())
		cityPulseCore = legacyCore
		table.insert(cityPulseVisuals, legacyCore)
	end

	local ringTransform = CFrame.new(0, 13.5, 9) * CFrame.Angles(math.rad(90), 0, 0)
	for trackIndex, radius in { 54.5, 57.5 } do
		local railSegments = buildSegmentedArc(
			premium,
			`PrismRail_{trackIndex}`,
			ringTransform,
			radius,
			0,
			math.pi * 2,
			36,
			0.52,
			if trackIndex == 1 then PALETTE.ColdBlue else PALETTE.Purple,
			Enum.Material.Metal,
			"Hub"
		)
		for _, segment in railSegments do
			segment:SetAttribute("TransitRing", true)
			segment:SetAttribute("VisualPriority", "Medium")
			segment.CastShadow = false
		end
	end

	buildSegmentedArc(
		premium,
		"GroundCityLoop",
		CFrame.new(0, 2.25, 9) * CFrame.Angles(math.rad(90), 0, 0),
		45.5,
		0,
		math.pi * 2,
		42,
		0.72,
		PALETTE.Chrome,
		Enum.Material.SmoothPlastic,
		"Hub"
	)

	for supportIndex = 1, 12 do
		local angle = (supportIndex - 1) / 12 * math.pi * 2
		local position = Vector3.new(math.cos(angle) * 56, 7.6, 9 + math.sin(angle) * 56)
		local support = createPart(
			premium,
			`RailSupport_{supportIndex}`,
			Vector3.new(0.72, 10.8, 0.72),
			CFrame.new(position),
			PALETTE.Chrome,
			Enum.Material.Metal,
			false
		)
		support.CastShadow = false
		support:SetAttribute("VisualPriority", "Low")
		tagBloomable(support, "Hub")
	end

	local districts = premiumCityCatalog.Districts
	for index, definition in if type(districts) == "table" then districts else {} do
		local angle = math.rad(tonumber(definition.angleDegrees) or ((index - 1) * 60))
		local outward = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local center = Vector3.new(0, 2.3, 9) + outward * 58
		local gateFrame = CFrame.lookAt(center, Vector3.new(0, center.Y, 9))
		local accent = colorFromHex(definition.accentHex, PALETTE.Acid)
		local gate = Instance.new("Model")
		gate.Name = "DistrictGateway_" .. tostring(definition.id)
		gate:SetAttribute("DistrictGateway", true)
		gate:SetAttribute("WorldId", tostring(definition.id))
		gate:SetAttribute("GatewayPurpose", "RunPreview")
		gate:SetAttribute("GatewayIndex", index)
		gate.Parent = premium

		local platform = createPart(
			gate,
			"GatewayPlatform",
			Vector3.new(15, 0.45, 9),
			gateFrame * CFrame.new(0, 0.1, 0),
			PALETTE.Deep,
			Enum.Material.Concrete,
			true
		)
		platform:SetAttribute("NavigationDestination", tostring(definition.id))
		tagBloomable(platform, "Hub")
		for side = -1, 1, 2 do
			local pylon = createPart(
				gate,
				if side < 0 then "GatewayLeft" else "GatewayRight",
				Vector3.new(1.25, 11, 1.8),
				gateFrame * CFrame.new(side * 5.5, 5.5, 0),
				if side < 0 then PALETTE.Chrome else accent,
				if side < 0 then Enum.Material.Metal else Enum.Material.Neon,
				false
			)
			pylon.CastShadow = side < 0
			tagBloomStory(pylon, "Hub", 2, accent, 0, pylon.Material)
		end
		local crown = createPart(
			gate,
			"GatewayCrown",
			Vector3.new(12.5, 1.2, 1.8),
			gateFrame * CFrame.new(0, 11, 0),
			accent,
			Enum.Material.Neon,
			false
		)
		crown.CastShadow = false
		tagBloomStory(crown, "Hub", 3, accent, 0, Enum.Material.Neon)
		createCompactWorldLabel(
			gate,
			crown,
			`{tostring(definition.symbol)} · {tostring(definition.nameRu)}`,
			tostring(definition.hintRu),
			accent
		)
		createNumberCue(gate, platform, index, accent)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DistrictPreviewPrompt"
		prompt.ActionText = "Посмотреть район"
		prompt.ObjectText = tostring(definition.nameRu)
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("AuraRushDistrictPreview", true)
		prompt:SetAttribute("DistrictNameRu", tostring(definition.nameRu))
		prompt:SetAttribute("DistrictHintRu", tostring(definition.hintRu))
		prompt.Parent = platform
		local secretDefinition = premiumCityCatalog.GetSecretFrameForWorld(definition.id)
		if secretDefinition then
			buildSecretFrame(gate, gateFrame, secretDefinition, index, accent)
		end
		local routeEnd = center - outward * 10
		local routeStart = Vector3.new(0, 2.52, 9) + outward * 31
		local districtRoute = createRouteStripe(
			premium,
			`DistrictRoute_{index}`,
			routeStart,
			routeEnd,
			accent:Lerp(PALETTE.Ink, 0.12),
			0.76
		)
		districtRoute:SetAttribute("WorldId", tostring(definition.id))
		tagBloomable(districtRoute, "Hub")
	end

	local padDefinitions = premiumCityCatalog.PulsePads
	for index, definition in if type(padDefinitions) == "table" then padDefinitions else {} do
		local angle = math.rad(tonumber(definition.angleDegrees) or ((index - 1) * 90))
		local position = Vector3.new(math.sin(angle) * 19, 2.55, 9 + math.cos(angle) * 19)
		local accent = colorFromHex(definition.accentHex, PALETTE.Acid)
		local pad = createDisc(
			premium,
			`CityPulsePad_{tostring(definition.id)}`,
			position,
			4.1,
			0.42,
			accent
		)
		pad.Material = Enum.Material.Neon
		pad.CastShadow = false
		pad:SetAttribute("CityPulsePad", true)
		pad:SetAttribute("PulsePadId", tostring(definition.id))
		pad:SetAttribute("PulsePadIndex", index)
		pad:SetAttribute("PulsePadNameRu", tostring(definition.nameRu))
		pad:SetAttribute("PulseCueRu", tostring(definition.cueRu))
		pad:SetAttribute("PulseBaseColor", accent:ToHex())
		pad:SetAttribute("ColorIndependentCue", `Плита {tostring(definition.nameRu)}`)
		tagBloomable(pad, "Hub")
		createNumberCue(premium, pad, index, accent)
		createPulsePadLabel(premium, pad, `{index} · {tostring(definition.nameRu)}`, accent)
		table.insert(cityPulsePads, pad)
	end

	for index, position in
		{
			Vector3.new(-34, 2.8, -22),
			Vector3.new(34, 2.8, -22),
		}
	do
		local stage = createDisc(
			premium,
			`PhotoStage_{index}`,
			position,
			7,
			0.6,
			if index == 1 then PALETTE.Purple else PALETTE.Coral
		)
		stage.Material = Enum.Material.Marble
		stage:SetAttribute("PhotoSpot", true)
		stage:SetAttribute("CameraSafeRadius", 9)
		stage:SetAttribute("AccessibilityCue", "Свободная фотоплощадка")
		tagBloomable(stage, "Hub")
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PhotoSpotPrompt"
		prompt.ActionText = "Сделать фото"
		prompt.ObjectText = `Фотозона {index}`
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("AuraRushPhotoSpot", true)
		prompt.Parent = stage
	end

	premium:SetAttribute("DistrictGatewayCount", #premiumCityCatalog.Districts)
	premium:SetAttribute("PulsePadCount", #cityPulsePads)
	premium:SetAttribute("RailSegmentCount", 72)
	premium:SetAttribute("SecretFrameCount", #secretFrames)
end

local function buildHub(root: Model): ()
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = root
	configureStreamingZone(hub, "hub")
	hub:SetAttribute("WorldNameRu", "Площадь стиля")
	hub:SetAttribute("ArtPassVersion", 8)
	hub:SetAttribute("SpawnClearRadius", 14)
	hub:SetAttribute("PrimaryRouteWidth", 16)
	hub:SetAttribute("SpatialHierarchy", "arrival_heart_districts")
	hub:SetAttribute("IdleGameplay", "city_pulse")

	local floor =
		createDisc(hub, "HubFloor", Vector3.new(0, 0, 4), 78, 3, Color3.fromRGB(43, 50, 64))
	floor.Material = Enum.Material.Asphalt
	tagBloomable(floor, "Hub")
	local plaza =
		createDisc(hub, "HubPlaza", Vector3.new(0, 1.7, 4), 64, 0.6, Color3.fromRGB(70, 81, 98))
	plaza.Material = Enum.Material.Concrete
	tagBloomable(plaza, "Hub")

	buildSegmentedArc(
		hub,
		"PlazaPulseRing",
		CFrame.new(0, 2.18, 0) * CFrame.Angles(math.rad(90), 0, 0),
		45,
		0,
		math.pi * 2,
		28,
		0.62,
		PALETTE.Acid,
		Enum.Material.SmoothPlastic,
		"Hub"
	)

	local skyline = {
		-- The skyline sits behind the northern gateway and elevated rail. The
		-- central gap preserves an unobstructed arrival-to-landmark sightline.
		{ Vector3.new(-54, 15, 76), 19, 30, PALETTE.ColdBlue },
		{ Vector3.new(-34, 20, 83), 18, 40, PALETTE.Coral },
		{ Vector3.new(-16, 16, 88), 16, 32, PALETTE.Acid },
		{ Vector3.new(16, 23, 88), 17, 46, PALETTE.ColdBlue },
		{ Vector3.new(34, 18, 83), 19, 36, PALETTE.Coral },
		{ Vector3.new(54, 13, 76), 18, 26, PALETTE.Acid },
	}
	for index, definition in skyline do
		buildHubFacade(
			hub,
			"PlazaFacade_" .. index,
			definition[1],
			definition[2],
			definition[3],
			definition[4]
		)
	end

	for index, route in
		{
			{ Vector3.new(0, 2.25, -42), Vector3.new(0, 2.25, 53), PALETTE.Acid },
			{ Vector3.new(10, 2.25, 0), Vector3.new(55, 2.25, 0), PALETTE.Coral },
			{ Vector3.new(-10, 2.25, 0), Vector3.new(-55, 2.25, 0), PALETTE.ColdBlue },
		}
	do
		local stripe =
			createRouteStripe(hub, "PlazaRoute_" .. index, route[1], route[2], route[3], 1.4)
		tagBloomable(stripe, "Hub")
	end

	local sculptureBase =
		createDisc(hub, "SignatureBase", Vector3.new(0, 2.4, 9), 9, 1.1, PALETTE.Milk)
	sculptureBase.Material = Enum.Material.Marble
	tagBloomable(sculptureBase, "Hub")
	buildSegmentedArc(
		hub,
		"SignatureOrbitA",
		CFrame.new(0, 15, 9),
		10,
		0,
		math.pi * 2,
		16,
		0.8,
		PALETTE.ColdBlue,
		Enum.Material.Metal,
		"Hub"
	)
	buildSegmentedArc(
		hub,
		"SignatureOrbitB",
		CFrame.new(0, 15, 9) * CFrame.Angles(0, math.rad(58), math.rad(28)),
		7.2,
		0,
		math.pi * 2,
		12,
		0.62,
		PALETTE.Coral,
		Enum.Material.SmoothPlastic,
		"Hub"
	)
	local signatureCore = createPart(
		hub,
		"SignatureCore",
		Vector3.new(5.5, 5.5, 5.5),
		CFrame.new(0, 15, 9),
		PALETTE.Acid,
		Enum.Material.Glass,
		false
	)
	signatureCore.Shape = Enum.PartType.Ball
	signatureCore.Transparency = 0.08
	tagLandmark(signatureCore, "hub_signature")
	local signatureLight = Instance.new("PointLight")
	signatureLight.Color = PALETTE.Acid
	signatureLight.Brightness = 1
	signatureLight.Range = 28
	signatureLight.Shadows = false
	signatureLight.Parent = signatureCore

	local logoAnchor = createPart(
		hub,
		"LogoAnchor",
		Vector3.new(2, 2, 2),
		CFrame.new(0, 7, 22),
		PALETTE.White,
		Enum.Material.Neon,
		false
	)
	logoAnchor.Transparency = 1
	createSign(
		hub,
		logoAnchor,
		"AURA RUSH",
		"Собери образ. Пройди район. Перекрась сцену.",
		PALETTE.Acid
	)
	buildArch(hub, Vector3.new(0, 0, 48), 24, PALETTE.Coral)

	for index, position in
		{
			Vector3.new(-14, 2.3, -35),
			Vector3.new(14, 2.3, -35),
			Vector3.new(-14, 2.3, -17),
			Vector3.new(14, 2.3, -17),
			Vector3.new(-20, 2.3, 25),
			Vector3.new(20, 2.3, 25),
		}
	do
		createGlowLamp(
			hub,
			"PlazaLamp_" .. index,
			position,
			if index % 2 == 0 then PALETTE.Coral else PALETTE.ColdBlue,
			6.5,
			"Hub"
		)
	end

	local arrivalPad = createPart(
		hub,
		"ArrivalPad",
		Vector3.new(18, 0.35, 13),
		CFrame.new(0, 2.35, -34),
		Color3.fromRGB(32, 40, 53),
		Enum.Material.Metal,
		true
	)
	arrivalPad:SetAttribute("SafeSpawnArea", true)
	tagBloomable(arrivalPad, "Hub")
	for index = -2, 2 do
		local tread = createPart(
			hub,
			`ArrivalTread_{index}`,
			Vector3.new(12, 0.08, 0.38),
			CFrame.new(0, 2.57, -34 + index * 2),
			if index == 0 then PALETTE.Acid else PALETTE.Chrome,
			Enum.Material.SmoothPlastic,
			false
		)
		tread.CanTouch = false
		tagBloomable(tread, "Hub")
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 3, -34), Vector3.new(0, 3, 9))
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn:SetAttribute("ArrivalFocus", Vector3.new(0, 14, 9))
	spawn.Parent = hub
	spawns.Hub = CFrame.lookAt(Vector3.new(0, 6, -34), Vector3.new(0, 6, 9))
	buildPremiumCityLayer(hub)
end

local function buildThreadRun(root: Model): ()
	local area = Instance.new("Model")
	area.Name = "ThreadRun"
	area.Parent = root
	local origin = Vector3.new(0, 0, 115)

	local base = createPart(
		area,
		"StartPlatform",
		Vector3.new(32, 2, 24),
		CFrame.new(origin),
		PALETTE.Deep,
		Enum.Material.SmoothPlastic
	)
	tagBloomable(base, "Challenge")
	createSign(
		area,
		base,
		"Погоня",
		"Собери 8 нитей. Напольная линия ведёт вперёд.",
		PALETTE.Acid
	)
	spawns.ThreadRun = CFrame.new(origin + Vector3.new(0, 5, 0))

	local positions = {
		Vector3.new(0, 3, 16),
		Vector3.new(-8, 6, 30),
		Vector3.new(7, 9, 44),
		Vector3.new(14, 12, 58),
		Vector3.new(2, 15, 72),
		Vector3.new(-13, 12, 86),
		Vector3.new(-4, 9, 101),
		Vector3.new(8, 6, 116),
	}

	for index, offset in positions do
		local worldPosition = origin + offset
		local platform = createPart(
			area,
			"RunPlatform_" .. index,
			Vector3.new(15, 2, 11),
			CFrame.new(worldPosition),
			if index % 2 == 0 then PALETTE.Deep else Color3.fromRGB(48, 38, 88),
			Enum.Material.SmoothPlastic
		)
		tagBloomable(platform, "Challenge")

		local orb = createPart(
			area,
			"Thread_" .. index,
			Vector3.new(3.2, 3.2, 3.2),
			CFrame.new(worldPosition + Vector3.new(0, 4, 0)),
			if index % 2 == 0 then PALETTE.Cyan else PALETTE.Pink,
			Enum.Material.Neon,
			false
		)
		orb.Shape = Enum.PartType.Ball
		orb:SetAttribute("CollectibleId", index)
		orb:SetAttribute("ChallengeAct", "thread_run")
		CollectionService:AddTag(orb, COLLECTIBLE_TAG)
		table.insert(collectibles, orb)

		-- Neon already keeps every collectible readable. Lighting only alternating
		-- orbs preserves cadence while avoiding eight overlapping local lights on
		-- low-end clients.
		if index % 2 == 1 then
			local light = Instance.new("PointLight")
			light.Color = orb.Color
			light.Brightness = 1.65
			light.Range = 12
			light.Shadows = false
			light.Parent = orb
		end
	end
	createRouteStripe(
		area,
		"ThreadRoute",
		origin + Vector3.new(0, 2.1, 8),
		origin + Vector3.new(8, 8.1, 116),
		PALETTE.Acid,
		0.65
	)

	createPart(
		area,
		"SafetyFloor",
		Vector3.new(90, 2, 150),
		CFrame.new(origin + Vector3.new(0, -8, 66)),
		PALETTE.Ink,
		Enum.Material.SmoothPlastic
	).Transparency =
		0.12
end

local function buildBeatLab(root: Model): ()
	local area = Instance.new("Model")
	area.Name = "BeatLab"
	area.Parent = root
	local origin = Vector3.new(130, 0, 0)
	local stage = createDisc(area, "BeatStage", origin, 34, 3, PALETTE.Deep)
	tagBloomable(stage, "Challenge")
	createSign(
		area,
		stage,
		"Бит-челлендж",
		"Нажимай в ритм. Кольца показывают долю.",
		PALETTE.Coral
	)
	spawns.BeatLab = CFrame.new(origin + Vector3.new(0, 6, 0))

	for index = 1, 16 do
		local angle = (index / 16) * math.pi * 2
		local column = createPart(
			area,
			"BeatColumn",
			Vector3.new(2, 6 + (index % 4) * 3, 2),
			CFrame.new(origin + Vector3.new(math.cos(angle) * 29, 4, math.sin(angle) * 29)),
			if index % 2 == 0 then PALETTE.Chrome else PALETTE.Coral,
			if index % 2 == 0 then Enum.Material.Metal else Enum.Material.SmoothPlastic,
			false
		)
		tagBloomable(column, "Challenge")
	end
end

local function buildPrismPuzzle(root: Model): ()
	local area = Instance.new("Model")
	area.Name = "PrismPuzzle"
	area.Parent = root
	local origin = Vector3.new(-130, 0, 0)
	local floor = createPart(
		area,
		"PrismFloor",
		Vector3.new(70, 2, 70),
		CFrame.new(origin),
		PALETTE.Ink,
		Enum.Material.SmoothPlastic
	)
	tagBloomable(floor, "Challenge")
	createSign(
		area,
		floor,
		"Цветовой код",
		"Запомни порядок. У каждой площадки есть номер.",
		PALETTE.ColdBlue
	)
	spawns.PrismPuzzle = CFrame.new(origin + Vector3.new(0, 5, 18))

	local colors = { PALETTE.Pink, PALETTE.Cyan, PALETTE.Gold, PALETTE.Mint }
	for index, color in colors do
		local x = if index % 2 == 0 then 13 else -13
		local z = if index > 2 then 13 else -13
		local pad =
			createDisc(area, "PrismPad_" .. index, origin + Vector3.new(x, 1.5, z), 8, 1, color)
		pad.Material = Enum.Material.Neon
		pad:SetAttribute("PrismIndex", index)
		tagBloomable(pad, "Challenge")
		createNumberCue(area, pad, index, color)
	end

	local crystal = createPart(
		area,
		"SignalCrystal",
		Vector3.new(8, 18, 8),
		CFrame.new(origin + Vector3.new(0, 10, 0)) * CFrame.Angles(0, math.rad(45), 0),
		PALETTE.White,
		Enum.Material.Glass,
		false
	)
	crystal.Transparency = 0.22
	tagBloomable(crystal, "Challenge")
end

local function buildMaterialSurf(root: Model): ()
	local area = Instance.new("Model")
	area.Name = "MaterialSurf"
	area.Parent = root
	configureStreamingZone(area, "material_surf")
	local origin = Vector3.new(245, 2, 92)

	local start = createPart(
		area,
		"SurfLaunch",
		Vector3.new(30, 2, 24),
		CFrame.new(origin),
		Color3.fromRGB(24, 27, 60),
		Enum.Material.Metal
	)
	tagBloomable(start, "MaterialSurf")
	createSign(
		area,
		start,
		"Материал-сёрф",
		"Пройди волну и собери 8 образцов.",
		PALETTE.ColdBlue
	)
	spawns.MaterialSurf = CFrame.new(origin + Vector3.new(0, 5, 0))

	local previous = origin + Vector3.new(0, 1, 10)
	for index = 1, 10 do
		local phase = index / 10
		local center = origin
			+ Vector3.new(
				math.sin(phase * math.pi * 2) * 18,
				3 + math.sin(phase * math.pi) * 15,
				index * 14
			)
		local nextCenter = if index < 10
			then origin + Vector3.new(
				math.sin(((index + 1) / 10) * math.pi * 2) * 18,
				3 + math.sin(((index + 1) / 10) * math.pi) * 15,
				(index + 1) * 14
			)
			else center + Vector3.new(0, -2, 14)
		local platform = createPart(
			area,
			"MaterialWave_" .. index,
			Vector3.new(18, 1.5, 13),
			CFrame.lookAt(center, nextCenter),
			if index % 3 == 0
				then PALETTE.Pink
				elseif index % 2 == 0 then PALETTE.Purple
				else PALETTE.Cyan,
			if index % 3 == 0 then Enum.Material.Glass else Enum.Material.SmoothPlastic
		)
		platform.Transparency = if platform.Material == Enum.Material.Glass then 0.2 else 0
		platform:SetAttribute("MaterialBehavior", if index % 3 == 0 then "Glide" else "Pulse")
		tagBloomable(platform, "MaterialSurf")
		createConnector(area, "WaveSeam", previous, center, 0.45, PALETTE.White, Enum.Material.Neon)
		previous = center

		if index <= 8 then
			local sample = createPart(
				area,
				"MaterialSample_" .. index,
				Vector3.new(3, 3, 3),
				CFrame.new(center + Vector3.new(0, 4, 0)) * CFrame.Angles(0, index * 0.7, 0.7),
				if index % 2 == 0 then PALETTE.Gold else PALETTE.Mint,
				Enum.Material.Neon,
				false
			)
			sample.Shape = Enum.PartType.Ball
			sample:SetAttribute("CollectibleId", index)
			sample:SetAttribute("ChallengeAct", "material_surf")
			CollectionService:AddTag(sample, COLLECTIBLE_TAG)
			table.insert(collectibles, sample)
		end
	end

	local crest = createPart(
		area,
		"LiquidChromeCrest",
		Vector3.new(4, 28, 28),
		CFrame.new(origin + Vector3.new(0, 12, 156)) * CFrame.Angles(0, 0, math.rad(90)),
		PALETTE.White,
		Enum.Material.Metal,
		false
	)
	crest.Shape = Enum.PartType.Cylinder
	tagLandmark(crest, "material_surf_crest")
	local safety = createPart(
		area,
		"SurfSafetyFloor",
		Vector3.new(80, 2, 190),
		CFrame.new(origin + Vector3.new(0, -12, 80)),
		PALETTE.Ink,
		Enum.Material.SmoothPlastic
	)
	safety.Transparency = 0.15
end

local function buildLightLoom(root: Model): ()
	local area = Instance.new("Model")
	area.Name = "LightLoom"
	area.Parent = root
	configureStreamingZone(area, "light_loom")
	local origin = Vector3.new(-245, 3, 90)
	local floor = createDisc(area, "LoomFloor", origin, 40, 3, PALETTE.Ink)
	tagBloomable(floor, "LightLoom")
	createSign(
		area,
		floor,
		"Светоткачество",
		"Соедини четыре дорожки в один узор.",
		PALETTE.Acid
	)
	spawns.LightLoom = CFrame.new(origin + Vector3.new(0, 6, 21))

	local laneColors = { PALETTE.Pink, PALETTE.Cyan, PALETTE.Gold, PALETTE.Mint }
	for lane, color in laneColors do
		local previous = origin + Vector3.new((lane - 2.5) * 10, 2, 25)
		for step = 1, 6 do
			local point = origin
				+ Vector3.new((lane - 2.5) * (10 - step * 1.25), 3 + step * 2.1, 22 - step * 7)
			local thread = createConnector(
				area,
				"LoomThread_" .. lane .. "_" .. step,
				previous,
				point,
				0.55,
				color,
				Enum.Material.Neon
			)
			tagBloomable(thread, "LightLoom")
			local node = createPart(
				area,
				"LoomNode_" .. lane .. "_" .. step,
				Vector3.new(1.4, 1.4, 1.4),
				CFrame.new(point),
				color,
				Enum.Material.Neon,
				false
			)
			node.Shape = Enum.PartType.Ball
			node:SetAttribute("LoomLane", lane)
			node:SetAttribute("LoomStep", step)
			previous = point
		end
	end

	local spindle = createPart(
		area,
		"OpalSpindle",
		Vector3.new(10, 28, 10),
		CFrame.new(origin + Vector3.new(0, 15, -23)) * CFrame.Angles(0, math.rad(45), 0),
		PALETTE.White,
		Enum.Material.Glass,
		false
	)
	spindle.Transparency = 0.18
	tagLandmark(spindle, "light_loom_spindle")
end

local function buildBloomRescue(root: Model): ()
	local area = Instance.new("Model")
	area.Name = "BloomRescue"
	area.Parent = root
	configureStreamingZone(area, "bloom_rescue")
	local origin = Vector3.new(0, 2, -270)
	local floor = createDisc(area, "RescueGarden", origin, 46, 3, Color3.fromRGB(23, 29, 41))
	tagBloomable(floor, "BloomRescue")
	createSign(
		area,
		floor,
		"Спасение района",
		"Верни свет точкам в правильном порядке.",
		PALETTE.Coral
	)
	spawns.BloomRescue = CFrame.new(origin + Vector3.new(0, 6, 24))

	local colors = { PALETTE.Pink, PALETTE.Cyan, PALETTE.Gold, PALETTE.Mint }
	for index, color in colors do
		local angle = ((index - 1) / 4) * math.pi * 2 + math.pi * 0.25
		local position = origin + Vector3.new(math.cos(angle) * 22, 2, math.sin(angle) * 22)
		local pad = createDisc(area, "RescueNode_" .. index, position, 7, 1.2, color)
		pad.Material = Enum.Material.Neon
		pad:SetAttribute("PrismIndex", index)
		pad:SetAttribute("ChallengeAct", "bloom_rescue")
		tagBloomable(pad, "BloomRescue")
		createNumberCue(area, pad, index, color)
		for petalIndex = 1, 5 do
			local petalAngle = (petalIndex / 5) * math.pi * 2
			local petalPosition = position
				+ Vector3.new(math.cos(petalAngle) * 6, 3.2, math.sin(petalAngle) * 6)
			local petal = createPart(
				area,
				"DormantPetal",
				Vector3.new(1.3, 5, 2.5),
				CFrame.lookAt(petalPosition, position) * CFrame.Angles(math.rad(22), 0, 0),
				Color3.fromRGB(71, 73, 92),
				Enum.Material.Slate,
				false
			)
			petal:SetAttribute("RescueNode", index)
			tagBloomable(petal, "BloomRescue")
		end
	end

	local heart = createPart(
		area,
		"DormantBloomHeart",
		Vector3.new(11, 22, 11),
		CFrame.new(origin + Vector3.new(0, 12, 0)) * CFrame.Angles(0.2, math.rad(45), 0.2),
		PALETTE.Purple,
		Enum.Material.Glass,
		false
	)
	heart.Transparency = 0.22
	heart:SetAttribute("RescueHeart", true)
	tagLandmark(heart, "bloom_rescue_heart")
end

local function buildMixLab(root: Model): ()
	local area = Instance.new("Model")
	area.Name = "MixLab"
	area.Parent = root
	local origin = Vector3.new(0, 0, -120)
	local floor = createDisc(area, "MixFloor", origin, 38, 3, PALETTE.Deep)
	tagBloomable(floor, "MixLab")
	createSign(
		area,
		floor,
		"Гримерка",
		"Цвет, фактура, аура и поза — собери свой выход.",
		PALETTE.Acid
	)
	spawns.MixLab = CFrame.new(origin + Vector3.new(0, 6, 0))

	for index = 1, 6 do
		local angle = (index / 6) * math.pi * 2
		local framePosition = origin + Vector3.new(math.cos(angle) * 29, 8, math.sin(angle) * 29)
		local frame = createPart(
			area,
			"MirrorFrame",
			Vector3.new(10, 17, 1),
			CFrame.lookAt(framePosition, origin + Vector3.new(0, 8, 0)),
			PALETTE.Gold,
			Enum.Material.Metal,
			false
		)
		frame.Transparency = 0.12
		tagBloomable(frame, "MixLab")
	end
end

local function buildMetroFinale(root: Model): ()
	local area, profile = createWorldModel(root, "PrismMetro", "prism_metro")
	local origin = Vector3.new(-80, 6, 340)
	local ink = profileColor(profile, 1, PALETTE.Ink)
	local blue = profileColor(profile, 2, PALETTE.ColdBlue)
	local coral = profileColor(profile, 3, PALETTE.Coral)
	local milk = profileColor(profile, 4, PALETTE.Milk)
	local accent = colorFromHex(if profile then profile.accentHex else nil, blue)
	area:SetAttribute("HeroDistrict", true)
	area:SetAttribute("ArtPassVersion", 6)
	area:SetAttribute("ModularKit", "PrismTransitKit_v1")
	area:SetAttribute("RouteClearWidth", 28)
	area:SetAttribute("SpawnClearRadius", 11)

	local runway = createPart(
		area,
		"MetroRunway",
		Vector3.new(58, 3, 126),
		CFrame.new(origin),
		ink,
		Enum.Material.Asphalt
	)
	tagBloomable(runway, "Metro")
	local platform = createPart(
		area,
		"EditorialPlatform",
		Vector3.new(36, 1.2, 116),
		CFrame.new(origin + Vector3.new(0, 2.1, 0)),
		Color3.fromRGB(27, 35, 49),
		Enum.Material.Concrete
	)
	tagBloomable(platform, "Metro")
	local signPylon = createPart(
		area,
		"StationGuide",
		Vector3.new(1.1, 5.8, 1.1),
		CFrame.new(origin + Vector3.new(-20.5, 5.2, -50)),
		accent,
		Enum.Material.Neon,
		false
	)
	signPylon.CanTouch = false
	tagBloomable(signPylon, "Metro")
	createSign(
		area,
		signPylon,
		"Призма-метро",
		"Держись линии. У ворот район поймает ваш стиль.",
		accent
	)
	spawns.Finale_prism_metro =
		CFrame.lookAt(origin + Vector3.new(0, 5.5, -50), origin + Vector3.new(0, 5.5, 44))

	local route = createRouteStripe(
		area,
		"MetroRoute",
		origin + Vector3.new(0, 2.76, -56),
		origin + Vector3.new(0, 2.76, 53),
		accent,
		1.6
	)
	tagBloomStory(route, "Metro", 1, accent, 0, Enum.Material.SmoothPlastic)
	for side = -1, 1, 2 do
		local edge = createRouteStripe(
			area,
			"PlatformEdge_" .. side,
			origin + Vector3.new(side * 16.2, 2.76, -56),
			origin + Vector3.new(side * 16.2, 2.76, 53),
			milk,
			0.52
		)
		edge:SetAttribute(
			"ColorIndependentCue",
			"Тактильная граница платформы"
		)
		tagBloomable(edge, "Metro")

		for railIndex, xOffset in { 21.2, 24.4 } do
			local rail = createConnector(
				area,
				`TransitRail_{side}_{railIndex}`,
				origin + Vector3.new(side * xOffset, 2.1, -60),
				origin + Vector3.new(side * xOffset, 2.1, 60),
				0.45,
				PALETTE.Chrome,
				Enum.Material.Metal
			)
			rail:SetAttribute("SetDressing", "Rail")
			tagBloomable(rail, "Metro")
		end
	end

	for index = 1, 12 do
		local z = -51 + (index - 1) * 9.2
		local cadenceTile = createPart(
			area,
			`CadenceTile_{index}`,
			Vector3.new(if index % 3 == 0 then 7.5 else 5.2, 0.12, 3.8),
			CFrame.new(origin + Vector3.new(0, 2.78, z)),
			if index % 4 == 0 then coral else accent:Lerp(ink, 0.2 + (index % 3) * 0.12),
			if index % 3 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			false
		)
		cadenceTile.CanTouch = false
		cadenceTile.CastShadow = false
		cadenceTile:SetAttribute("RouteBeat", index)
		cadenceTile:SetAttribute("ReactiveSignal", true)
		tagBloomStory(
			cadenceTile,
			"Metro",
			math.clamp(math.ceil(index / 4), 1, 3),
			if index % 4 == 0 then coral else accent,
			0,
			Enum.Material.Neon
		)
	end

	for side = -1, 1, 2 do
		for index = 1, 5 do
			local height = 23 + ((index * 5 + (if side > 0 then 1 else 0)) % 3) * 7
			local z = -44 + (index - 1) * 22
			buildTransitFacade(
				area,
				`TransitFacade_{side}_{index}`,
				origin + Vector3.new(side * 38, height * 0.5 + 1.5, z),
				side,
				height,
				if index % 2 == 0 then accent else blue,
				if index % 3 == 0 then coral else milk
			)
		end
	end

	for side = -1, 1, 2 do
		for index = 1, 5 do
			createGlowLamp(
				area,
				`PlatformLamp_{side}_{index}`,
				origin + Vector3.new(side * 12.8, 2.75, -43 + (index - 1) * 22),
				if (index + side) % 2 == 0 then coral else accent,
				7.2
			)
		end
	end

	for index = 1, 3 do
		local z = -34 + index * 31
		local beam = createConnector(
			area,
			"CanopyRibbon_" .. index,
			origin + Vector3.new(-19, 18 + index, z - 3),
			origin + Vector3.new(19, 18 + (4 - index), z + 3),
			0.82,
			PALETTE.Chrome,
			Enum.Material.Metal
		)
		tagBloomStory(
			beam,
			"Metro",
			2,
			if index == 2 then coral else accent,
			0,
			Enum.Material.Metal
		)
	end

	local gateSegments = buildSegmentedArc(
		area,
		"KineticGate",
		CFrame.new(origin + Vector3.new(0, 2.8, 50)),
		15.5,
		0,
		math.pi,
		12,
		1.55,
		PALETTE.Chrome,
		Enum.Material.Metal,
		"Metro",
		3,
		accent
	)
	for _, segment in gateSegments do
		tagLandmark(segment, "prism_metro_kinetic_gate")
	end
	local heroPrism = createPart(
		area,
		"KineticGateCore",
		Vector3.new(5.8, 5.8, 5.8),
		CFrame.new(origin + Vector3.new(0, 20.5, 50)) * CFrame.Angles(0, math.rad(45), math.rad(45)),
		coral,
		Enum.Material.Glass,
		false
	)
	heroPrism.Transparency = 0.08
	heroPrism.CastShadow = false
	heroPrism:SetAttribute("AmbientSignal", true)
	tagBloomStory(heroPrism, "Metro", 3, accent, 0.02, Enum.Material.Glass)
	tagLandmark(heroPrism, "prism_metro_kinetic_gate")
	local heroLight = Instance.new("PointLight")
	heroLight.Color = accent
	heroLight.Brightness = 1.2
	heroLight.Range = 34
	heroLight.Shadows = false
	heroLight.Parent = heroPrism
	createFinaleCamera(
		area,
		"prism_metro",
		origin + Vector3.new(0, 21, -74),
		origin + Vector3.new(0, 8, 12)
	)
end

local function buildCloudFinale(root: Model): ()
	local area, profile = createWorldModel(root, "CloudBazaar", "cloud_bazaar")
	local origin = Vector3.new(140, 55, 340)
	local porcelain = profileColor(profile, 1, PALETTE.Milk)
	local blush = profileColor(profile, 2, Color3.fromRGB(255, 200, 221))
	local mist = profileColor(profile, 3, Color3.fromRGB(184, 242, 230))
	local lilac = profileColor(profile, 4, Color3.fromRGB(205, 180, 219))
	local accent = colorFromHex(if profile then profile.accentHex else nil, blush)

	local island = createDisc(area, "CloudIsland", origin, 45, 8, porcelain)
	island.Material = Enum.Material.Marble
	tagBloomable(island, "Cloud")
	for index, offset in
		{
			Vector3.new(-29, -1, 7),
			Vector3.new(29, -1, 5),
			Vector3.new(-20, -2, -28),
			Vector3.new(23, -2, 29),
		}
	do
		local terrace = createDisc(
			area,
			"CloudTerrace_" .. index,
			origin + offset,
			18 - (index % 2) * 3,
			5,
			if index % 2 == 0 then Color3.fromRGB(232, 236, 233) else porcelain
		)
		terrace.Material = Enum.Material.SmoothPlastic
		tagBloomable(terrace, "Cloud")
	end
	createSign(
		area,
		island,
		"Облачный квартал",
		"Следуй по розовой дорожке к жемчужной сцене.",
		accent
	)
	spawns.Finale_cloud_bazaar = CFrame.new(origin + Vector3.new(0, 9, -20))

	local cloudRoute = createRouteStripe(
		area,
		"CloudRoute",
		origin + Vector3.new(0, 4.25, -34),
		origin + Vector3.new(0, 4.25, 31),
		accent,
		1.8
	)
	tagBloomStory(cloudRoute, "Cloud", 1, accent, 0, Enum.Material.SmoothPlastic)

	local pavilionOffsets = {
		Vector3.new(-24, 4.5, 4),
		Vector3.new(24, 4.5, 7),
		Vector3.new(0, 4.5, 24),
	}
	for index, offset in pavilionOffsets do
		local center = origin + offset
		local base = createDisc(
			area,
			"PavilionBase_" .. index,
			center,
			9,
			1.1,
			if index == 2 then mist else porcelain
		)
		base.Material = Enum.Material.Marble
		tagBloomable(base, "Cloud")
		buildSegmentedArc(
			area,
			"SoftArch_" .. index,
			CFrame.new(center + Vector3.new(0, 0.5, 0)),
			8,
			0,
			math.pi,
			7,
			0.85,
			if index == 1 then blush elseif index == 2 then mist else lilac,
			Enum.Material.SmoothPlastic,
			"Cloud",
			2,
			accent
		)
		local canopy = createWedge(
			area,
			"SilkCanopy_" .. index,
			Vector3.new(13, 1.1, 11),
			CFrame.new(center + Vector3.new(0, 8.4, 0)) * CFrame.Angles(0, index * 0.42, 0),
			if index == 1 then blush elseif index == 2 then mist else lilac,
			Enum.Material.Fabric,
			false
		)
		canopy.Transparency = 0.18
		tagBloomStory(canopy, "Cloud", 2, accent:Lerp(porcelain, 0.4), 0.02, Enum.Material.Fabric)
	end

	local cloudCenters = {
		Vector3.new(-48, -4, -18),
		Vector3.new(48, -5, -9),
		Vector3.new(-38, -7, 39),
		Vector3.new(42, -4, 43),
	}
	for clusterIndex, clusterOffset in cloudCenters do
		for puffIndex = 1, 3 do
			local puff = createPart(
				area,
				"CloudPuff_" .. clusterIndex .. "_" .. puffIndex,
				Vector3.new(13 + puffIndex * 3, 7 + (puffIndex % 2) * 3, 10 + puffIndex),
				CFrame.new(
					origin
						+ clusterOffset
						+ Vector3.new((puffIndex - 2) * 8, (puffIndex % 2) * 2, (puffIndex - 2) * 2)
				),
				porcelain,
				Enum.Material.SmoothPlastic,
				false
			)
			puff.Shape = Enum.PartType.Ball
			puff.Transparency = 0.08
			puff.CastShadow = false
			puff:SetAttribute("VisualPriority", "Low")
			tagBloomable(puff, "Cloud")
		end
	end

	local pearl = createPart(
		area,
		"QuarterPearl",
		Vector3.new(13, 13, 13),
		CFrame.new(origin + Vector3.new(0, 16, 34)),
		porcelain,
		Enum.Material.Glass,
		false
	)
	pearl.Shape = Enum.PartType.Ball
	pearl.Transparency = 0.16
	tagBloomStory(pearl, "Cloud", 3, accent:Lerp(porcelain, 0.6), 0.04, Enum.Material.Glass)
	tagLandmark(pearl, "cloud_bazaar_pearl")
	buildSegmentedArc(
		area,
		"PearlHalo",
		CFrame.new(pearl.Position) * CFrame.Angles(0, math.rad(24), 0),
		11,
		0,
		math.pi * 2,
		10,
		0.55,
		lilac,
		Enum.Material.SmoothPlastic,
		"Cloud",
		3,
		accent
	)
	createFinaleCamera(
		area,
		"cloud_bazaar",
		origin + Vector3.new(0, 27, -72),
		origin + Vector3.new(0, 8, 4)
	)
end

local function buildGreenhouseFinale(root: Model): ()
	local area, profile = createWorldModel(root, "MoonlitGreenhouse", "moonlit_greenhouse")
	local origin = Vector3.new(-285, 8, 330)
	local night = profileColor(profile, 1, Color3.fromRGB(7, 26, 23))
	local teal = profileColor(profile, 2, Color3.fromRGB(10, 147, 150))
	local leaf = profileColor(profile, 3, Color3.fromRGB(148, 210, 189))
	local moonViolet = profileColor(profile, 4, Color3.fromRGB(181, 140, 255))
	local accent = colorFromHex(if profile then profile.accentHex else nil, leaf)

	local floor = createDisc(area, "GreenhouseFloor", origin, 46, 4, night)
	floor.Material = Enum.Material.Slate
	tagBloomable(floor, "Greenhouse")
	local mossFloor = createDisc(
		area,
		"VelvetMossFloor",
		origin + Vector3.new(0, 2.25, 0),
		40,
		0.8,
		Color3.fromRGB(19, 58, 48)
	)
	mossFloor.Material = Enum.Material.Grass
	tagBloomable(mossFloor, "Greenhouse")
	createSign(
		area,
		floor,
		"Лунная оранжерея",
		"Светлая дорожка ведёт к дереву. Цветы раскроются по этапам.",
		accent
	)
	spawns.Finale_moonlit_greenhouse = CFrame.new(origin + Vector3.new(0, 7, -20))

	local gardenRoute = createRouteStripe(
		area,
		"GardenRoute",
		origin + Vector3.new(0, 2.72, -38),
		origin + Vector3.new(0, 2.72, 33),
		PALETTE.Milk,
		1.35
	)
	tagBloomStory(gardenRoute, "Greenhouse", 1, accent, 0, Enum.Material.SmoothPlastic)

	for index, z in { -31, -10, 11, 32 } do
		buildSegmentedArc(
			area,
			"GlassRib_" .. index,
			CFrame.new(origin + Vector3.new(0, 2.5, z)),
			36,
			0,
			math.pi,
			7,
			0.9,
			if index % 2 == 0 then leaf else teal,
			Enum.Material.Glass,
			"Greenhouse",
			2,
			accent
		)
	end

	for index = 1, 9 do
		local angle = index * 2.399963
		local distance = 11 + (index % 3) * 9
		local basePosition = origin
			+ Vector3.new(math.cos(angle) * distance, 2.8, math.sin(angle) * distance)
		local stemHeight = 4 + index % 4
		local stem = createPart(
			area,
			"MoonStem_" .. index,
			Vector3.new(0.8, stemHeight, 0.8),
			CFrame.new(basePosition + Vector3.new(0, stemHeight * 0.5, 0)),
			Color3.fromRGB(51, 92, 70),
			Enum.Material.SmoothPlastic,
			false
		)
		tagBloomable(stem, "Greenhouse")
		local flower = createDisc(
			area,
			"MoonFlower_" .. index,
			basePosition + Vector3.new(0, stemHeight + 0.8, 0),
			2.1 + (index % 3) * 0.3,
			0.55,
			Color3.fromRGB(45, 63, 61)
		)
		flower.Material = Enum.Material.Glass
		flower.CanCollide = false
		flower.Transparency = 0.28
		tagBloomStory(
			flower,
			"Greenhouse",
			if index <= 3 then 1 elseif index <= 6 then 2 else 3,
			if index % 2 == 0 then moonViolet else accent,
			0.05,
			Enum.Material.Glass
		)
	end

	local treeBase = origin + Vector3.new(0, 2.8, 29)
	local trunkTop = treeBase + Vector3.new(0, 22, 0)
	local trunk = createConnector(
		area,
		"MoonTreeTrunk",
		treeBase,
		trunkTop,
		3.2,
		Color3.fromRGB(51, 62, 52),
		Enum.Material.Wood
	)
	tagBloomable(trunk, "Greenhouse")
	for index = 1, 6 do
		local angle = ((index - 1) / 6) * math.pi * 2
		local branchEnd = trunkTop
			+ Vector3.new(math.cos(angle) * 13, 4 + (index % 2) * 4, math.sin(angle) * 13)
		local branch = createConnector(
			area,
			"MoonBranch_" .. index,
			trunkTop - Vector3.new(0, index % 3, 0),
			branchEnd,
			1.25,
			Color3.fromRGB(57, 72, 57),
			Enum.Material.Wood
		)
		tagBloomable(branch, "Greenhouse")
		local leafBlade = createWedge(
			area,
			"MoonLeaf_" .. index,
			Vector3.new(5, 1.3, 9),
			CFrame.new(branchEnd) * CFrame.Angles(0, -angle, math.rad(12)),
			Color3.fromRGB(42, 74, 64),
			Enum.Material.Grass,
			false
		)
		leafBlade.Transparency = 0.18
		tagBloomStory(
			leafBlade,
			"Greenhouse",
			3,
			if index % 2 == 0 then accent else moonViolet,
			0,
			Enum.Material.Grass
		)
		tagLandmark(leafBlade, "moonlit_greenhouse_tree")
	end
	buildSegmentedArc(
		area,
		"MoonHalo",
		CFrame.new(origin + Vector3.new(0, 25, 39)),
		18,
		0,
		math.pi * 2,
		12,
		0.8,
		moonViolet,
		Enum.Material.Glass,
		"Greenhouse",
		3,
		accent
	)
	createFinaleCamera(
		area,
		"moonlit_greenhouse",
		origin + Vector3.new(0, 25, -68),
		origin + Vector3.new(0, 9, 3)
	)
end

local function buildBoardwalkFinale(root: Model): ()
	local area, profile = createWorldModel(root, "OrbitalBoardwalk", "orbital_boardwalk")
	local origin = Vector3.new(285, 58, 310)
	local spaceInk = profileColor(profile, 1, Color3.fromRGB(11, 12, 42))
	local violet = profileColor(profile, 2, Color3.fromRGB(155, 93, 229))
	local sunGold = profileColor(profile, 3, Color3.fromRGB(255, 209, 102))
	local festivalCoral = profileColor(profile, 4, Color3.fromRGB(247, 37, 133))
	local accent = colorFromHex(if profile then profile.accentHex else nil, violet)

	local deck = createPart(
		area,
		"OrbitDeck",
		Vector3.new(38, 3, 112),
		CFrame.new(origin),
		spaceInk,
		Enum.Material.Metal
	)
	tagBloomable(deck, "Boardwalk")
	local innerDeck = createPart(
		area,
		"FestivalRamp",
		Vector3.new(29, 1.1, 104),
		CFrame.new(origin + Vector3.new(0, 2.05, 0)),
		Color3.fromRGB(34, 37, 66),
		Enum.Material.SmoothPlastic
	)
	tagBloomable(innerDeck, "Boardwalk")
	createSign(
		area,
		deck,
		"Орбитальная набережная",
		"Держись центральной линии. Кольца соберутся вокруг сцены.",
		accent
	)
	spawns.Finale_orbital_boardwalk = CFrame.new(origin + Vector3.new(0, 7, -38))

	local route = createRouteStripe(
		area,
		"OrbitRoute",
		origin + Vector3.new(0, 2.7, -49),
		origin + Vector3.new(0, 2.7, 45),
		sunGold,
		1.3
	)
	tagBloomStory(route, "Boardwalk", 1, accent, 0, Enum.Material.SmoothPlastic)

	for side = -1, 1, 2 do
		local rail = createConnector(
			area,
			"ContinuousRail_" .. side,
			origin + Vector3.new(side * 18, 4, -51),
			origin + Vector3.new(side * 18, 4, 51),
			0.8,
			PALETTE.Chrome,
			Enum.Material.Metal
		)
		tagBloomable(rail, "Boardwalk")
		for index = 1, 4 do
			local z = -42 + index * 23
			local signal = createWedge(
				area,
				"SignalSail_" .. side .. "_" .. index,
				Vector3.new(4.5, 13 + (index % 2) * 4, 7),
				CFrame.new(origin + Vector3.new(side * 23, 7.5, z))
					* CFrame.Angles(0, -side * math.rad(90), 0),
				if index % 2 == 0 then violet else festivalCoral,
				Enum.Material.SmoothPlastic,
				false
			)
			signal.Transparency = 0.14
			tagBloomStory(
				signal,
				"Boardwalk",
				2,
				if index % 2 == 0 then accent else sunGold,
				0,
				Enum.Material.SmoothPlastic
			)
		end
	end

	for index, offset in { Vector3.new(-26, -1.5, 15), Vector3.new(26, -1.5, 19) } do
		local balcony = createDisc(
			area,
			"OrbitBalcony_" .. index,
			origin + offset,
			17,
			3,
			Color3.fromRGB(28, 31, 57)
		)
		balcony.Material = Enum.Material.Metal
		tagBloomable(balcony, "Boardwalk")
	end

	local beacon = createPart(
		area,
		"FestivalBeacon",
		Vector3.new(12, 12, 12),
		CFrame.new(origin + Vector3.new(0, 22, 38)),
		Color3.fromRGB(49, 49, 78),
		Enum.Material.Glass,
		false
	)
	beacon.Shape = Enum.PartType.Ball
	beacon.Transparency = 0.2
	tagBloomStory(beacon, "Boardwalk", 3, accent, 0.06, Enum.Material.Glass)
	tagLandmark(beacon, "orbital_boardwalk_beacon")
	buildSegmentedArc(
		area,
		"WideOrbit",
		CFrame.new(beacon.Position),
		28,
		0,
		math.pi * 2,
		14,
		1.15,
		sunGold,
		Enum.Material.Metal,
		"Boardwalk",
		2,
		accent
	)
	buildSegmentedArc(
		area,
		"TiltedOrbit",
		CFrame.new(beacon.Position) * CFrame.Angles(math.rad(18), math.rad(42), 0),
		19,
		0,
		math.pi * 2,
		10,
		0.7,
		festivalCoral,
		Enum.Material.SmoothPlastic,
		"Boardwalk",
		3,
		accent
	)

	for index = 1, 3 do
		local angle = (index / 3) * math.pi * 2
		local planet = createPart(
			area,
			"FestivalPlanet_" .. index,
			Vector3.new(7 + index * 2, 7 + index * 2, 7 + index * 2),
			CFrame.new(
				origin
					+ Vector3.new(math.cos(angle) * 43, 18 + index * 5, 18 + math.sin(angle) * 43)
			),
			if index == 1 then festivalCoral elseif index == 2 then sunGold else violet,
			Enum.Material.Glass,
			false
		)
		planet.Shape = Enum.PartType.Ball
		planet.Transparency = 0.22
		planet:SetAttribute("VisualPriority", "Low")
		tagBloomStory(
			planet,
			"Boardwalk",
			index,
			if index == 2 then sunGold else accent,
			0.08,
			Enum.Material.Glass
		)
	end

	createFinaleCamera(
		area,
		"orbital_boardwalk",
		origin + Vector3.new(0, 27, -76),
		origin + Vector3.new(0, 10, 4)
	)
end

local function buildVelvetArchiveFinale(root: Model): ()
	local area, profile = createWorldModel(root, "VelvetArchive", "velvet_archive")
	local origin = Vector3.new(-470, 10, 340)
	local ink = profileColor(profile, 1, Color3.fromRGB(22, 11, 34))
	local violet = profileColor(profile, 2, Color3.fromRGB(90, 24, 154))
	local thread = profileColor(profile, 3, Color3.fromRGB(224, 170, 255))
	local paper = profileColor(profile, 4, Color3.fromRGB(243, 217, 177))
	local accent = colorFromHex(if profile then profile.accentHex else nil, thread)
	local darkBrass = Color3.fromRGB(129, 102, 68)

	local archiveFloor = createPart(
		area,
		"ArchiveFloor",
		Vector3.new(56, 3, 118),
		CFrame.new(origin),
		ink,
		Enum.Material.Wood
	)
	tagBloomable(archiveFloor, "VelvetArchive")
	local runway = createPart(
		area,
		"VelvetRunway",
		Vector3.new(28, 1.1, 109),
		CFrame.new(origin + Vector3.new(0, 2.05, 0)),
		Color3.fromRGB(76, 23, 62),
		Enum.Material.Fabric
	)
	tagBloomable(runway, "VelvetArchive")
	createSign(
		area,
		archiveFloor,
		"Бархатный архив",
		"Светлая нить ведёт через своды к живой коллекции.",
		accent
	)
	spawns.Finale_velvet_archive = CFrame.new(origin + Vector3.new(0, 6, -40))

	local route = createRouteStripe(
		area,
		"ArchiveThread",
		origin + Vector3.new(0, 2.72, -51),
		origin + Vector3.new(0, 2.72, 46),
		paper,
		0.9
	)
	tagBloomStory(route, "VelvetArchive", 1, accent, 0, Enum.Material.SmoothPlastic)
	for index, z in { -28, 2, 32 } do
		buildSegmentedArc(
			area,
			"ArchiveVault_" .. index,
			CFrame.new(origin + Vector3.new(0, 2.7, z)),
			28,
			0,
			math.pi,
			8,
			1.7,
			darkBrass,
			Enum.Material.Metal,
			"VelvetArchive",
			if index == 1 then 1 else 2,
			if index == 3 then accent else darkBrass
		)
	end

	for index = 1, 9 do
		local t = (index - 1) / 8
		local angle = t * math.pi * 2.25
		local shelfPosition = origin
			+ Vector3.new(math.cos(angle) * 24, 8 + t * 13, 24 + math.sin(angle) * 20)
		local shelf = createPart(
			area,
			"SpiralShelf_" .. index,
			Vector3.new(10, 14, 3.2),
			CFrame.lookAt(shelfPosition, origin + Vector3.new(0, shelfPosition.Y - origin.Y, 24)),
			if index % 2 == 0 then Color3.fromRGB(43, 25, 50) else Color3.fromRGB(29, 20, 37),
			Enum.Material.Wood,
			false
		)
		tagBloomable(shelf, "VelvetArchive")
		local volume = createPart(
			area,
			"ArchiveVolume_" .. index,
			Vector3.new(6.5, 1.2, 3.6),
			shelf.CFrame * CFrame.new(0, ((index % 3) - 1) * 3.2, -1.9),
			Color3.fromRGB(71, 48, 73),
			Enum.Material.SmoothPlastic,
			false
		)
		volume:SetAttribute("ArchiveChapter", index)
		tagBloomStory(
			volume,
			"VelvetArchive",
			2,
			if index % 2 == 0 then accent else paper,
			0,
			Enum.Material.SmoothPlastic
		)
	end

	local pagePoints: { Vector3 } = {}
	for index = 1, 8 do
		local t = (index - 1) / 7
		local angle = t * math.pi * 2
		local point = origin
			+ Vector3.new(math.cos(angle) * (10 + t * 10), 13 + t * 16, 24 + math.sin(angle) * 13)
		table.insert(pagePoints, point)
		local page = createPart(
			area,
			"FlyingPage_" .. index,
			Vector3.new(5.5, 0.35, 3.8),
			CFrame.new(point) * CFrame.Angles(math.sin(angle) * 0.28, angle, math.cos(angle) * 0.25),
			Color3.fromRGB(68, 48, 70),
			Enum.Material.SmoothPlastic,
			false
		)
		page.Transparency = 0.26
		tagBloomStory(
			page,
			"VelvetArchive",
			3,
			if index % 2 == 0 then paper else accent,
			0.02,
			Enum.Material.SmoothPlastic
		)
		if index > 1 then
			local ribbon = createConnector(
				area,
				"InkConstellation_" .. index,
				pagePoints[index - 1],
				point,
				0.25,
				violet,
				Enum.Material.SmoothPlastic
			)
			tagBloomStory(ribbon, "VelvetArchive", 3, accent, 0.06, Enum.Material.SmoothPlastic)
		end
	end

	local orreryCenter = origin + Vector3.new(0, 22, 42)
	local spindle = createPart(
		area,
		"ArchiveOrrerySpindle",
		Vector3.new(3.8, 3.8, 3.8),
		CFrame.new(orreryCenter),
		paper,
		Enum.Material.Metal,
		false
	)
	spindle.Shape = Enum.PartType.Ball
	tagBloomStory(spindle, "VelvetArchive", 3, accent, 0, Enum.Material.Metal)
	tagLandmark(spindle, "velvet_archive_orrery")
	for index, transform in
		{
			CFrame.new(orreryCenter),
			CFrame.new(orreryCenter) * CFrame.Angles(math.rad(28), math.rad(52), 0),
		}
	do
		buildSegmentedArc(
			area,
			"ArchiveOrreryRing_" .. index,
			transform,
			17 + index * 4,
			0,
			math.pi * 2,
			12,
			0.75,
			if index == 1 then darkBrass else thread,
			Enum.Material.Metal,
			"VelvetArchive",
			3,
			accent
		)
	end
	createFinaleCamera(
		area,
		"velvet_archive",
		origin + Vector3.new(0, 27, -78),
		origin + Vector3.new(0, 10, 7)
	)
end

local function buildSolarCathedralFinale(root: Model): ()
	local area, profile = createWorldModel(root, "SolarCathedral", "solar_cathedral")
	local origin = Vector3.new(470, 15, 340)
	local earth = profileColor(profile, 1, Color3.fromRGB(58, 29, 18))
	local orange = profileColor(profile, 2, Color3.fromRGB(255, 159, 28))
	local sunGold = profileColor(profile, 3, Color3.fromRGB(255, 209, 102))
	local ivory = profileColor(profile, 4, Color3.fromRGB(255, 244, 214))
	local accent = colorFromHex(if profile then profile.accentHex else nil, sunGold)
	local warmGlass = orange:Lerp(ivory, 0.38)

	local foundation = createPart(
		area,
		"CathedralFoundation",
		Vector3.new(60, 4, 122),
		CFrame.new(origin),
		earth,
		Enum.Material.Sandstone
	)
	tagBloomable(foundation, "SolarCathedral")
	local aisle = createPart(
		area,
		"SunAisle",
		Vector3.new(36, 1.2, 112),
		CFrame.new(origin + Vector3.new(0, 2.55, 0)),
		ivory,
		Enum.Material.Marble
	)
	tagBloomable(aisle, "SolarCathedral")
	createSign(
		area,
		foundation,
		"Солнечный собор",
		"Золотая линия ведёт к зеркальному солнцу.",
		accent
	)
	spawns.Finale_solar_cathedral = CFrame.new(origin + Vector3.new(0, 6, -42))

	local route = createRouteStripe(
		area,
		"SunRoute",
		origin + Vector3.new(0, 3.2, -52),
		origin + Vector3.new(0, 3.2, 46),
		sunGold,
		1.25
	)
	tagBloomStory(route, "SolarCathedral", 1, accent, 0, Enum.Material.SmoothPlastic)

	for index, z in { -28, 3, 34 } do
		buildSegmentedArc(
			area,
			"SunArch_" .. index,
			CFrame.new(origin + Vector3.new(0, 3, z)),
			29,
			0,
			math.pi,
			9,
			1.8,
			if index == 2 then warmGlass else ivory,
			if index == 2 then Enum.Material.Glass else Enum.Material.Marble,
			"SolarCathedral",
			if index == 1 then 1 else 2,
			if index == 3 then accent else warmGlass
		)
	end

	for side = -1, 1, 2 do
		for index = 1, 4 do
			local z = -43 + index * 24
			local height = 25 + index * 2
			local columnPosition = origin + Vector3.new(side * 25, height * 0.5 + 2, z)
			local column = createPart(
				area,
				"PorcelainColumn_" .. side .. "_" .. index,
				Vector3.new(4.5, height, 4.5),
				CFrame.new(columnPosition),
				ivory,
				Enum.Material.Marble
			)
			tagBloomable(column, "SolarCathedral")
			local capital = createPart(
				area,
				"SunCapital_" .. side .. "_" .. index,
				Vector3.new(9, 2, 9),
				CFrame.new(columnPosition + Vector3.new(0, height * 0.5 + 1.2, 0))
					* CFrame.Angles(0, index * 0.4, 0),
				warmGlass,
				Enum.Material.Glass,
				false
			)
			capital.Transparency = 0.25
			tagBloomStory(capital, "SolarCathedral", 2, accent, 0.08, Enum.Material.Glass)
			local ray = createConnector(
				area,
				"SunRay_" .. side .. "_" .. index,
				capital.Position,
				origin + Vector3.new(0, 39, 43),
				0.5,
				sunGold,
				Enum.Material.Glass
			)
			ray.Transparency = 0.42
			tagBloomStory(ray, "SolarCathedral", 3, accent, 0.14, Enum.Material.Glass)
		end
	end

	local sunPosition = origin + Vector3.new(0, 39, 43)
	local sun = createPart(
		area,
		"LivingSun",
		Vector3.new(21, 21, 21),
		CFrame.new(sunPosition),
		warmGlass,
		Enum.Material.Glass,
		false
	)
	sun.Shape = Enum.PartType.Ball
	sun.Transparency = 0.12
	tagBloomStory(sun, "SolarCathedral", 3, accent, 0.02, Enum.Material.Glass)
	tagLandmark(sun, "solar_cathedral_sun")
	local sunLight = Instance.new("PointLight")
	sunLight.Name = "SolarBloomLight"
	sunLight.Color = warmGlass
	sunLight.Brightness = 1.6
	sunLight.Range = 58
	sunLight.Shadows = false
	sunLight.Parent = sun

	for index = 1, 9 do
		local angle = ((index - 1) / 9) * math.pi * 2
		local mirror = createWedge(
			area,
			"HelioMirror_" .. index,
			Vector3.new(5.5, 14, 1.2),
			CFrame.new(sunPosition + Vector3.new(math.cos(angle) * 23, math.sin(angle) * 23, 2))
				* CFrame.Angles(0, 0, angle - math.rad(90)),
			if index % 2 == 0 then PALETTE.Chrome else ivory,
			Enum.Material.Metal,
			false
		)
		mirror.Transparency = 0.24
		tagBloomStory(
			mirror,
			"SolarCathedral",
			3,
			if index % 2 == 0 then accent else ivory,
			0.04,
			Enum.Material.Metal
		)
		tagLandmark(mirror, "solar_cathedral_helio")
	end
	buildSegmentedArc(
		area,
		"SolarHalo",
		CFrame.new(sunPosition),
		34,
		0,
		math.pi * 2,
		14,
		1,
		sunGold,
		Enum.Material.Metal,
		"SolarCathedral",
		3,
		accent
	)

	createFinaleCamera(
		area,
		"solar_cathedral",
		origin + Vector3.new(0, 29, -80),
		origin + Vector3.new(0, 13, 8)
	)
end

local function buildRemixGuardians(root: Model): ()
	table.clear(guardianAnchors)
	if not remixCatalog or type(remixCatalog.Guardians) ~= "table" then
		return
	end
	local guardiansModel = Instance.new("Model")
	guardiansModel.Name = "RemixGuardians"
	guardiansModel:SetAttribute("GuardianCount", #remixCatalog.Guardians)
	guardiansModel:SetAttribute("PrimaryLanguage", "ru")
	guardiansModel.Parent = root
	configureStreamingZone(guardiansModel, "remix_guardians")

	for _, definition in remixCatalog.Guardians do
		local worldId = tostring(definition.worldId)
		local spawn = spawns["Finale_" .. worldId]
		if spawn then
			local model = Instance.new("Model")
			model.Name = "Guardian_" .. worldId
			model:SetAttribute("GuardianId", tostring(definition.id))
			model:SetAttribute("WorldId", worldId)
			model:SetAttribute("NameRu", tostring(definition.nameRu))
			model:SetAttribute("VerbRu", tostring(definition.verbRu))
			model:SetAttribute("Pattern", tostring(definition.pattern))
			model:SetAttribute("Progress", 0)
			model.Parent = guardiansModel

			local accent = colorFromHex(definition.accentHex, PALETTE.Purple)
			local center = (spawn * CFrame.new(0, 10, -18)).Position
			local core = createPart(
				model,
				"GuardianCore",
				Vector3.new(11, 11, 11),
				CFrame.new(center),
				accent,
				Enum.Material.Neon,
				false
			)
			core.Shape = Enum.PartType.Ball
			core.Transparency = 0.2
			core.CanTouch = false
			core:SetAttribute("GuardianAnchor", true)
			core:SetAttribute("WorldId", worldId)
			core:SetAttribute("AccentHex", tostring(definition.accentHex))
			core:SetAttribute("BaseSize", 11)
			guardianAnchors[worldId] = core

			buildSegmentedArc(
				model,
				"GuardianOrbit",
				CFrame.new(center),
				10,
				0,
				math.pi * 2,
				12,
				0.55,
				accent:Lerp(PALETTE.White, 0.24),
				Enum.Material.Neon,
				"Guardian"
			)
			createSign(
				model,
				core,
				tostring(definition.nameRu),
				tostring(definition.verbRu),
				accent
			)
		end
	end
end

local function configureLighting(): ()
	Lighting.ClockTime = 18.4
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(78, 87, 105)
	Lighting.OutdoorAmbient = Color3.fromRGB(118, 131, 152)
	Lighting.ExposureCompensation = 0.12
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.68
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.32
	pcall(function()
		Lighting.LightingStyle = Enum.LightingStyle.Realistic
	end)
	pcall(function()
		Lighting.PrioritizeLightingQuality = true
	end)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "AuraAtmosphere"
	atmosphere.Color = Color3.fromRGB(183, 196, 211)
	atmosphere.Decay = Color3.fromRGB(39, 48, 63)
	atmosphere.Density = 0.2
	atmosphere.Glare = 0.05
	atmosphere.Haze = 0.85
	atmosphere.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Name = "AuraBloom"
	bloom.Intensity = 0.1
	bloom.Size = 16
	bloom.Threshold = 1.8
	bloom.Parent = Lighting

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		or Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "AuraColor"
	colorCorrection.Brightness = 0.01
	colorCorrection.Contrast = 0.06
	colorCorrection.Saturation = 0.04
	colorCorrection.TintColor = PALETTE.Milk
	colorCorrection.Parent = Lighting
end

local function applyWorldLighting(worldId: string, bloomState: boolean, tweenDuration: number?): ()
	local profile = getArtProfile(worldId)
	if type(profile) ~= "table" then
		return
	end
	local target = if bloomState then profile.bloom else profile.normal
	if type(target) ~= "table" then
		return
	end
	local tweenInfo =
		TweenInfo.new(tweenDuration or 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local accent = colorFromHex(profile.accentHex, PALETTE.ColdBlue)
	local paletteBase = profileColor(profile, 1, PALETTE.Ink)
	TweenService:Create(Lighting, tweenInfo, {
		Brightness = tonumber(target.brightness) or Lighting.Brightness,
		ClockTime = tonumber(target.clockTime) or Lighting.ClockTime,
		Ambient = colorFromHex(target.ambientHex, Lighting.Ambient),
		OutdoorAmbient = colorFromHex(target.outdoorAmbientHex, Lighting.OutdoorAmbient),
	}):Play()

	local atmosphere = Lighting:FindFirstChild("AuraAtmosphere")
	if atmosphere and atmosphere:IsA("Atmosphere") then
		TweenService:Create(atmosphere, tweenInfo, {
			Color = accent:Lerp(PALETTE.Milk, 0.52),
			Decay = paletteBase:Lerp(PALETTE.Ink, 0.4),
			Density = tonumber(target.atmosphereDensity) or atmosphere.Density,
			Haze = tonumber(target.atmosphereHaze) or atmosphere.Haze,
		}):Play()
	end
	local bloom = Lighting:FindFirstChild("AuraBloom")
	if bloom and bloom:IsA("BloomEffect") then
		TweenService:Create(bloom, tweenInfo, {
			Intensity = tonumber(target.bloomIntensity) or bloom.Intensity,
			Size = tonumber(target.bloomSize) or bloom.Size,
		}):Play()
	end
	local colorCorrection = Lighting:FindFirstChild("AuraColor")
	if colorCorrection and colorCorrection:IsA("ColorCorrectionEffect") then
		TweenService:Create(colorCorrection, tweenInfo, {
			Saturation = if bloomState then 0.16 else 0.06,
			Contrast = if bloomState then 0.11 else 0.07,
			TintColor = accent:Lerp(PALETTE.Milk, if bloomState then 0.72 else 0.86),
		}):Play()
	end
end

function WorldService.Init(context: any): ()
	artDirectionRegistry = if type(context) == "table" then context.ArtDirectionRegistry else nil
	remixCatalog = if type(context) == "table" then context.RemixCatalog else nil
	premiumCityCatalog = if type(context) == "table" then context.PremiumCityCatalog else nil
	if artDirectionRegistry == nil then
		local sharedRoot = ReplicatedStorage:FindFirstChild("AuraRushShared")
		local registryModule = if sharedRoot
			then sharedRoot:FindFirstChild("ArtDirectionRegistry")
			else nil
		if registryModule and registryModule:IsA("ModuleScript") then
			local ok, registry = pcall(require, registryModule)
			if ok and type(registry) == "table" then
				artDirectionRegistry = registry
			end
		end
	end
	if premiumCityCatalog == nil then
		local sharedRoot = ReplicatedStorage:FindFirstChild("AuraRushShared")
		local premiumModule = if sharedRoot
			then sharedRoot:FindFirstChild("PremiumCityCatalog")
			else nil
		if premiumModule and premiumModule:IsA("ModuleScript") then
			local ok, registry = pcall(require, premiumModule)
			if ok and type(registry) == "table" then
				premiumCityCatalog = registry
			end
		end
	end
end

function WorldService.Build(): Model
	local previous = Workspace:FindFirstChild(WORLD_NAME)
	if previous then
		previous:Destroy()
	end

	table.clear(spawns)
	table.clear(activeRunSpawns)
	table.clear(activeRunCollectibles)
	table.clear(collectibles)
	table.clear(heroLandmarks)
	table.clear(guardianAnchors)
	table.clear(cityPulsePads)
	table.clear(cityPulseVisuals)
	table.clear(secretFrames)
	table.clear(secretFrameById)
	cityPulseCore = nil
	configureLighting()

	local root = Instance.new("Model")
	root.Name = WORLD_NAME
	root:SetAttribute("PresentationVersion", "remix_city_v6_ru")
	root:SetAttribute("HeroSliceVersion", 7)
	root:SetAttribute("VisualQualityPass", "premium_city_ring_v8")
	root:SetAttribute("MotionFeedbackContract", "pooled_local_v1")
	root:SetAttribute("PrimaryLanguage", "ru")
	root:SetAttribute("WorldCount", 6)
	root:SetAttribute("RemixCityVersion", 6)
	root:SetAttribute(
		"PremiumCityVersion",
		if premiumCityCatalog then premiumCityCatalog.Version else 0
	)
	root:SetAttribute("CityPulseProgress", 0)
	root:SetAttribute("CityPulseCompletionToken", 0)
	root:SetAttribute(
		"EncounterCellCount",
		if remixCatalog then #remixCatalog.EncounterCells else 0
	)
	root:SetAttribute("GuardianCount", if remixCatalog then #remixCatalog.Guardians else 0)
	root.Parent = Workspace
	rootModel = root

	buildHub(root)
	buildThreadRun(root)
	buildBeatLab(root)
	buildPrismPuzzle(root)
	buildMaterialSurf(root)
	buildLightLoom(root)
	buildBloomRescue(root)
	buildMixLab(root)
	buildMetroFinale(root)
	buildCloudFinale(root)
	buildGreenhouseFinale(root)
	buildBoardwalkFinale(root)
	buildVelvetArchiveFinale(root)
	buildSolarCathedralFinale(root)
	buildRemixGuardians(root)

	for _, child in root:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("StreamingFriendly") ~= true then
			configureStreamingZone(child, string.lower(child.Name))
		end
		if child:IsA("Model") then
			local basePartCount = 0
			for _, descendant in child:GetDescendants() do
				if descendant:IsA("BasePart") then
					basePartCount += 1
				end
			end
			child:SetAttribute("BasePartCount", basePartCount)
		end
	end

	return root
end

function WorldService.GetSpawn(phase: string, worldId: string?): CFrame
	if phase == "Finale" then
		local key = "Finale_" .. (worldId or "prism_metro")
		return spawns[key] or spawns.Finale_prism_metro or CFrame.new(0, 8, 300)
	end
	return activeRunSpawns[phase] or spawns[phase] or spawns.Hub or CFrame.new(0, 8, 0)
end

function WorldService.GetRoot(): Model?
	return rootModel
end

function WorldService.GetGuardianAnchor(worldId: string?): BasePart?
	return guardianAnchors[worldId or "prism_metro"]
end

function WorldService.PulseGuardian(worldId: string, alpha: number, matched: boolean): ()
	local anchor = guardianAnchors[worldId]
	if not anchor or not anchor.Parent then
		return
	end
	local progress = math.clamp(tonumber(alpha) or 0, 0, 1)
	local baseSize = tonumber(anchor:GetAttribute("BaseSize")) or 11
	local accent = colorFromHex(anchor:GetAttribute("AccentHex"), PALETTE.Purple)
	local model = anchor.Parent
	model:SetAttribute("Progress", progress)
	model:SetAttribute("LastPulseMatched", matched)
	TweenService
		:Create(anchor, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.one * (baseSize + progress * 8),
			Color = if matched then accent:Lerp(PALETTE.White, progress * 0.35) else PALETTE.Coral,
			Transparency = math.clamp(0.2 - progress * 0.12, 0.04, 0.2),
		})
		:Play()
end

function WorldService.GetCollectibles(actId: string?): { BasePart }
	local requestedAct = actId or "thread_run"
	local result = {}
	for _, collectible in WorldService.GetAllCollectibles() do
		if collectible:GetAttribute("ChallengeAct") == requestedAct then
			table.insert(result, collectible)
		end
	end
	return result
end

function WorldService.GetAllCollectibles(): { BasePart }
	local result = {}
	for _, source in { collectibles, activeRunCollectibles } do
		for _, collectible in source do
			if collectible.Parent then
				table.insert(result, collectible)
			end
		end
	end
	return result
end

function WorldService.ResetRound(roundId: string): ()
	bloomToken += 1
	activeBloomRecipe = nil
	table.clear(activeRunSpawns)
	table.clear(activeRunCollectibles)
	if rootModel then
		local activeRunGeometry = rootModel:FindFirstChild("ActiveRunGeometry")
		if activeRunGeometry then
			activeRunGeometry:Destroy()
		end
		rootModel:SetAttribute("BloomAct", nil)
		rootModel:SetAttribute("BloomActIndex", nil)
		rootModel:SetAttribute("BloomIntensity", nil)
		rootModel:SetAttribute("BloomRecipeVersion", nil)
		rootModel:SetAttribute("BloomWorldNameRu", nil)
		for _, child in rootModel:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("WorldId") ~= nil then
				child:SetAttribute("BloomStoryStage", nil)
				child:SetAttribute("BloomStoryIntensity", nil)
			end
		end
	end
	for _, instance in CollectionService:GetTagged(BLOOM_TAG) do
		if instance:IsA("BasePart") and instance.Parent then
			local baseHex = instance:GetAttribute("BaseColor")
			if type(baseHex) == "string" then
				local ok, color = pcall(Color3.fromHex, baseHex)
				if ok then
					instance.Color = color
				end
			end
			local materialName = instance:GetAttribute("BaseMaterial")
			if type(materialName) == "string" then
				local material = (Enum.Material :: any)[materialName]
				if material then
					instance.Material = material
				end
			end
			local baseTransparency = instance:GetAttribute("BaseTransparency")
			if type(baseTransparency) == "number" then
				instance.Transparency = math.clamp(baseTransparency, 0, 1)
			end
			local baseReflectance = instance:GetAttribute("BaseReflectance")
			if type(baseReflectance) == "number" then
				instance.Reflectance = math.clamp(baseReflectance, 0, 1)
			end
		end
	end
	configureLighting()
	for _, collectible in collectibles do
		collectible:SetAttribute("RoundId", roundId)
	end
	for worldId, anchor in guardianAnchors do
		if anchor.Parent then
			local baseSize = tonumber(anchor:GetAttribute("BaseSize")) or 11
			anchor.Size = Vector3.one * baseSize
			anchor.Color = colorFromHex(anchor:GetAttribute("AccentHex"), PALETTE.Purple)
			anchor.Transparency = 0.2
			anchor.Parent:SetAttribute("Progress", 0)
			anchor.Parent:SetAttribute("LastPulseMatched", nil)
		else
			guardianAnchors[worldId] = nil
		end
	end
	if rootModel then
		WorldService.SetCityPulse(
			math.clamp(tonumber(rootModel:GetAttribute("CityPulseProgress")) or 0, 0, 1),
			tostring(rootModel:GetAttribute("CityPulseEventId") or ""),
			tostring(rootModel:GetAttribute("CityPulseAccentHex") or "D6FF49"),
			rootModel:GetAttribute("CityPulseComplete") == true,
			tostring(rootModel:GetAttribute("CityPulsePreferredPadId") or "")
		)
	end
end

function WorldService.ApplyRunPlan(runPlan: any): ()
	if type(runPlan) ~= "table" then
		return
	end
	if rootModel then
		rootModel:SetAttribute("ActiveRouteId", tostring(runPlan.selectedRouteId or ""))
		rootModel:SetAttribute("ActiveRunVersion", tonumber(runPlan.version) or 1)
		rootModel:SetAttribute("ActiveRunSeamless", runPlan.seamless == true)
		rootModel:SetAttribute(
			"ActiveGuardianId",
			tostring(if type(runPlan.guardian) == "table" then runPlan.guardian.id or "" else "")
		)
		rootModel:SetAttribute(
			"ActiveModifierId",
			tostring(if type(runPlan.modifier) == "table" then runPlan.modifier.id or "" else "")
		)
		rootModel:SetAttribute(
			"ActiveVisualProfile",
			tostring(
				if type(runPlan.briefTreatment) == "table"
					then runPlan.briefTreatment.visualProfile or "open_canvas"
					else "open_canvas"
			)
		)
	end
	buildActiveRunGeometry(runPlan)
end

function WorldService.SetPhase(phase: string): ()
	if rootModel then
		rootModel:SetAttribute("ActivePhase", phase)
	end
end

function WorldService.SetActiveAct(actId: string?, sceneId: string?): ()
	if rootModel then
		rootModel:SetAttribute("ActiveAct", actId)
		rootModel:SetAttribute("ActiveScene", sceneId)
	end
end

function WorldService.AdvanceWorldBloom(actIndex: number): ()
	if not rootModel or type(activeBloomRecipe) ~= "table" then
		return
	end
	local index = math.clamp(math.floor(actIndex), 1, 3)
	local act = activeBloomRecipe.bloomActs and activeBloomRecipe.bloomActs[index]
	local actName = if type(act) == "table" and type(act.id) == "string"
		then act.id
		elseif index == 1 then "seed"
		elseif index == 2 then "cascade"
		else "bloom"
	local intensity = if type(act) == "table" and type(act.intensity) == "number"
		then math.clamp(act.intensity, 0, 1)
		else index / 3
	rootModel:SetAttribute("BloomAct", actName)
	rootModel:SetAttribute("BloomActIndex", index)
	rootModel:SetAttribute("BloomIntensity", intensity)

	local primaryColor = activeBloomRecipe.primaryColor
	if typeof(primaryColor) ~= "Color3" then
		local hex = activeBloomRecipe.primaryHex
		if type(hex) == "string" then
			local ok, parsed = pcall(Color3.fromHex, hex)
			if ok then
				primaryColor = parsed
			end
		end
	end
	if typeof(primaryColor) ~= "Color3" then
		primaryColor = PALETTE.Purple
	end
	local presentation = if type(activeBloomRecipe.presentation) == "table"
		then activeBloomRecipe.presentation
		else {}
	local paletteStops = if type(presentation.paletteStops) == "table"
		then presentation.paletteStops
		else { activeBloomRecipe.primaryHex }
	local colorBlend = math.clamp(tonumber(presentation.colorBlend) or 0.32, 0.16, 0.62)
	local emission = math.clamp(tonumber(presentation.emission) or 0.38, 0.1, 0.9)
	local recipeMaterialName = if type(presentation.materialName) == "string"
		then presentation.materialName
		else nil
	local recipeMaterial = if recipeMaterialName
		then (Enum.Material :: any)[recipeMaterialName]
		else nil
	local activeWorldId = tostring(activeBloomRecipe.worldId or "prism_metro")
	for _, child in rootModel:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("WorldId") == activeWorldId then
			child:SetAttribute("BloomStoryStage", index)
			child:SetAttribute("BloomStoryIntensity", intensity)
		end
	end

	for _, instance in CollectionService:GetTagged(BLOOM_TAG) do
		if
			instance:IsA("BasePart")
			and instance.Parent
			and instance:GetAttribute("WorldId") == activeWorldId
		then
			local baseColor = colorFromHex(instance:GetAttribute("BaseColor"), instance.Color)
			local paletteKey = instance.Name .. ":" .. tostring(instance:GetAttribute("BloomGroup"))
			local paletteIndex = if #paletteStops > 0
				then (stableHash(paletteKey) % #paletteStops) + 1
				else 1
			local genomeColor = colorFromHex(paletteStops[paletteIndex], primaryColor :: Color3)
			local baseTransparency = instance:GetAttribute("BaseTransparency")
			local targetTransparency = if type(baseTransparency) == "number"
				then math.clamp(baseTransparency, 0, 1)
				else instance.Transparency
			local targetColor = baseColor:Lerp(genomeColor, colorBlend * intensity)
			targetColor = targetColor:Lerp(primaryColor :: Color3, intensity * 0.12)
			local storyRole = instance:GetAttribute("BloomStoryRole")
			local revealStage = tonumber(instance:GetAttribute("BloomRevealStage")) or 1

			if storyRole == "DistrictReveal" and index >= revealStage then
				local authoredColor =
					colorFromHex(instance:GetAttribute("BloomTargetColor"), baseColor)
				targetColor = authoredColor:Lerp(genomeColor, 0.34 + colorBlend * 0.42)
				local authoredTransparency = instance:GetAttribute("BloomTargetTransparency")
				if type(authoredTransparency) == "number" then
					targetTransparency = math.clamp(authoredTransparency, 0, 1)
				end
				local targetMaterialName = instance:GetAttribute("BloomTargetMaterial")
				if type(targetMaterialName) == "string" then
					local targetMaterial = (Enum.Material :: any)[targetMaterialName]
					if targetMaterial then
						instance.Material = targetMaterial
					end
				end
				if recipeMaterial then
					instance.Material = recipeMaterial
				end
			elseif instance:GetAttribute("HeroLandmark") ~= nil then
				targetColor = baseColor:Lerp(genomeColor, intensity * (0.56 + colorBlend * 0.32))
				if recipeMaterial then
					instance.Material = recipeMaterial
				end
				instance.Reflectance = math.clamp(emission * 0.22, 0, 0.2)
			end

			TweenService:Create(
				instance,
				TweenInfo.new(0.72, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = targetColor, Transparency = targetTransparency }
			):Play()
		end
	end
	applyWorldLighting(activeWorldId, index >= 2, 0.85)
	local bloom = Lighting:FindFirstChild("AuraBloom")
	if bloom and bloom:IsA("BloomEffect") then
		TweenService
			:Create(bloom, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Intensity = math.clamp(0.12 + emission * intensity * 0.76, 0.12, 0.72),
				Size = math.clamp(22 + intensity * 22, 22, 44),
			})
			:Play()
	end
	local colorCorrection = Lighting:FindFirstChild("AuraColor")
	if colorCorrection and colorCorrection:IsA("ColorCorrectionEffect") then
		local paletteTint = colorFromHex(
			paletteStops[((index - 1) % math.max(#paletteStops, 1)) + 1],
			primaryColor :: Color3
		)
		TweenService:Create(
			colorCorrection,
			TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TintColor = paletteTint:Lerp(PALETTE.Milk, 0.68) }
		):Play()
	end
end

function WorldService.BeginWorldBloom(recipe: any, duration: number?): ()
	if type(recipe) ~= "table" then
		return
	end
	bloomToken += 1
	local token = bloomToken
	activeBloomRecipe = recipe
	if rootModel then
		rootModel:SetAttribute("BloomRecipeVersion", tonumber(recipe.version) or 1)
		rootModel:SetAttribute("BloomRoundId", tostring(recipe.roundId or ""))
		rootModel:SetAttribute("BloomWorldId", tostring(recipe.worldId or ""))
		rootModel:SetAttribute("BloomRouteId", tostring(recipe.routeId or ""))
		rootModel:SetAttribute("BloomPrimaryHex", tostring(recipe.primaryHex or "8250FF"))
		local presentation = if type(recipe.presentation) == "table"
			then recipe.presentation
			else {}
		rootModel:SetAttribute(
			"BloomMaterial",
			tostring(presentation.materialName or "SmoothPlastic")
		)
		rootModel:SetAttribute("BloomAuraPreset", tostring(presentation.auraPreset or "SoftSpark"))
		rootModel:SetAttribute("BloomAuraMotif", tostring(presentation.auraMotif or "spark"))
		rootModel:SetAttribute("BloomPosePreset", tostring(presentation.posePreset or "Hero"))
		rootModel:SetAttribute(
			"BloomCameraPreset",
			tostring(presentation.cameraPreset or "hero_arc")
		)
		rootModel:SetAttribute(
			"BloomLandmarkPreset",
			tostring(presentation.landmarkPreset or "orbit_rings")
		)
		rootModel:SetAttribute(
			"BloomRoutePattern",
			tostring(presentation.routePattern or "classic")
		)
		rootModel:SetAttribute(
			"BloomPerformance",
			math.clamp(tonumber(recipe.performance) or 0, 0, 1)
		)
		rootModel:SetAttribute(
			"BloomWorldNameRu",
			WORLD_RUSSIAN_NAMES[tostring(recipe.worldId or "")] or "Выбранный район"
		)
	end
	WorldService.AdvanceWorldBloom(1)
	local totalDuration = math.max(tonumber(duration) or 18, 3)
	task.delay(totalDuration * 0.28, function()
		if token == bloomToken then
			WorldService.AdvanceWorldBloom(2)
		end
	end)
	task.delay(totalDuration * 0.62, function()
		if token == bloomToken then
			WorldService.AdvanceWorldBloom(3)
		end
	end)
end

function WorldService.GetBloomRecipe(): any
	return activeBloomRecipe
end

function WorldService.GetHeroLandmarks(): { BasePart }
	return table.clone(heroLandmarks)
end

function WorldService.GetCityPulsePads(): { BasePart }
	return table.clone(cityPulsePads)
end

function WorldService.GetSecretFrames(): { BasePart }
	return table.clone(secretFrames)
end

function WorldService.GetSecretFrame(frameId: string): BasePart?
	return secretFrameById[frameId]
end

function WorldService.RevealSecretFrame(frameId: string): boolean
	local center = secretFrameById[frameId]
	if not center or not center.Parent then
		return false
	end
	local model = center.Parent
	local token = math.max(0, math.floor(tonumber(model:GetAttribute("RevealToken")) or 0)) + 1
	model:SetAttribute("RevealToken", token)
	model:SetAttribute("LastRevealedAt", Workspace:GetServerTimeNow())

	local previousHighlight = model:FindFirstChild("DiscoveryHighlight")
	if previousHighlight then
		previousHighlight:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "DiscoveryHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = center.Color
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = PALETTE.Milk
	highlight.OutlineTransparency = 0
	highlight.Parent = model

	local revealInfo = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(center, revealInfo, {
		Color = PALETTE.Milk,
		Transparency = 0.22,
	}):Play()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("SecretFrameEdge") == true then
			TweenService:Create(descendant, revealInfo, { Color = PALETTE.Milk }):Play()
		end
	end

	task.delay(2.6, function()
		if not model.Parent or model:GetAttribute("RevealToken") ~= token then
			return
		end
		local settleInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local baseColor = colorFromHex(center:GetAttribute("BaseColor"), PALETTE.Purple)
		local baseTransparency =
			math.clamp(tonumber(center:GetAttribute("BaseTransparency")) or 0.76, 0, 1)
		TweenService:Create(center, settleInfo, {
			Color = baseColor,
			Transparency = baseTransparency,
		}):Play()
		for _, descendant in model:GetDescendants() do
			if
				descendant:IsA("BasePart")
				and descendant:GetAttribute("SecretFrameEdge") == true
			then
				TweenService
					:Create(descendant, settleInfo, {
						Color = colorFromHex(
							descendant:GetAttribute("BaseColor"),
							descendant.Color
						),
					})
					:Play()
			end
		end
		if highlight.Parent then
			TweenService:Create(highlight, settleInfo, {
				FillTransparency = 1,
				OutlineTransparency = 1,
			}):Play()
			task.delay(settleInfo.Time, function()
				if highlight.Parent then
					highlight:Destroy()
				end
			end)
		end
	end)
	return true
end

function WorldService.SetCityPulse(
	alphaValue: number,
	eventId: string,
	accentHex: string,
	complete: boolean,
	preferredPadId: string?
): ()
	local alpha = math.clamp(tonumber(alphaValue) or 0, 0, 1)
	local accent = colorFromHex(accentHex, PALETTE.Acid)
	if rootModel then
		local wasComplete = rootModel:GetAttribute("CityPulseComplete") == true
		rootModel:SetAttribute("CityPulseProgress", alpha)
		rootModel:SetAttribute("CityPulseEventId", string.sub(eventId, 1, 64))
		rootModel:SetAttribute("CityPulseAccentHex", accent:ToHex())
		rootModel:SetAttribute("CityPulseComplete", complete)
		rootModel:SetAttribute("CityPulsePreferredPadId", string.sub(preferredPadId or "", 1, 24))
		if complete and not wasComplete then
			rootModel:SetAttribute(
				"CityPulseCompletionToken",
				math.max(
					0,
					math.floor(tonumber(rootModel:GetAttribute("CityPulseCompletionToken")) or 0)
				) + 1
			)
		end
	end
	for index, visual in cityPulseVisuals do
		if visual.Parent then
			local baseColor = colorFromHex(visual:GetAttribute("PulseBaseColor"), visual.Color)
			local cadence = ((index - 1) % 6) / 5
			visual.Color =
				baseColor:Lerp(accent, math.clamp(alpha * (0.48 + cadence * 0.28), 0, 0.88))
			local baseTransparency = tonumber(visual:GetAttribute("PulseBaseTransparency"))
			if baseTransparency then
				visual.Transparency = math.clamp(baseTransparency - alpha * 0.08, 0, 0.85)
			end
		end
	end
	if cityPulseCore and cityPulseCore.Parent then
		cityPulseCore.Color = accent:Lerp(PALETTE.Milk, if complete then 0.2 else 0.48)
		local light = cityPulseCore:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = accent
			light.Brightness = 0.8 + alpha * 1.3
			light.Range = 24 + alpha * 14
		end
	end
	for _, pad in cityPulsePads do
		if pad.Parent then
			local baseColor = colorFromHex(pad:GetAttribute("PulseBaseColor"), pad.Color)
			local preferred = tostring(pad:GetAttribute("PulsePadId") or "")
				== (preferredPadId or "")
			pad.Color = if preferred
				then baseColor:Lerp(PALETTE.Milk, 0.24 + alpha * 0.2)
				else baseColor:Lerp(PALETTE.Ink, 0.16)
			pad.Transparency = if preferred then 0 else 0.12
		end
	end
end

function WorldService.TriggerGlowstorm(hostName: string?): ()
	glowstormToken += 1
	local token = glowstormToken
	local previousCelebration = Workspace:FindFirstChild("AuraRushGlowstorm")
	if previousCelebration then
		previousCelebration:Destroy()
	end
	for _, effectName in { "AuraRushGlowstormColor", "AuraRushGlowstormBloom" } do
		local previousEffect = Lighting:FindFirstChild(effectName)
		if previousEffect then
			previousEffect:Destroy()
		end
	end

	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "AuraRushGlowstormColor"
	color.Enabled = false
	color.Brightness = 0
	color.Contrast = 0
	color.Saturation = 0
	color.TintColor = Color3.fromRGB(255, 255, 255)
	color.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "AuraRushGlowstormBloom"
	bloom.Enabled = false
	bloom.Intensity = 0
	bloom.Size = 42
	bloom.Threshold = 0.85
	bloom.Parent = Lighting

	local celebration = Instance.new("Model")
	celebration.Name = "AuraRushGlowstorm"
	celebration:SetAttribute("Host", hostName or "Автор выхода")
	celebration:SetAttribute("ExpiresAt", Workspace:GetServerTimeNow() + 12)
	celebration:SetAttribute("PresentationVersion", 2)
	celebration:SetAttribute("ClientLocal", true)
	celebration:SetAttribute("Palette", "4DEAFF,FF4FD8,B9FF66,FFD166,8C6CFF")
	celebration:SetAttribute("Seed", math.floor(Workspace:GetServerTimeNow() * 1000) % 2147483646)
	celebration.Parent = Workspace

	local center = (spawns.Hub or CFrame.new(0, 8, 0)).Position
	celebration:SetAttribute("CenterX", center.X)
	celebration:SetAttribute("CenterY", center.Y)
	celebration:SetAttribute("CenterZ", center.Z)

	task.delay(12, function()
		if token ~= glowstormToken then
			return
		end
		celebration:Destroy()
		color:Destroy()
		bloom:Destroy()
	end)
end

WorldService.BLOOM_TAG = BLOOM_TAG
WorldService.COLLECTIBLE_TAG = COLLECTIBLE_TAG

return WorldService
