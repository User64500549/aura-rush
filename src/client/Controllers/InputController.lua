--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AppModule = require(script.Parent.Parent.UI.App)
local AudioDirectorModule = require(script.Parent.AudioDirector)
type App = AppModule.App
type AudioDirector = AudioDirectorModule.AudioDirector

local InputController = {}
InputController.__index = InputController

export type InputController = typeof(setmetatable(
	{} :: {
		App: App,
		Connections: { RBXScriptConnection },
		BeatStartTime: number,
		BeatInterval: number,
		BeatCount: number,
		BeatLanes: { number },
		LastSubmittedBeat: number,
		LastVisualBeat: number,
		LastCountIn: number,
		Audio: AudioDirector,
		LastInputMode: string,
		InputRoot: Folder?,
		InputContexts: { [string]: any },
		UsingInputActions: boolean,
	},
	InputController
))

local BEAT_ACTIONS = {
	{
		"AuraBeat1",
		1,
		{ Enum.KeyCode.Q, Enum.KeyCode.One, Enum.KeyCode.DPadLeft, Enum.KeyCode.ButtonX },
	},
	{
		"AuraBeat2",
		2,
		{ Enum.KeyCode.W, Enum.KeyCode.Two, Enum.KeyCode.DPadUp, Enum.KeyCode.ButtonY },
	},
	{
		"AuraBeat3",
		3,
		{ Enum.KeyCode.E, Enum.KeyCode.Three, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonB },
	},
	{
		"AuraBeat4",
		4,
		{ Enum.KeyCode.R, Enum.KeyCode.Four, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonA },
	},
}

local PRISM_ACTIONS = {
	{ "AuraPrism1", 1, { Enum.KeyCode.One, Enum.KeyCode.Q, Enum.KeyCode.ButtonX } },
	{ "AuraPrism2", 2, { Enum.KeyCode.Two, Enum.KeyCode.W, Enum.KeyCode.ButtonY } },
	{ "AuraPrism3", 3, { Enum.KeyCode.Three, Enum.KeyCode.E, Enum.KeyCode.ButtonB } },
	{ "AuraPrism4", 4, { Enum.KeyCode.Four, Enum.KeyCode.R, Enum.KeyCode.ButtonA } },
}

local function inputMode(inputType: Enum.UserInputType): string
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.find(inputType.Name, "Gamepad", 1, true) then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

function InputController.new(app: App, audio: AudioDirector): InputController
	local self: InputController = setmetatable({
		App = app,
		Connections = {},
		BeatStartTime = 0,
		BeatInterval = 0.75,
		BeatCount = 12,
		BeatLanes = {},
		LastSubmittedBeat = 0,
		LastVisualBeat = 0,
		LastCountIn = 0,
		Audio = audio,
		LastInputMode = inputMode(UserInputService:GetLastInputType()),
		InputRoot = nil,
		InputContexts = {},
		UsingInputActions = false,
	}, InputController)
	self.App.ScreenGui:SetAttribute("PreferredInput", self.LastInputMode)

	self.UsingInputActions = self:_tryBindInputActions()
	if not self.UsingInputActions then
		self:_bindActions()
	end
	self.App:On(
		"BeatConfigured",
		function(startTime: number, interval: number, count: number, lanes: { number })
			self.BeatStartTime = startTime
			self.BeatInterval = math.max(interval, 0.1)
			self.BeatCount = math.max(math.floor(count), 1)
			self.BeatLanes = table.clone(lanes)
			self.LastSubmittedBeat = 0
			self.LastVisualBeat = 0
			self.LastCountIn = 0
		end
	)
	self.App:On("BeatLanePressed", function(lane: number)
		self:_submitBeat(lane)
	end)
	self.App:On("PhaseChanged", function(phase: string)
		self:_setInputPhase(phase)
		if phase ~= "BeatLab" then
			self.LastSubmittedBeat = 0
			self.LastVisualBeat = 0
			self.LastCountIn = 0
		end
	end)

	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function()
			self:_updateBeatVisual()
		end)
	)
	table.insert(
		self.Connections,
		UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
			local mode = inputMode(inputType)
			if mode ~= self.LastInputMode then
				self.LastInputMode = mode
				self.App.ScreenGui:SetAttribute("PreferredInput", mode)
			end
		end)
	)
	return self
end

function InputController._setInputPhase(self: InputController, phase: string): ()
	local beatContext = self.InputContexts.BeatLab
	local prismContext = self.InputContexts.PrismPuzzle
	if beatContext then
		beatContext.Enabled = phase == "BeatLab"
	end
	if prismContext then
		prismContext.Enabled = phase == "PrismPuzzle"
	end
end

