--!strict

local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AppModule = require(script.Parent.Parent.UI.App)
local sharedRoot = ReplicatedStorage:WaitForChild("AuraRushShared")
local ArtDirectionRegistry = require(sharedRoot:WaitForChild("ArtDirectionRegistry"))
type App = AppModule.App
type AnyMap = { [string]: any }

local AudioDirector = {}
AudioDirector.__index = AudioDirector

local BUILTIN_PULSE = "rbxasset://sounds/electronicpingshort.wav"

local function modularAudioEnabled(): boolean
	return Players.LocalPlayer:GetAttribute("AuraRushFlag_ModularAudio") ~= false
end

export type AudioDirector = typeof(setmetatable(
	{} :: {
		App: App,
		Root: Folder,
		MusicGroup: SoundGroup,
		SfxGroup: SoundGroup,
		AmbienceGroup: SoundGroup,
		LegacyMusic: Sound,
		LegacySfx: Sound,
		ModernMusic: AnyMap?,
		ModernSfx: AnyMap?,
		Connections: { RBXScriptConnection },
		Settings: AppModule.AccessibilitySettings,
		CurrentWorldId: string,
		CueToken: number,
		BloomPresentation: AnyMap,
	},
	AudioDirector
))

local function makeLegacy(
	parent: Instance,
	name: string,
	group: SoundGroup,
	baseVolume: number
): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = BUILTIN_PULSE
	sound.Volume = baseVolume
	sound.SoundGroup = group
	sound.Parent = parent
	return sound
end

local function tryMakeModern(parent: Instance, name: string, withReverb: boolean): AnyMap?
	local created: { Instance } = {}
	local result: AnyMap? = nil
	local ok = pcall(function()
		local player = Instance.new("AudioPlayer") :: any
		player.Name = `{name}Player`
		player.AssetId = BUILTIN_PULSE
		player.Volume = 0
		player.Parent = parent
		table.insert(created, player)

		local output = Instance.new("AudioDeviceOutput") :: any
		output.Name = `{name}Output`
		output.Parent = parent
		table.insert(created, output)

		local chain: { Instance } = { player }
		local effects: AnyMap = {}
		for _, definition in
			{
				{ key = "fader", className = "AudioFader" },
				{ key = "compressor", className = "AudioCompressor" },
				{ key = "equalizer", className = "AudioEqualizer" },
				{ key = "reverb", className = if withReverb then "AudioReverb" else "" },
			}
		do
			if definition.className ~= "" then
				local effect = Instance.new(definition.className)
				effect.Name = `{name}{definition.key}`
				effect.Parent = parent
				table.insert(created, effect)
				table.insert(chain, effect)
				effects[definition.key] = effect
			end
		end
		table.insert(chain, output)

		local wires = {}
		for index = 1, #chain - 1 do
			local wire = Instance.new("Wire") :: any
			wire.Name = `{name}Wire{index}`
			wire.SourceInstance = chain[index]
			wire.TargetInstance = chain[index + 1]
			wire.Parent = parent
			table.insert(created, wire)
			table.insert(wires, wire)
		end

		result = {
			player = player,
			output = output,
			wires = wires,
			effects = effects,
		}
	end)
	if not ok then
		for _, instance in created do
			instance:Destroy()
		end
		return nil
	end
	return result
end

local function destroyModern(modern: AnyMap?): ()
	if not modern then
		return
	end
	for _, wire in modern.wires or {} do
		if typeof(wire) == "Instance" then
			wire:Destroy()
		end
	end
	for _, instance in modern.effects or {} do
		if typeof(instance) == "Instance" then
			instance:Destroy()
		end
	end
	for _, key in { "output", "player" } do
		local rootInstance = modern[key]
		if typeof(rootInstance) == "Instance" then
			rootInstance:Destroy()
		end
	end
end

