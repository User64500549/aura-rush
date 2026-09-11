--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AppModule = require(script.Parent.Parent.UI.App)
local RemoteRegistryModule = require(script.Parent.RemoteRegistry)
local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local ArtDirectionRegistry = require(sharedRoot:WaitForChild("ArtDirectionRegistry"))

type App = AppModule.App
type RemoteRegistry = RemoteRegistryModule.RemoteRegistry
type AnyMap = { [string]: any }

local VfxDirector = {}
VfxDirector.__index = VfxDirector

local WORLD_FOCUS_NAMES = table.freeze({
	prism_metro = "MetroRunway",
	cloud_bazaar = "CloudIsland",
	moonlit_greenhouse = "GreenhouseFloor",
	orbital_boardwalk = "OrbitDeck",
	velvet_archive = "VelvetRunway",
	solar_cathedral = "SunAisle",
})

local WORLD_MOTIFS = table.freeze({
	prism_metro = "signal",
	cloud_bazaar = "pearl",
	moonlit_greenhouse = "petal",
	orbital_boardwalk = "orbit",
	velvet_archive = "page",
	solar_cathedral = "shard",
})

local MOTION_FEEDBACK = table.freeze({
	version = 1,
	clientOnly = true,
	extraRemotes = 0,
	pooled = true,
	entryPhase = "Loading",
	stepDistance = table.freeze({
		Low = 4.4,
		Balanced = 3.2,
		High = 2.6,
	}),
})

local MOTION_PHASES = table.freeze({
	Loading = true,
	Waiting = true,
	Intermission = true,
	BriefChoice = true,
	ThreadRun = true,
	BeatLab = true,
	PrismPuzzle = true,
	MixLab = true,
})

export type VfxDirector = typeof(setmetatable(
	{} :: {
		App: App,
		Remotes: RemoteRegistry,
		Folder: Folder,
		Pool: { Part },
		Generation: { [Part]: number },
		Connections: { RBXScriptConnection },
		Settings: AppModule.AccessibilitySettings,
		QualityTier: string,
		SequenceToken: number,
		Random: Random,
		CurrentWorldId: string,
		FrameSeconds: number,
		FrameCount: number,
		MotionLastPosition: Vector3?,
		MotionDistance: number,
		MotionSide: number,
	},
	VfxDirector
))

function VfxDirector.GetMotionFeedbackContract(): AnyMap
	return {
		version = MOTION_FEEDBACK.version,
		clientOnly = MOTION_FEEDBACK.clientOnly,
		extraRemotes = MOTION_FEEDBACK.extraRemotes,
		pooled = MOTION_FEEDBACK.pooled,
		entryPhase = MOTION_FEEDBACK.entryPhase,
		stepDistance = table.clone(MOTION_FEEDBACK.stepDistance),
	}
end

local function colorFromValue(value: any): Color3
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		local clean = string.gsub(value, "#", "")
		local packed = if #clean == 6 then tonumber(clean, 16) else nil
		if packed then
			return Color3.fromRGB(
				math.floor(packed / 65536) % 256,
				math.floor(packed / 256) % 256,
				packed % 256
			)
		end
	end
	return Color3.fromRGB(140, 108, 255)
end

local function makeSpark(parent: Instance, index: number): Part
	local part = Instance.new("Part")
	part.Name = `Spark{index}`
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.24, 0.24, 0.24)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent

	local tail = Instance.new("Attachment")
	tail.Name = "Tail"
	tail.Position = Vector3.new(0, -0.5, 0)
	tail.Parent = part
	local head = Instance.new("Attachment")
	head.Name = "Head"
	head.Position = Vector3.new(0, 0.5, 0)
	head.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "MotionTrail"
	trail.Attachment0 = tail
	trail.Attachment1 = head
	trail.Enabled = false
	trail.FaceCamera = true
	trail.LightEmission = 0.45
	trail.Lifetime = 0.22
	trail.MinLength = 0.15
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = part
	return part
end