function InputController._tryBindInputActions(self: InputController): boolean
	local createdRoot: Folder? = nil
	local ok = pcall(function()
		local root = Instance.new("Folder")
		root.Name = `AuraRushInputs_{Players.LocalPlayer.UserId}`
		root.Parent = ReplicatedStorage
		createdRoot = root

		local function makeContext(name: string): any
			local context = Instance.new("InputContext") :: any
			context.Name = name
			context.Enabled = false
			context.Priority = 2000
			context.Sink = true
			context.Parent = root
			self.InputContexts[name] = context
			return context
		end

		local beatContext = makeContext("BeatLab")
		for _, definition in BEAT_ACTIONS do
			local action = Instance.new("InputAction") :: any
			action.Name = definition[1] :: string
			action.Parent = beatContext
			local lane = definition[2] :: number
			local keyCodes = definition[3] :: { Enum.KeyCode }
			for keyIndex, keyCode in keyCodes do
				local binding = Instance.new("InputBinding") :: any
				binding.Name = `Binding{keyIndex}`
				binding.KeyCode = keyCode
				binding.Parent = action
			end
			table.insert(
				self.Connections,
				action.Pressed:Connect(function()
					if self.App:GetPhase() == "BeatLab" then
						self.App:PulseBeatLane(lane)
						self:_submitBeat(lane)
					end
				end)
			)
		end

		local prismContext = makeContext("PrismPuzzle")
		for _, definition in PRISM_ACTIONS do
			local action = Instance.new("InputAction") :: any
			action.Name = definition[1] :: string
			action.Parent = prismContext
			local prismIndex = definition[2] :: number
			local keyCodes = definition[3] :: { Enum.KeyCode }
			for keyIndex, keyCode in keyCodes do
				local binding = Instance.new("InputBinding") :: any
				binding.Name = `Binding{keyIndex}`
				binding.KeyCode = keyCode
				binding.Parent = action
			end
			table.insert(
				self.Connections,
				action.Pressed:Connect(function()
					if self.App:GetPhase() == "PrismPuzzle" then
						self.App:_emit("PrismInput", prismIndex)
					end
				end)
			)
		end
	end)
	if not ok then
		if createdRoot then
			createdRoot:Destroy()
		end
		table.clear(self.InputContexts)
		return false
	end
	self.InputRoot = createdRoot
	self.App.ScreenGui:SetAttribute("InputSystem", "InputActionSystem")
	self:_setInputPhase(self.App:GetPhase())
	return true
end

function InputController._currentBeat(self: InputController, sampleTime: number): number
	if self.BeatStartTime <= 0 then
		return math.max(1, self.LastSubmittedBeat + 1)
	end
	local relative = (sampleTime - self.BeatStartTime) / self.BeatInterval
	return math.floor(relative + 0.5) + 1
end

function InputController._submitBeat(self: InputController, lane: number)
	if self.App:GetPhase() ~= "BeatLab" then
		return
	end
	local sampleTime = workspace:GetServerTimeNow()
	local beatIndex = self:_currentBeat(sampleTime)
	if beatIndex < 1 or beatIndex > self.BeatCount or beatIndex == self.LastSubmittedBeat then
		return
	end
	local expectedLane = self.BeatLanes[beatIndex] or (((beatIndex - 1) % 4) + 1)
	if lane ~= expectedLane then
		return
	end
	self.LastSubmittedBeat = beatIndex
	self.App:_emit("BeatHit", beatIndex, sampleTime, lane)
end

function InputController._playMetronome(self: InputController, lane: number, countIn: boolean)
	self.Audio:PlayMetronome(lane, countIn)
end

function InputController._updateBeatVisual(self: InputController)
	if self.App:GetPhase() ~= "BeatLab" or self.BeatStartTime <= 0 then
		return
	end
	local elapsed = workspace:GetServerTimeNow() - self.BeatStartTime
	if elapsed < 0 then
		local countIn = math.clamp(math.ceil(-elapsed / self.BeatInterval), 1, 3)
		if countIn ~= self.LastCountIn then
			self.LastCountIn = countIn
			self.App:SetBeatCountIn(countIn)
			self:_playMetronome(1, true)
		end
		return
	end
	local beatIndex = math.floor(elapsed / self.BeatInterval) + 1
	if beatIndex >= 1 and beatIndex <= self.BeatCount and beatIndex ~= self.LastVisualBeat then
		self.LastVisualBeat = beatIndex
		local lane = self.BeatLanes[beatIndex] or (((beatIndex - 1) % 4) + 1)
		self.App:SetBeatTarget(beatIndex, lane)
		self:_playMetronome(lane, false)
	end
end

function InputController._bindActions(self: InputController)
	for _, definition in BEAT_ACTIONS do
		local actionName = definition[1] :: string
		local lane = definition[2] :: number
		local keyCodes = definition[3] :: { Enum.KeyCode }
		ContextActionService:BindActionAtPriority(actionName, function(_, inputState)
			if inputState == Enum.UserInputState.Begin and self.App:GetPhase() == "BeatLab" then
				self.App:PulseBeatLane(lane)
				self:_submitBeat(lane)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, 2000, table.unpack(keyCodes))
	end

	for _, definition in PRISM_ACTIONS do
		local actionName = definition[1] :: string
		local index = definition[2] :: number
		local keyCodes = definition[3] :: { Enum.KeyCode }
		ContextActionService:BindActionAtPriority(actionName, function(_, inputState)
			if inputState == Enum.UserInputState.Begin and self.App:GetPhase() == "PrismPuzzle" then
				self.App:_emit("PrismInput", index)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, 2000, table.unpack(keyCodes))
	end
end

function InputController.Destroy(self: InputController)
	if not self.UsingInputActions then
		for _, definition in BEAT_ACTIONS do
			ContextActionService:UnbindAction(definition[1] :: string)
		end
		for _, definition in PRISM_ACTIONS do
			ContextActionService:UnbindAction(definition[1] :: string)
		end
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	if self.InputRoot then
		self.InputRoot:Destroy()
		self.InputRoot = nil
	end
	table.clear(self.InputContexts)
end

return InputController