function AudioDirector.new(app: App, remotes: any?): AudioDirector
	local old = SoundService:FindFirstChild("AuraRushAudioClient")
	if old then
		old:Destroy()
	end
	for _, groupName in { "AuraRushMusic", "AuraRushSFX", "AuraRushAmbience" } do
		local oldGroup = SoundService:FindFirstChild(groupName)
		if oldGroup and oldGroup:IsA("SoundGroup") then
			oldGroup:Destroy()
		end
	end

	local root = Instance.new("Folder")
	root.Name = "AuraRushAudioClient"
	root.Parent = SoundService

	local musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "AuraRushMusic"
	musicGroup.Parent = SoundService

	local sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "AuraRushSFX"
	sfxGroup.Parent = SoundService

	local ambienceGroup = Instance.new("SoundGroup")
	ambienceGroup.Name = "AuraRushAmbience"
	ambienceGroup.Parent = SoundService

	local self: AudioDirector = setmetatable({
		App = app,
		Root = root,
		MusicGroup = musicGroup,
		SfxGroup = sfxGroup,
		AmbienceGroup = ambienceGroup,
		LegacyMusic = makeLegacy(root, "PhaseCueLegacy", musicGroup, 0.16),
		LegacySfx = makeLegacy(root, "PulseLegacy", sfxGroup, 0.42),
		ModernMusic = if modularAudioEnabled() then tryMakeModern(root, "PhaseCue", true) else nil,
		ModernSfx = if modularAudioEnabled() then tryMakeModern(root, "Pulse", false) else nil,
		Connections = {},
		Settings = app:GetSettings(),
		CurrentWorldId = "prism_metro",
		CueToken = 0,
		BloomPresentation = {},
	}, AudioDirector)

	self:_applySettings(self.Settings)
	self:_applyWorldMotif()
	table.insert(
		self.Connections,
		self.App:On("LocalSettingsChanged", function(settings: any)
			if type(settings) == "table" then
				self:_applySettings(settings)
			end
		end)
	)
	if remotes and type(remotes.GetEvent) == "function" then
		local bloomEvent = remotes:GetEvent("BloomStarted")
		if bloomEvent then
			table.insert(
				self.Connections,
				bloomEvent.OnClientEvent:Connect(function(payload: any)
					if type(payload) == "table" then
						self:_playBloomRecipe(payload)
					end
				end)
			)
		end
		local remixEvent = remotes:GetEvent("RemixUpdate")
		if remixEvent then
			table.insert(
				self.Connections,
				remixEvent.OnClientEvent:Connect(function(payload: any)
					if type(payload) ~= "table" then
						return
					end
					if payload.kind == "GuardianComplete" then
						self:_playPattern("sfx", { 1.08, 1.3, 1.56 }, 0.09)
					elseif payload.kind == "GuardianProgress" then
						local guardian = if type(payload.data) == "table"
							then payload.data.guardian
							else nil
						local target = if type(guardian) == "table"
							then math.max(tonumber(guardian.target) or 1, 1)
							else 1
						local progress = if type(guardian) == "table"
							then tonumber(guardian.progress) or 0
							else 0
						self:_playChannel("sfx", 0.92 + math.clamp(progress / target, 0, 1) * 0.48)
					elseif payload.kind == "ReplayPlayback" then
						self:_playPattern("music", { 0.78, 0.9, 1.04 }, 0.18)
					end
				end)
			)
		end
	end
	table.insert(
		self.Connections,
		self.App:On("PhaseChanged", function(phase: string)
			self:_playPhaseCue(phase)
		end)
	)
	table.insert(
		self.Connections,
		self.App:On("SnapshotApplied", function(snapshot: any)
			if type(snapshot) ~= "table" then
				return
			end
			local runPlan = snapshot.runPlan
			local brief = snapshot.selectedBrief
			local worldId = if type(runPlan) == "table" then runPlan.worldId else nil
			if type(worldId) ~= "string" and type(brief) == "table" then
				worldId = brief.WorldId or brief.worldId
			end
			if type(worldId) == "string" and ArtDirectionRegistry.GetWorld(worldId) then
				self.CurrentWorldId = worldId
				self:_applyWorldMotif()
			end
		end)
	)
	table.insert(
		self.Connections,
		Players.LocalPlayer
			:GetAttributeChangedSignal("AuraRushFlag_ModularAudio")
			:Connect(function()
				self:_syncModularAudio()
			end)
	)
	return self
end