function VfxDirector.new(app: App, remotes: RemoteRegistry): VfxDirector
	local old = workspace:FindFirstChild("AuraRushLocalVfx")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "AuraRushLocalVfx"
	folder.Parent = workspace

	local pool: { Part } = {}
	for index = 1, 32 do
		table.insert(pool, makeSpark(folder, index))
	end

	local self: VfxDirector = setmetatable({
		App = app,
		Remotes = remotes,
		Folder = folder,
		Pool = pool,
		Generation = {},
		Connections = {},
		Settings = app:GetSettings(),
		QualityTier = "Balanced",
		SequenceToken = 0,
		Random = Random.new(),
		CurrentWorldId = "prism_metro",
		FrameSeconds = 0,
		FrameCount = 0,
		MotionLastPosition = nil,
		MotionDistance = 0,
		MotionSide = 1,
	}, VfxDirector)

	self:_updateQuality()
	self:_bind()
	return self
end

function VfxDirector._bind(self: VfxDirector)
	self.App:On("LocalSettingsChanged", function(settings: any)
		if type(settings) == "table" then
			self.Settings = table.clone(settings)
			self:_updateQuality()
			if
				settings.lowVfx == true
				or settings.reducedMotion == true
				or settings.noFlashes == true
			then
				self:_releaseAll()
			end
		end
	end)
	self.App:On("PhaseChanged", function(phase: string)
		self.MotionLastPosition = nil
		self.MotionDistance = 0
		if phase ~= "Finale" then
			self.SequenceToken += 1
			self:_releaseAll()
		end
	end)
	self.App:On("BeatHit", function()
		if
			not self.Settings.lowVfx
			and not self.Settings.reducedMotion
			and not self.Settings.noFlashes
		then
			self:_emitPlayerSpark()
		end
	end)
	self.App:On("SnapshotApplied", function(snapshot: any)
		if type(snapshot) ~= "table" then
			return
		end
		local brief = snapshot.selectedBrief
		local runPlan = snapshot.runPlan
		local worldId = if type(runPlan) == "table" then runPlan.worldId else nil
		if type(worldId) ~= "string" and type(brief) == "table" then
			worldId = brief.WorldId or brief.worldId
		end
		if type(worldId) == "string" and WORLD_MOTIFS[worldId] then
			self.CurrentWorldId = worldId
		end
	end)

	local bloomEvent = self.Remotes:GetEvent("BloomStarted")
	if bloomEvent then
		table.insert(
			self.Connections,
			bloomEvent.OnClientEvent:Connect(function(payload: any)
				if type(payload) == "table" then
					self:_scheduleBloom(payload)
				end
			end)
		)
	end
	local remixEvent = self.Remotes:GetEvent("RemixUpdate")
	if remixEvent then
		table.insert(
			self.Connections,
			remixEvent.OnClientEvent:Connect(function(payload: any)
				if
					type(payload) ~= "table"
					or self.Settings.lowVfx
					or self.Settings.reducedMotion
					or self.Settings.noFlashes
				then
					return
				end
				local count = if payload.kind == "GuardianComplete"
					then 8
					elseif payload.kind == "GuardianProgress" then 2
					else 0
				for index = 1, count do
					task.delay((index - 1) * 0.05, function()
						if self.Folder.Parent then
							self:_emitPlayerSpark()
						end
					end)
				end
			end)
		)
	end
	local function handleGlowstorm(instance: Instance): ()
		if instance.Name == "AuraRushGlowstorm" and instance:IsA("Model") then
			self:_playGlowstorm(instance)
		end
	end
	table.insert(self.Connections, workspace.ChildAdded:Connect(handleGlowstorm))
	local activeGlowstorm = workspace:FindFirstChild("AuraRushGlowstorm")
	if activeGlowstorm then
		handleGlowstorm(activeGlowstorm)
	end

	local camera = workspace.CurrentCamera
	if camera then
		table.insert(
			self.Connections,
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:_updateQuality()
			end)
		)
	end
	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function(deltaTime: number)
			self.FrameSeconds += math.clamp(deltaTime, 0, 0.25)
			self.FrameCount += 1
			self:_updateMotionFeedback()
			if self.FrameSeconds >= 2.5 then
				local measuredFps = self.FrameCount / math.max(self.FrameSeconds, 0.01)
				self.FrameSeconds = 0
				self.FrameCount = 0
				self:_updateQuality(measuredFps)
			end
		end)
	)
