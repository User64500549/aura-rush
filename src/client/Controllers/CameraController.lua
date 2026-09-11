--!strict

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AppModule = require(script.Parent.Parent.UI.App)
local RemoteRegistryModule = require(script.Parent.RemoteRegistry)
local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local ArtDirectionRegistry = require(sharedRoot:WaitForChild("ArtDirectionRegistry"))

type App = AppModule.App
type RemoteRegistry = RemoteRegistryModule.RemoteRegistry
type AnyMap = { [string]: any }

local CameraController = {}
CameraController.__index = CameraController

local WORLD_GROUPS = table.freeze({
	prism_metro = "Metro",
	cloud_bazaar = "Cloud",
	moonlit_greenhouse = "Greenhouse",
	orbital_boardwalk = "Boardwalk",
	velvet_archive = "VelvetArchive",
	solar_cathedral = "SolarCathedral",
})

local WORLD_FOCUS_NAMES = table.freeze({
	prism_metro = "MetroRunway",
	cloud_bazaar = "CloudIsland",
	moonlit_greenhouse = "GreenhouseFloor",
	orbital_boardwalk = "OrbitDeck",
	velvet_archive = "VelvetRunway",
	solar_cathedral = "SunAisle",
})

export type CameraController = typeof(setmetatable(
	{} :: {
		App: App,
		Remotes: RemoteRegistry,
		Connections: { RBXScriptConnection },
		BloomEffect: BloomEffect,
		ColorEffect: ColorCorrectionEffect,
		DepthEffect: DepthOfFieldEffect,
		SequenceToken: number,
		Active: boolean,
		ActiveTweens: { Tween },
		EffectTweens: { Tween },
		WorldTweens: { Tween },
		PreviousCameraType: Enum.CameraType?,
		PreviousCameraSubject: Instance?,
		PreviousFieldOfView: number,
		PreviousLighting: AnyMap,
		ArrivalFramed: boolean,
		ArrivalQueued: boolean,
		ArrivalToken: number,
		RouteArrivalToken: number,
	},
	CameraController
))

local function getHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function colorFromHex(value: any): Color3?
	if type(value) ~= "string" then
		return nil
	end
	local clean = string.gsub(value, "#", "")
	if #clean ~= 6 then
		return nil
	end
	local packed = tonumber(clean, 16)
	if not packed then
		return nil
	end
	return Color3.fromRGB(
		math.floor(packed / 65536) % 256,
		math.floor(packed / 256) % 256,
		packed % 256
	)
end

local function getWorldId(payload: AnyMap): string
	local value = payload.worldId or payload.WorldId
	local brief = payload.brief
	if type(value) ~= "string" and type(brief) == "table" then
		value = brief.WorldId or brief.worldId
	end
	return if type(value) == "string" then value else "prism_metro"
end

local function getWorldArtProfile(worldId: string): AnyMap?
	local ok, profile = pcall(ArtDirectionRegistry.GetWorld, worldId)
	return if ok and type(profile) == "table" then profile else nil
end

local function findAtmosphere(): Atmosphere?
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	return if atmosphere and atmosphere:IsA("Atmosphere") then atmosphere else nil
end

local function prefetchPosition(position: Vector3): ()
	-- Finale landmarks may live outside the current streaming radius. Prefetch is
	-- opportunistic and never blocks the camera if the API is unavailable.
	task.spawn(function()
		pcall(function()
			(workspace :: any):RequestStreamAroundAsync(position, 3)
		end)
	end)
end

local function getCameraCFrame(worldId: string): CFrame?
	local specific = workspace:FindFirstChild(`FinaleCamera_{worldId}`, true)
	local generic = workspace:FindFirstChild("FinaleCamera", true)
	local anchor = specific or generic
	if anchor then
		if anchor:IsA("BasePart") then
			return anchor.CFrame
		elseif anchor:IsA("Model") then
			return anchor:GetPivot()
		end
	end

	local focusName = WORLD_FOCUS_NAMES[worldId]
	local focus = if focusName then workspace:FindFirstChild(focusName, true) else nil
	if focus and focus:IsA("BasePart") then
		local target = focus.Position + Vector3.new(0, 8, 0)
		return CFrame.lookAt(target + Vector3.new(42, 22, -54), target)
	end
	return nil