function AudioDirector._playBloomRecipe(self: AudioDirector, payload: AnyMap): ()
	local recipe = if type(payload.recipe) == "table" then payload.recipe else {}
	local presentation = if type(recipe.presentation) == "table" then recipe.presentation else {}
	self.BloomPresentation = table.clone(presentation)
	local pulseRate = math.clamp(tonumber(presentation.pulseRate) or 1, 0.6, 1.25)
	local intensity = math.clamp(tonumber(presentation.intensity) or 0.7, 0.4, 1)
	local performance = math.clamp(tonumber(recipe.performance) or 0.55, 0, 1)
	local motif = tostring(presentation.auraMotif or "spark")
	self.Root:SetAttribute("BloomAuraMotif", motif)
	self.Root:SetAttribute("BloomPulseRate", pulseRate)
	self.Root:SetAttribute("BloomIntensity", intensity)
	self.Root:SetAttribute("BloomPerformance", performance)

	for _, modern in { self.ModernMusic, self.ModernSfx } do
		if modern then
			pcall(function()
				local effects = (modern :: AnyMap).effects
				if effects and effects.equalizer then
					effects.equalizer.LowGain = -2 + intensity * 4
					effects.equalizer.MidGain = if motif == "glitch" or motif == "pixel"
						then 4
						else 1
					effects.equalizer.HighGain = if motif == "mist" then -3 else 1 + performance * 3
				end
				if effects and effects.reverb then
					effects.reverb.WetLevel = -18 + intensity * 8
				end
			end)
		end
	end

	local base = 0.84 + performance * 0.24
	self:_playPattern(
		"music",
		{ base * pulseRate * 0.88, base * pulseRate, base * pulseRate * 1.12 },
		math.clamp(0.2 / pulseRate, 0.11, 0.28)
	)
end

function AudioDirector._syncModularAudio(self: AudioDirector): ()
	if not modularAudioEnabled() then
		destroyModern(self.ModernMusic)
		destroyModern(self.ModernSfx)
		self.ModernMusic = nil
		self.ModernSfx = nil
		return
	end
	if not self.ModernMusic then
		self.ModernMusic = tryMakeModern(self.Root, "PhaseCue", true)
	end
	if not self.ModernSfx then
		self.ModernSfx = tryMakeModern(self.Root, "Pulse", false)
	end
	self:_applySettings(self.Settings)
	self:_applyWorldMotif()
end

function AudioDirector._applySettings(
	self: AudioDirector,
	settings: AppModule.AccessibilitySettings
)
	self.Settings = table.clone(settings)
	self.MusicGroup.Volume = math.clamp(settings.musicVolume, 0, 1)
	self.SfxGroup.Volume = math.clamp(settings.sfxVolume, 0, 1)
	self.AmbienceGroup.Volume = math.clamp(settings.ambienceVolume, 0, 1)
	if self.ModernMusic then
		pcall(function()
			(self.ModernMusic :: AnyMap).player.Volume = 0.16
			local effects = (self.ModernMusic :: AnyMap).effects
			if effects and effects.fader then
				effects.fader.Volume = settings.musicVolume
			end
		end)
	end
	if self.ModernSfx then
		pcall(function()
			(self.ModernSfx :: AnyMap).player.Volume = 0.42
			local effects = (self.ModernSfx :: AnyMap).effects
			if effects and effects.fader then
				effects.fader.Volume = settings.sfxVolume
			end
		end)
	end
end

function AudioDirector._applyWorldMotif(self: AudioDirector): ()
	local profile = ArtDirectionRegistry.GetWorld(self.CurrentWorldId)
	if not profile then
		return
	end
	local motif = tostring(profile.soundMotif or "")
	local lowGain = if string.find(motif, "house", 1, true) then -2 else 1
	local midGain = if string.find(motif, "strings", 1, true) then 3 else 0
	local highGain = if string.find(motif, "choir", 1, true) then 2 else 1
	local wetLevel = if self.CurrentWorldId == "moonlit_greenhouse"
			or self.CurrentWorldId == "solar_cathedral"
		then -9
		else -16
	for _, modern in { self.ModernMusic, self.ModernSfx } do
		if modern then
			pcall(function()
				local effects = (modern :: AnyMap).effects
				if effects and effects.equalizer then
					effects.equalizer.LowGain = lowGain
					effects.equalizer.MidGain = midGain
					effects.equalizer.HighGain = highGain
				end
				if effects and effects.reverb then
					effects.reverb.DryLevel = 0
					effects.reverb.WetLevel = wetLevel
				end
			end)
		end
	end
	self.Root:SetAttribute("WorldSoundMotif", motif)
end