end

function VfxDirector._playGlowstorm(self: VfxDirector, marker: Model): ()
	if marker:GetAttribute("AuraRushLocalPlayed") == true then
		return
	end
	marker:SetAttribute("AuraRushLocalPlayed", true)
	local host = tostring(marker:GetAttribute("Host") or "Команда")
	self.App:ShowCaption(`{host}: район сияет`, 2.8, "Success")
	if self.Settings.reducedMotion or self.Settings.noFlashes then
		return
	end

	local center = Vector3.new(
		tonumber(marker:GetAttribute("CenterX")) or 0,
		tonumber(marker:GetAttribute("CenterY")) or 8,
		tonumber(marker:GetAttribute("CenterZ")) or 0
	)
	local palette = string.split(
		tostring(marker:GetAttribute("Palette") or "4DEAFF,FF4FD8,B9FF66,FFD166,8C6CFF"),
		","
	)
	local counts = { Minimal = 0, Low = 5, Balanced = 12, High = 20 }
	local count = counts[self.QualityTier] or 8
	for index = 1, count do
		task.delay((index - 1) * 0.045, function()
			if
				marker.Parent
				and not self.Settings.reducedMotion
				and not self.Settings.noFlashes
			then
				self:_spark(
					center + Vector3.new(0, 4 + (index % 4) * 1.5, 0),
					colorFromValue(palette[((index - 1) % math.max(#palette, 1)) + 1]),
					if self.Settings.lowVfx then 0.75 else 1.15,
					self.CurrentWorldId,
					if index % 3 == 0 then "ribbon" else "spark"
				)
			end
		end)
	end

	if self.Settings.lowVfx then
		return
	end
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "AuraRushGlowstormLocalColor"
	color.Brightness = 0
	color.Contrast = 0
	color.Saturation = 0
	color.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "AuraRushGlowstormLocalBloom"
	bloom.Intensity = 0
	bloom.Size = 32
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
	TweenService:Create(
		color,
		TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0.025, Contrast = 0.07, Saturation = 0.14 }
	):Play()
	TweenService:Create(
		bloom,
		TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Intensity = 0.34 }
	):Play()
	task.delay(2.5, function()
		if color.Parent then
			TweenService:Create(color, TweenInfo.new(2), {
				Brightness = 0,
				Contrast = 0,
				Saturation = 0,
			}):Play()
		end
		if bloom.Parent then
			TweenService:Create(bloom, TweenInfo.new(2), { Intensity = 0 }):Play()
		end
	end)
	task.delay(4.7, function()
		color:Destroy()
		bloom:Destroy()
	end)
end

function VfxDirector._updateQuality(self: VfxDirector, measuredFps: number?)
	if self.Settings.reducedMotion or self.Settings.lowVfx or self.Settings.noFlashes then
		self.QualityTier = "Minimal"
	else
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local pixels = viewport.X * viewport.Y
		if UserInputService.TouchEnabled and pixels < 1_200_000 then
			self.QualityTier = "Low"
		elseif pixels >= 2_000_000 and not UserInputService.TouchEnabled then
			self.QualityTier = "High"
		else
			self.QualityTier = "Balanced"
		end
		if measuredFps and measuredFps < 27 then
			self.QualityTier = "Minimal"
		elseif measuredFps and measuredFps < 42 and self.QualityTier ~= "Minimal" then
			self.QualityTier = "Low"
		end
	end
	self.Folder:SetAttribute("QualityTier", self.QualityTier)
end

function VfxDirector._acquire(self: VfxDirector): (Part?, number)
	for _, part in self.Pool do
		if part.Transparency >= 1 then
			local generation = (self.Generation[part] or 0) + 1
			self.Generation[part] = generation
			return part, generation
		end
	end
	return nil, 0
end

function VfxDirector._release(self: VfxDirector, part: Part, generation: number)
	if self.Generation[part] ~= generation then
		return
	end
	part.Transparency = 1
	part.Size = Vector3.new(0.24, 0.24, 0.24)
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Orientation = Vector3.zero
	part:SetAttribute("EffectKind", nil)
	local trail = part:FindFirstChild("MotionTrail")
	if trail and trail:IsA("Trail") then
		trail.Enabled = false
	end
end

function VfxDirector._releaseAll(self: VfxDirector)
	for _, part in self.Pool do
		self.Generation[part] = (self.Generation[part] or 0) + 1
		part.Transparency = 1
		part.Size = Vector3.new(0.24, 0.24, 0.24)
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Orientation = Vector3.zero
		part:SetAttribute("EffectKind", nil)
		local trail = part:FindFirstChild("MotionTrail")
		if trail and trail:IsA("Trail") then
			trail.Enabled = false
		end
	end
end

function VfxDirector._updateMotionFeedback(self: VfxDirector)
	local phase = self.App:GetPhase()
	local threshold = MOTION_FEEDBACK.stepDistance[self.QualityTier]
	if
		MOTION_PHASES[phase] ~= true
		or type(threshold) ~= "number"
		or self.Settings.lowVfx
		or self.Settings.reducedMotion
		or self.Settings.noFlashes
	then
		self.MotionLastPosition = nil
		self.MotionDistance = 0
		return
	end

	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		not root
		or not root:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
		or humanoid.MoveDirection.Magnitude < 0.05
	then
		self.MotionLastPosition = nil
		return
	end

	local position = root.Position
	local previous = self.MotionLastPosition
	self.MotionLastPosition = position
	if not previous then
		return
	end

	local planarDelta = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z)
	local moved = math.min(planarDelta.Magnitude, 7)
	if moved < 0.025 then
		return
	end
	self.MotionDistance += moved
	if self.MotionDistance < threshold then
		return
	end

	self.MotionDistance %= threshold
	self.MotionSide *= -1
	self:_emitMotionSignal(root, planarDelta.Unit, self.MotionSide)
end

function VfxDirector._emitMotionSignal(
	self: VfxDirector,
	root: BasePart,
	direction: Vector3,
	side: number
)
	local character = root.Parent
	if not character then
		return
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character, self.Folder }
	raycastParams.IgnoreWater = true
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -7, 0), raycastParams)
	if not hit then
		return
	end

	local part, generation = self:_acquire()
	if not part then
		return
	end
	local signal = part :: Part
	local profile = ArtDirectionRegistry.GetWorld(self.CurrentWorldId)
	local accent = colorFromValue(if profile then profile.accentHex else nil)
	local reactive = hit.Instance:GetAttribute("ReactiveSignal") == true
	local color = if reactive then hit.Instance.Color:Lerp(accent, 0.34) else accent
	local up = hit.Normal
	local right = up:Cross(direction)
	if right.Magnitude < 0.05 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end
	local position = hit.Position + up * 0.055 + right * (side * 0.42)
	local signalCFrame = CFrame.lookAt(position, position + direction, up)

	signal:SetAttribute("EffectKind", if reactive then "RouteResponse" else "StyleStep")
	signal.Shape = Enum.PartType.Block
	signal.Material = Enum.Material.Neon
	signal.Color = color:Lerp(Color3.new(1, 1, 1), if reactive then 0.26 else 0.12)
	signal.Size = if reactive then Vector3.new(1.45, 0.065, 2.25) else Vector3.new(1.05, 0.055, 1.7)
	signal.CFrame = signalCFrame
	signal.Transparency = if reactive then 0.08 else 0.22
	local trail = signal:FindFirstChild("MotionTrail")
	if trail and trail:IsA("Trail") then
		trail.Enabled = false
	end
	local duration = if self.QualityTier == "High" then 0.62 else 0.48
	TweenService
		:Create(signal, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = if reactive
				then Vector3.new(2.25, 0.035, 3.15)
				else Vector3.new(1.7, 0.03, 2.45),
			Transparency = 1,
		})
		:Play()
	task.delay(duration + 0.08, function()
		if signal.Parent then
			self:_release(signal, generation)
		end
	end)