end

local function getFocusPosition(worldId: string, cameraCFrame: CFrame): Vector3
	local focusName = WORLD_FOCUS_NAMES[worldId]
	local focus = if focusName then workspace:FindFirstChild(focusName, true) else nil
	if focus then
		if focus:IsA("BasePart") then
			return focus.Position + Vector3.new(0, 7, 0)
		elseif focus:IsA("Model") then
			return focus:GetPivot().Position + Vector3.new(0, 7, 0)
		end
	end
	return cameraCFrame.Position + cameraCFrame.LookVector * 48
end

local function getCameraShots(worldId: string, twistId: string, cameraPreset: string?): { CFrame }
	local opening = getCameraCFrame(worldId)
	if not opening then
		return {}
	end
	local target = getFocusPosition(worldId, opening)
	local radial = opening.Position - target
	local distance = radial.Magnitude
	if distance < 8 then
		radial = Vector3.new(0.6, 0.28, -1)
		distance = 54
	end
	radial = radial.Unit
	local right = Vector3.new(0, 1, 0):Cross(radial)
	if right.Magnitude < 0.01 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end
	local first = opening
	if twistId == "zero_gravity" or cameraPreset == "zero_g_roll" then
		first *= CFrame.Angles(math.rad(-4), 0, math.rad(7))
	end
	local lateralScale = if cameraPreset == "editorial_sweep"
		then 0.24
		else if cameraPreset == "duo_mirror" then 0.18 else 0.13
	local heightScale = if cameraPreset == "squad_skyline"
		then 14
		else if cameraPreset == "soft_orbit" then 7 else 4
	local secondPosition = target
		+ radial * (distance * 0.78)
		+ right * (distance * lateralScale)
		+ Vector3.new(0, heightScale, 0)
	local thirdPosition = target
		+ radial * (distance * (if cameraPreset == "hero_arc" then 1.08 else 0.96))
		- right * (distance * (if cameraPreset == "duo_mirror" then lateralScale else 0.1))
		+ Vector3.new(0, if cameraPreset == "squad_skyline" then 18 else 9, 0)
	return {
		first,
		CFrame.lookAt(secondPosition, target + Vector3.new(0, 2, 0)),
		CFrame.lookAt(thirdPosition, target + Vector3.new(0, 3, 0)),
	}
end

function CameraController.new(app: App, remotes: RemoteRegistry): CameraController
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "AuraRushBloomClient"
	bloom.Intensity = 0.035
	bloom.Size = 12
	bloom.Threshold = 2
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "AuraRushColorClient"
	color.Brightness = 0
	color.Contrast = 0
	color.Saturation = 0
	color.Parent = Lighting

	local depth = Instance.new("DepthOfFieldEffect")
	depth.Name = "AuraRushDepthClient"
	depth.Enabled = false
	depth.FarIntensity = 0
	depth.FocusDistance = 42
	depth.InFocusRadius = 26
	depth.NearIntensity = 0
	depth.Parent = Lighting

	local self: CameraController = setmetatable({
		App = app,
		Remotes = remotes,
		Connections = {},
		BloomEffect = bloom,
		ColorEffect = color,
		DepthEffect = depth,
		SequenceToken = 0,
		Active = false,
		ActiveTweens = {},
		EffectTweens = {},
		WorldTweens = {},
		PreviousCameraType = nil,
		PreviousCameraSubject = nil,
		PreviousFieldOfView = 70,
		PreviousLighting = {},
		ArrivalFramed = false,
		ArrivalQueued = false,
		ArrivalToken = 0,
		RouteArrivalToken = 0,
	}, CameraController)

	-- These properties are deliberately optional so an older Studio build can
	-- still open the place without turning presentation features into a boot error.
	pcall(function()
		local lightingAny: any = Lighting
		lightingAny.LightingStyle = Enum.LightingStyle.Realistic
		lightingAny.PrioritizeLightingQuality = true
	end)

	self:_bind()
	return self
end