function AudioDirector._playChannel(
	self: AudioDirector,
	kind: "music" | "sfx",
	playbackSpeed: number
)
	local modern = if kind == "music" then self.ModernMusic else self.ModernSfx
	local settingVolume = if kind == "music"
		then self.Settings.musicVolume
		else self.Settings.sfxVolume
	if settingVolume <= 0 then
		return
	end

	if modern and modularAudioEnabled() then
		local ok, played = pcall(function()
			local player = (modern :: AnyMap).player
			if player.IsReady ~= true then
				return false
			end
			player:Stop()
			player.PlaybackSpeed = math.clamp(playbackSpeed, 0.5, 1.8)
			player.TimePosition = 0
			player:Play()
			return true
		end)
		if ok and played == true then
			return
		end
		if not ok then
			if kind == "music" then
				destroyModern(self.ModernMusic)
				self.ModernMusic = nil
			else
				destroyModern(self.ModernSfx)
				self.ModernSfx = nil
			end
		end
	end

	local legacy = if kind == "music" then self.LegacyMusic else self.LegacySfx
	legacy:Stop()
	legacy.PlaybackSpeed = math.clamp(playbackSpeed, 0.5, 1.8)
	legacy.TimePosition = 0
	legacy:Play()
end

function AudioDirector._playPattern(
	self: AudioDirector,
	kind: "music" | "sfx",
	speeds: { number },
	spacing: number
): ()
	self.CueToken += 1
	local token = self.CueToken
	task.spawn(function()
		for index, speed in speeds do
			if token ~= self.CueToken then
				return
			end
			self:_playChannel(kind, speed)
			if index < #speeds then
				task.wait(spacing)
			end
		end
	end)
end

function AudioDirector._playPhaseCue(self: AudioDirector, phase: string)
	local speeds: { [string]: number } = {
		BriefChoice = 0.72,
		ThreadRun = 0.86,
		BeatLab = 1.0,
		PrismPuzzle = 1.12,
		MixLab = 1.22,
		Finale = 1.38,
		Results = 0.94,
	}
	local speed = speeds[phase]
	if speed then
		local worldPitch: { [string]: number } = {
			prism_metro = 1,
			cloud_bazaar = 0.9,
			moonlit_greenhouse = 0.84,
			orbital_boardwalk = 1.12,
			velvet_archive = 0.78,
			solar_cathedral = 1.06,
		}
		local pitch = worldPitch[self.CurrentWorldId] or 1
		local pattern = if phase == "Finale"
			then { speed * pitch * 0.86, speed * pitch, speed * pitch * 1.16 }
			else { speed * pitch, speed * pitch * 1.06 }
		self:_playPattern("music", pattern, if phase == "Finale" then 0.16 else 0.11)
	end
	if phase == "Finale" then
		self.App:ShowCaption("Перекраска началась", 2.2, "Success")
	end
end

function AudioDirector.PlayMetronome(self: AudioDirector, lane: number, countIn: boolean)
	local safeLane = math.clamp(math.floor(lane), 1, 4)
	self:_playChannel("sfx", if countIn then 0.82 else 0.92 + safeLane * 0.07)
	if self.Settings.captions then
		self.App:ShowCaption(
			if countIn then "Приготовься" else `Дорожка {safeLane}`,
			if countIn then 0.45 else 0.34,
			"Info"
		)
	end
	if self.Settings.haptics then
		local strength = if countIn then 0.08 else 0.14
		local supported = false
		pcall(function()
			supported = HapticService:IsMotorSupported(
				Enum.UserInputType.Gamepad1,
				Enum.VibrationMotor.Small
			)
		end)
		if supported then
			pcall(function()
				HapticService:SetMotor(
					Enum.UserInputType.Gamepad1,
					Enum.VibrationMotor.Small,
					strength
				)
			end)
			task.delay(0.045, function()
				pcall(function()
					HapticService:SetMotor(
						Enum.UserInputType.Gamepad1,
						Enum.VibrationMotor.Small,
						0
					)
				end)
			end)
		end
	end
end

function AudioDirector.PlaySfx(self: AudioDirector, cue: string)
	local speed = if cue == "success" then 1.35 else if cue == "warning" then 0.7 else 1
	self:_playChannel("sfx", speed)
end

function AudioDirector.Destroy(self: AudioDirector)
	self.CueToken += 1
	pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
	end)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	self.Root:Destroy()
	self.MusicGroup:Destroy()
	self.SfxGroup:Destroy()
	self.AmbienceGroup:Destroy()
end

return AudioDirector