end

function VfxDirector._spark(
	self: VfxDirector,
	center: Vector3,
	color: Color3,
	scale: number,
	worldId: string?,
	motifOverride: string?
)
	local part, generation = self:_acquire()
	if not part then
		return
	end
	local spark = part :: Part
	local theta = self.Random:NextNumber(0, math.pi * 2)
	local radius = self.Random:NextNumber(2.5, 10) * scale
	local start = center
		+ Vector3.new(
			math.cos(theta) * radius,
			self.Random:NextNumber(0.5, 5) * scale,
			math.sin(theta) * radius
		)
	local rise = self.Random:NextNumber(3, 8) * scale
	local size = self.Random:NextNumber(0.18, 0.46) * scale
	local motif = motifOverride or WORLD_MOTIFS[worldId or self.CurrentWorldId] or "signal"
	local shapeMotif = if motif == "bubble"
			or motif == "jelly"
			or motif == "mist"
		then "pearl"
		else if motif == "petal"
				or motif == "bloom"
				or motif == "heart"
			then "petal"
			else if motif == "star" or motif == "ray"
				then "shard"
				else if motif == "ribbon"
						or motif == "comet"
						or motif == "rain"
						or motif == "aurora"
						or motif == "pulse"
					then "signal"
					else motif
	spark.Color = color:Lerp(Color3.new(1, 1, 1), self.Random:NextNumber(0.05, 0.42))
	spark.Position = start
	spark.Material = Enum.Material.Neon
	if shapeMotif == "pearl" then
		spark.Shape = Enum.PartType.Ball
		spark.Material = Enum.Material.Glass
		spark.Size = Vector3.new(size * 1.8, size * 1.8, size * 1.8)
	elseif shapeMotif == "petal" then
		spark.Shape = Enum.PartType.Block
		spark.Size = Vector3.new(size * 2.6, size * 0.34, size * 1.35)
	elseif shapeMotif == "orbit" then
		spark.Shape = Enum.PartType.Cylinder
		spark.Size = Vector3.new(size * 0.45, size * 2.1, size * 2.1)
	elseif shapeMotif == "page" then
		spark.Shape = Enum.PartType.Block
		spark.Material = Enum.Material.SmoothPlastic
		spark.Size = Vector3.new(size * 2.5, size * 0.18, size * 1.65)
	elseif shapeMotif == "shard" then
		spark.Shape = Enum.PartType.Block
		spark.Material = Enum.Material.Glass
		spark.Size = Vector3.new(size * 0.42, size * 3.2, size * 0.7)
	else
		spark.Shape = Enum.PartType.Block
		spark.Size = Vector3.new(size * 0.48, size * 2.7, size * 0.48)
	end
	spark.Orientation = Vector3.new(
		self.Random:NextNumber(-35, 35),
		self.Random:NextNumber(0, 180),
		self.Random:NextNumber(-24, 24)
	)
	spark.Transparency = 0.12
	local trail = spark:FindFirstChild("MotionTrail")
	if trail and trail:IsA("Trail") then
		trail.Color = ColorSequence.new(spark.Color, spark.Color:Lerp(Color3.new(1, 1, 1), 0.5))
		trail.Enabled = shapeMotif == "signal" or shapeMotif == "orbit" or shapeMotif == "shard"
	end
	TweenService:Create(
		spark,
		TweenInfo.new(
			self.Random:NextNumber(0.75, 1.4),
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Position = start + Vector3.new(
				self.Random:NextNumber(-2.5, 2.5) * scale,
				rise,
				self.Random:NextNumber(-2.5, 2.5) * scale
			),
			Size = Vector3.new(size * 0.32, size * 0.32, size * 0.32),
			Orientation = spark.Orientation + Vector3.new(
				self.Random:NextNumber(-80, 80),
				self.Random:NextNumber(80, 220),
				self.Random:NextNumber(-70, 70)
			),
			Transparency = 1,
		}
	):Play()
	task.delay(1.5, function()
		if spark.Parent then
			self:_release(spark, generation)
		end
	end)