function CameraController._captureLighting(self: CameraController): ()
	if self.PreviousLighting.captured == true then
		return
	end
	local atmosphere = findAtmosphere()
	self.PreviousLighting = {
		captured = true,
		brightness = Lighting.Brightness,
		clockTime = Lighting.ClockTime,
		ambient = Lighting.Ambient,
		outdoorAmbient = Lighting.OutdoorAmbient,
		atmosphere = atmosphere,
		atmosphereDensity = if atmosphere then atmosphere.Density else nil,
		atmosphereHaze = if atmosphere then atmosphere.Haze else nil,
	}
end

function CameraController._applyWorldLighting(
	self: CameraController,
	worldId: string,
	duration: number,
	reducedMotion: boolean,
	lowVfx: boolean
): ()
	local profile = getWorldArtProfile(worldId)
	local lightingProfile = if profile and type(profile.bloom) == "table"
		then profile.bloom
		else nil
	if not lightingProfile then
		return
	end
	self:_captureLighting()
	local ambient = colorFromHex(lightingProfile.ambientHex)
	local outdoorAmbient = colorFromHex(lightingProfile.outdoorAmbientHex)
	local transition = if reducedMotion then 0 else math.clamp(duration * 0.34, 0.5, 3.4)
	local lightingGoal: AnyMap = {
		Brightness = math.clamp(tonumber(lightingProfile.brightness) or 2.5, 0, 6),
	}
	if ambient then
		lightingGoal.Ambient = ambient
	end
	if outdoorAmbient then
		lightingGoal.OutdoorAmbient = outdoorAmbient
	end
	Lighting.ClockTime = tonumber(lightingProfile.clockTime) or Lighting.ClockTime
	if transition <= 0 then
		local lightingAny: any = Lighting
		for key, value in lightingGoal do
			lightingAny[key] = value
		end
	else
		local tween = TweenService:Create(
			Lighting,
			TweenInfo.new(transition, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			lightingGoal
		)
		table.insert(self.EffectTweens, tween)
		tween:Play()
	end

	local atmosphere = findAtmosphere()
	if atmosphere then
		local atmosphereGoal = {
			Density = math.clamp(tonumber(lightingProfile.atmosphereDensity) or 0.25, 0, 1),
			Haze = math.clamp(tonumber(lightingProfile.atmosphereHaze) or 1, 0, 10),
		}
		if transition <= 0 then
			atmosphere.Density = atmosphereGoal.Density
			atmosphere.Haze = atmosphereGoal.Haze
		else
			local tween = TweenService:Create(
				atmosphere,
				TweenInfo.new(transition, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				atmosphereGoal
			)
			table.insert(self.EffectTweens, tween)
			tween:Play()
		end
	end

	pcall(function()
		local lightingAny: any = Lighting
		lightingAny.EnvironmentDiffuseScale = if lowVfx then 0.45 else 0.68
		lightingAny.EnvironmentSpecularScale = if lowVfx then 0.38 else 0.72
		lightingAny.ShadowSoftness = 0.42
	end)
end

function CameraController._restoreLighting(self: CameraController): ()
	local previous = self.PreviousLighting
	if previous.captured ~= true then
		return
	end
	Lighting.Brightness = tonumber(previous.brightness) or Lighting.Brightness
	Lighting.ClockTime = tonumber(previous.clockTime) or Lighting.ClockTime
	if typeof(previous.ambient) == "Color3" then
		Lighting.Ambient = previous.ambient
	end
	if typeof(previous.outdoorAmbient) == "Color3" then
		Lighting.OutdoorAmbient = previous.outdoorAmbient
	end
	local atmosphere = previous.atmosphere
	if atmosphere and typeof(atmosphere) == "Instance" and atmosphere.Parent then
		if type(previous.atmosphereDensity) == "number" then
			(atmosphere :: Atmosphere).Density = previous.atmosphereDensity
		end
		if type(previous.atmosphereHaze) == "number" then
			(atmosphere :: Atmosphere).Haze = previous.atmosphereHaze
		end
	end
	self.PreviousLighting = {}
end

function CameraController._queueArrival(self: CameraController, character: Model)
	if self.ArrivalFramed or self.ArrivalQueued then
		return
	end
	self.ArrivalQueued = true
	local token = self.ArrivalToken
	task.spawn(function()
		for _ = 1, 40 do
			if token ~= self.ArrivalToken or not character.Parent then
				return
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local spawn = workspace:FindFirstChild("HubSpawn", true)
			local camera = workspace.CurrentCamera
			if
				root
				and root:IsA("BasePart")
				and humanoid
				and spawn
				and spawn:IsA("BasePart")
				and camera
				and camera.CameraSubject == humanoid
				and not self.Active
				and (root.Position - spawn.Position).Magnitude <= 28
			then
				self.ArrivalFramed = true
				local focus = spawn:GetAttribute("ArrivalFocus")
				local target = if typeof(focus) == "Vector3"
					then focus
					else spawn.Position + spawn.CFrame.LookVector * 43 + Vector3.new(0, 10, 0)
				local frames = 0
				RunService:BindToRenderStep(
					"AuraRushArrivalCamera",
					Enum.RenderPriority.Camera.Value + 1,
					function()
						if
							token ~= self.ArrivalToken
							or self.Active
							or not root.Parent
							or workspace.CurrentCamera ~= camera
						then
							RunService:UnbindFromRenderStep("AuraRushArrivalCamera")
							return
						end
						-- Seed Roblox's normal follow camera once, without a cutscene,
						-- locking controls, or fighting the player's later camera input.
						camera.CFrame = CFrame.lookAt(
							root.Position - spawn.CFrame.LookVector * 18 + Vector3.new(0, 7, 0),
							target
						)
						frames += 1
						if frames >= 3 then
							RunService:UnbindFromRenderStep("AuraRushArrivalCamera")
						end
					end
				)
				return
			end
			task.wait(0.1)
		end
		self.ArrivalQueued = false
	end)
end

function CameraController._queueRouteArrival(self: CameraController, phase: string)
	self.RouteArrivalToken += 1
	RunService:UnbindFromRenderStep("AuraRushRouteArrivalCamera")
	local actIndex = ({ ThreadRun = 1, BeatLab = 2, PrismPuzzle = 3 })[phase]
	if not actIndex then
		return
	end
	local token = self.RouteArrivalToken
	task.spawn(function()
		for _ = 1, 40 do
			if token ~= self.RouteArrivalToken then
				return
			end
			local character = Players.LocalPlayer.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local route = workspace:FindFirstChild("ActiveRunGeometry", true)
			local chunk = if route then route:FindFirstChild(`RouteChunk_{actIndex}`) else nil
			local arrival = if chunk then chunk:GetAttribute("ArrivalPosition") else nil
			local direction = if chunk then chunk:GetAttribute("ArrivalDirection") else nil
			local camera = workspace.CurrentCamera
			if
				root
				and root:IsA("BasePart")
				and humanoid
				and camera
				and camera.CameraSubject == humanoid
				and not self.Active
				and typeof(arrival) == "Vector3"
				and typeof(direction) == "Vector3"
				and direction.Magnitude > 0.9
				and (root.Position - arrival).Magnitude <= 28
			then
				local forward = direction.Unit
				local frames = 0
				RunService:BindToRenderStep(
					"AuraRushRouteArrivalCamera",
					Enum.RenderPriority.Camera.Value + 1,
					function()
						if
							token ~= self.RouteArrivalToken
							or self.Active
							or not root.Parent
							or workspace.CurrentCamera ~= camera
						then
							RunService:UnbindFromRenderStep("AuraRushRouteArrivalCamera")
							return
						end
						camera.CFrame = CFrame.lookAt(
							root.Position - forward * 16 + Vector3.new(0, 7, 0),
							root.Position + forward * 24 + Vector3.new(0, 2, 0)
						)
						frames += 1
						if frames >= 3 then
							RunService:UnbindFromRenderStep("AuraRushRouteArrivalCamera")
						end
					end
				)
				return
			end
			task.wait(0.1)
		end
	end)
end

function CameraController._bind(self: CameraController)
	self.App:On("PhaseChanged", function(phase: string)
		if phase ~= "Finale" then
			self:_restoreCamera(true)
		end
		self:_queueRouteArrival(phase)
	end)
	self.App:On("LocalSettingsChanged", function(settings: any)
		if type(settings) == "table" and self.Active and settings.reducedMotion == true then
			self:_restoreCamera(false)
		elseif type(settings) == "table" and settings.noFlashes == true then
			for _, tween in self.EffectTweens do
				tween:Cancel()
			end
			table.clear(self.EffectTweens)
			self.BloomEffect.Intensity = 0.06
			self.ColorEffect.Brightness = 0
			self.ColorEffect.Contrast = 0.02
			self.ColorEffect.Saturation = 0.04
			self.DepthEffect.Enabled = false
		end
	end)

	table.insert(
		self.Connections,
		Players.LocalPlayer.CharacterAdded:Connect(function(character: Model)
			self:_queueArrival(character)
			if not self.Active then
				return
			end
			task.defer(function()
				local humanoid = character:FindFirstChildOfClass("Humanoid")
					or character:WaitForChild("Humanoid", 5)
				if humanoid and humanoid:IsA("Humanoid") then
					self:_restoreCamera(false)
				end
			end)
		end)
	)
	local initialCharacter = Players.LocalPlayer.Character
	if initialCharacter then
		self:_queueArrival(initialCharacter)
	end
	table.insert(
		self.Connections,
		workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			if self.Active then
				task.defer(function()
					self:_restoreCamera(false)
				end)
			end
		end)
	)

	local event = self.Remotes:GetEvent("BloomStarted")
	if event then
		table.insert(
			self.Connections,
			event.OnClientEvent:Connect(function(payload: any)
				if type(payload) == "table" then
					self:_scheduleBloom(payload)
				end
			end)
		)
	end
end

function CameraController._scheduleBloom(self: CameraController, payload: AnyMap)
	self.SequenceToken += 1
	local token = self.SequenceToken
	local startsAt = tonumber(payload.startsAt or payload.startTime) or workspace:GetServerTimeNow()
	local delaySeconds = math.max(0, startsAt - workspace:GetServerTimeNow())
	local worldId = getWorldId(payload)
	local opening = getCameraCFrame(worldId)
	if opening then
		prefetchPosition(opening.Position + opening.LookVector * 42)
	end
	self.App:BeginBloom(payload)
	task.delay(delaySeconds, function()
		if token == self.SequenceToken then
			self:_playBloom(payload, token)
		end
	end)
end

function CameraController._playBloom(self: CameraController, payload: AnyMap, token: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local settings = self.App:GetSettings()
	local duration = math.max(tonumber(payload.duration) or 10, 1)
	local worldId = getWorldId(payload)
	local twistId = if type(payload.twistId) == "string" then payload.twistId else ""
	local recipe = if type(payload.recipe) == "table" then payload.recipe else {}
	local presentation = if type(recipe.presentation) == "table" then recipe.presentation else {}
	local cameraPreset = if type(presentation.cameraPreset) == "string"
		then presentation.cameraPreset
		else nil
	local shots = getCameraShots(worldId, twistId, cameraPreset)
	self:_applyWorldLighting(worldId, duration, settings.reducedMotion, settings.lowVfx)
	if #shots > 0 then
		if not self.Active then
			self.PreviousCameraType = camera.CameraType
			self.PreviousCameraSubject = camera.CameraSubject
			self.PreviousFieldOfView = camera.FieldOfView
		end
		self.Active = true
		camera.CameraType = Enum.CameraType.Scriptable
		if settings.reducedMotion then
			camera.CFrame = shots[1]
			camera.FieldOfView = 60
			task.delay(math.min(duration, 6), function()
				if token == self.SequenceToken then
					self:_restoreCamera(false)
				end
			end)
		else
			self.DepthEffect.Enabled = not settings.lowVfx
			self.DepthEffect.FocusDistance = math.clamp(
				(shots[1].Position - getFocusPosition(worldId, shots[1])).Magnitude,
				18,
				80
			)
			self.DepthEffect.InFocusRadius = 24
			self.DepthEffect.FarIntensity = if settings.lowVfx then 0 else 0.12
			self.DepthEffect.NearIntensity = if settings.lowVfx then 0 else 0.08
			self:_playShotSequence(camera, shots, duration, token)
		end
	end
	self:_bloomWorld(
		worldId,
		if recipe.primaryColor ~= nil then recipe.primaryColor else payload.color,
		if recipe.accentHex ~= nil then recipe.accentHex else payload.accentHex,
		twistId,
		duration,
		settings.reducedMotion,
		presentation
	)

	if settings.reducedMotion or settings.lowVfx or settings.noFlashes then
		self.DepthEffect.Enabled = false
		self.BloomEffect.Intensity = if settings.noFlashes
			then 0.06
			else if settings.lowVfx then 0.1 else 0.22
		self.ColorEffect.Saturation = if settings.noFlashes then 0.04 else 0.08
		return
	end
	local profile = getWorldArtProfile(worldId)
	local bloomProfile = if profile and type(profile.bloom) == "table" then profile.bloom else nil
	local bloomTween = TweenService:Create(
		self.BloomEffect,
		TweenInfo.new(duration * 0.4, Enum.EasingStyle.Sine),
		{
			Intensity = math.clamp(
				tonumber(if bloomProfile then bloomProfile.bloomIntensity else nil) or 0.5,
				0.15,
				0.7
			),
			Size = math.clamp(
				tonumber(if bloomProfile then bloomProfile.bloomSize else nil) or 32,
				18,
				48
			),
		}
	)
	local colorTween = TweenService:Create(
		self.ColorEffect,
		TweenInfo.new(duration * 0.45, Enum.EasingStyle.Sine),
		{
			Brightness = 0.04,
			Contrast = 0.08,
			Saturation = 0.28,
		}
	)
	table.insert(self.EffectTweens, bloomTween)
	table.insert(self.EffectTweens, colorTween)
	bloomTween:Play()
	colorTween:Play()
end

function CameraController._playShotSequence(
	self: CameraController,
	camera: Camera,
	shots: { CFrame },
	duration: number,
	token: number
)
	local sequenceDuration = math.min(math.max(duration * 0.72, 3.6), 9)
	local segment = sequenceDuration / math.max(#shots, 1)
	local fieldsOfView = { 58, 52, 64 }
	task.spawn(function()
		for index, shot in shots do
			if token ~= self.SequenceToken or workspace.CurrentCamera ~= camera then
				return
			end
			local tween = TweenService:Create(
				camera,
				TweenInfo.new(
					math.min(segment * 0.82, 1.65),
					Enum.EasingStyle.Quint,
					Enum.EasingDirection.InOut
				),
				{
					CFrame = shot,
					FieldOfView = fieldsOfView[index] or 58,
				}
			)
			table.insert(self.ActiveTweens, tween)
			tween:Play()
			task.wait(segment)
		end
		if token == self.SequenceToken then
			self:_restoreCamera(false)
		end
	end)
end

function CameraController._bloomWorld(
	self: CameraController,
	worldId: string,
	colorValue: any,
	accentValue: any,
	twistId: string,
	duration: number,
	reducedMotion: boolean,
	presentation: AnyMap?
)
	local targetColor = if typeof(colorValue) == "Color3"
		then colorValue
		else colorFromHex(colorValue)
	if not targetColor then
		targetColor = Color3.fromRGB(140, 108, 255)
	end
	local accentColor = colorFromHex(accentValue)
	if accentColor then
		targetColor = targetColor:Lerp(accentColor, 0.18)
	end
	local targetGroup = WORLD_GROUPS[worldId] or WORLD_GROUPS.prism_metro
	local profile = getWorldArtProfile(worldId)
	local recipePalette = if type(presentation) == "table"
			and type(presentation.paletteStops) == "table"
		then presentation.paletteStops
		else nil
	local profilePalette = if recipePalette
		then recipePalette
		else if profile and type(profile.palette) == "table" then profile.palette else {}
	local colorBlend = math.clamp(
		tonumber(if type(presentation) == "table" then presentation.colorBlend else nil) or 0.32,
		0.16,
		0.62
	)
	local colorIndex = 0
	for _, instance in CollectionService:GetTagged("AuraRushBloomable") do
		if instance:IsA("BasePart") and instance:GetAttribute("BloomGroup") == targetGroup then
			colorIndex += 1
			local cycle = (colorIndex - 1) % 5
			local authoredTarget = colorFromHex(instance:GetAttribute("BloomTargetColor"))
			local profileColor =
				colorFromHex(profilePalette[(cycle % math.max(#profilePalette, 1)) + 1])
			local varied = if cycle == 0
				then targetColor:Lerp(Color3.new(1, 1, 1), 0.18 + colorBlend * 0.2)
				else if cycle == 1
					then targetColor:Lerp(Color3.new(0, 0, 0), 0.12)
					else if cycle == 2
						then targetColor:Lerp(profileColor or Color3.fromRGB(48, 133, 255), 0.2)
						else if cycle == 3
							then targetColor:Lerp(
								profileColor or Color3.fromRGB(255, 107, 91),
								0.18
							)
							else targetColor
			if authoredTarget then
				-- The authored world keeps its material identity while the team palette
				-- remains visibly responsible for the final transformation.
				varied = authoredTarget:Lerp(varied, 0.44 + colorBlend * 0.28)
			end
			if twistId == "color_eclipse" then
				varied = if colorIndex % 2 == 0
					then varied:Lerp(Color3.fromRGB(8, 5, 20), 0.72)
					else varied:Lerp(Color3.fromRGB(255, 210, 92), 0.28)
			elseif twistId == "zero_gravity" then
				varied = varied:Lerp(Color3.fromRGB(180, 225, 255), 0.16)
			end
			if reducedMotion then
				instance.Color = varied
			else
				local stage = math.clamp(
					math.floor(tonumber(instance:GetAttribute("BloomRevealStage")) or 1),
					1,
					3
				)
				local tween = TweenService:Create(
					instance,
					TweenInfo.new(
						math.min(duration * 0.3, 2.6),
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.Out
					),
					{ Color = varied }
				)
				table.insert(self.WorldTweens, tween)
				task.delay((stage - 1) * math.min(duration * 0.19, 1.8), function()
					if instance.Parent and self.App:GetPhase() == "Finale" then
						tween:Play()
					end
				end)
			end
		end
	end
end

function CameraController._restoreWorld(self: CameraController)
	for _, tween in self.WorldTweens do
		tween:Cancel()
	end
	table.clear(self.WorldTweens)
	for _, instance in CollectionService:GetTagged("AuraRushBloomable") do
		if instance:IsA("BasePart") then
			local baseColor = colorFromHex(instance:GetAttribute("BaseColor"))
			if baseColor then
				instance.Color = baseColor
			end
		end
	end
end

function CameraController._restoreCamera(self: CameraController, restoreWorld: boolean?)
	self.SequenceToken += 1
	for _, tween in self.ActiveTweens do
		tween:Cancel()
	end
	table.clear(self.ActiveTweens)
	for _, tween in self.EffectTweens do
		tween:Cancel()
	end
	table.clear(self.EffectTweens)
	local camera = workspace.CurrentCamera
	local shouldRecoverCamera = self.Active
		or (camera ~= nil and camera.CameraType == Enum.CameraType.Scriptable)
	if camera and shouldRecoverCamera then
		local previousType = self.PreviousCameraType
		camera.CameraType = if previousType and previousType ~= Enum.CameraType.Scriptable
			then previousType
			else Enum.CameraType.Custom
		local previousSubject = self.PreviousCameraSubject
		local humanoid = getHumanoid()
		if humanoid then
			camera.CameraSubject = humanoid
		elseif previousSubject and previousSubject.Parent then
			camera.CameraSubject = previousSubject
		end
		camera.FieldOfView = math.clamp(self.PreviousFieldOfView, 40, 100)
	end
	self.Active = false
	self.PreviousCameraType = nil
	self.PreviousCameraSubject = nil
	self.BloomEffect.Intensity = 0.035
	self.BloomEffect.Size = 12
	self.ColorEffect.Brightness = 0
	self.ColorEffect.Contrast = 0
	self.ColorEffect.Saturation = 0
	self.DepthEffect.Enabled = false
	self.DepthEffect.FarIntensity = 0
	self.DepthEffect.NearIntensity = 0
	if restoreWorld ~= false then
		self:_restoreWorld()
		self:_restoreLighting()
	end
end

function CameraController.Destroy(self: CameraController)
	self.ArrivalToken += 1
	self.RouteArrivalToken += 1
	RunService:UnbindFromRenderStep("AuraRushArrivalCamera")
	RunService:UnbindFromRenderStep("AuraRushRouteArrivalCamera")
	self:_restoreCamera(true)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.BloomEffect:Destroy()
	self.ColorEffect:Destroy()
	self.DepthEffect:Destroy()
end

return CameraController