end

function VfxDirector._worldCenter(_self: VfxDirector, payload: AnyMap): Vector3
	local worldId = if type(payload.worldId) == "string" then payload.worldId else "prism_metro"
	local focusName = WORLD_FOCUS_NAMES[worldId]
	local focus = if focusName then workspace:FindFirstChild(focusName, true) else nil
	if focus and focus:IsA("BasePart") then
		return focus.Position + Vector3.new(0, 5, 0)
	elseif focus and focus:IsA("Model") then
		return focus:GetPivot().Position + Vector3.new(0, 5, 0)
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position else Vector3.new(0, 8, 0)
end

function VfxDirector._scheduleBloom(self: VfxDirector, payload: AnyMap)
	self.SequenceToken += 1
	local token = self.SequenceToken
	local worldId = if type(payload.worldId) == "string"
		then payload.worldId
		else self.CurrentWorldId
	self.CurrentWorldId = if WORLD_MOTIFS[worldId] then worldId else "prism_metro"
	local startsAt = tonumber(payload.startsAt or payload.startTime) or workspace:GetServerTimeNow()
	task.delay(math.max(0, startsAt - workspace:GetServerTimeNow()), function()
		if
			token ~= self.SequenceToken
			or self.Settings.reducedMotion
			or self.Settings.noFlashes
		then
			return
		end
		local counts = { Minimal = 2, Low = 7, Balanced = 14, High = 24 }
		local recipe = if type(payload.recipe) == "table" then payload.recipe else {}
		local presentation = if type(recipe.presentation) == "table"
			then recipe.presentation
			else {}
		local intensity = math.clamp(tonumber(presentation.intensity) or 0.72, 0.4, 1)
		local count = math.max(1, math.floor((counts[self.QualityTier] or 10) * intensity))
		local center = self:_worldCenter(payload)
		local profile = ArtDirectionRegistry.GetWorld(self.CurrentWorldId)
		local profilePalette = if type(presentation.paletteStops) == "table"
			then presentation.paletteStops
			else if profile and type(profile.palette) == "table" then profile.palette else {}
		local baseColor = colorFromValue(
			recipe.primaryColor or recipe.primaryHex or payload.color or payload.accentHex
		)
		local auraMotif = if type(presentation.auraMotif) == "string"
			then presentation.auraMotif
			else nil
		local duration = math.max(tonumber(payload.duration) or 8, 3)
		for stage = 1, 3 do
			local profileHex = profilePalette[((stage - 1) % math.max(#profilePalette, 1)) + 1]
			local stageColor = baseColor:Lerp(colorFromValue(profileHex), 0.24 + stage * 0.08)
			local stageCount = math.max(1, math.floor(count * (0.54 + stage * 0.12)))
			local stageDelay = (stage - 1) * math.min(duration * 0.21, 1.8)
			for index = 1, stageCount do
				task.delay(stageDelay + (index - 1) * 0.035, function()
					if token == self.SequenceToken and self.App:GetPhase() == "Finale" then
						self:_spark(
							center + Vector3.new(0, (stage - 1) * 3.5, 0),
							stageColor,
							(1.05 + stage * 0.16) * (0.8 + intensity * 0.3),
							self.CurrentWorldId,
							auraMotif
						)
					end
				end)
			end
		end
	end)
end

function VfxDirector._emitPlayerSpark(self: VfxDirector)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local profile = ArtDirectionRegistry.GetWorld(self.CurrentWorldId)
		local color = colorFromValue(if profile then profile.accentHex else nil)
		self:_spark(root.Position + Vector3.new(0, 2, 0), color, 0.45, self.CurrentWorldId)
	end
end

function VfxDirector.Destroy(self: VfxDirector)
	self.SequenceToken += 1
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Folder:Destroy()
end

return VfxDirector
