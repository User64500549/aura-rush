--!strict

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local AppModule = require(script.Parent.Parent.UI.App)
type App = AppModule.App

local CaptureController = {}
CaptureController.__index = CaptureController

export type CaptureController = typeof(setmetatable(
	{} :: {
		App: App,
		Busy: boolean,
		Destroyed: boolean,
		OperationId: number,
		Connections: { RBXScriptConnection },
	},
	CaptureController
))

function CaptureController.new(app: App): CaptureController
	local self: CaptureController = setmetatable({
		App = app,
		Busy = false,
		Destroyed = false,
		OperationId = 0,
		Connections = {},
	}, CaptureController)

	self.App:On("CaptureRequested", function()
		self:TakeScreenshot()
	end)
	table.insert(
		self.Connections,
		ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
			if prompt:GetAttribute("AuraRushPhotoSpot") == true then
				self:TakeScreenshot()
			end
		end)
	)
	return self
end

function CaptureController.TakeScreenshot(self: CaptureController)
	if self.Destroyed then
		return
	end
	if Players.LocalPlayer:GetAttribute("AuraRushFlag_Capture") == false then
		self.App:ShowToast("CaptureUnavailable", "Warning")
		return
	end
	if self.Busy then
		return
	end
	self.Busy = true
	self.OperationId += 1
	local operationId = self.OperationId
	self.App:SetCaptureMode(true)
	task.delay(15, function()
		if self.Destroyed or not self.Busy or self.OperationId ~= operationId then
			return
		end
		self.OperationId += 1
		self.Busy = false
		self.App:SetCaptureMode(false)
		self.App:ShowToast("CaptureUnavailable", "Warning")
	end)
	task.spawn(function()
		RunService.RenderStepped:Wait()
		if self.Destroyed or self.OperationId ~= operationId then
			return
		end
		local callbackRan = false
		local ok = pcall(function()
			CaptureService:TakeScreenshotCaptureAsync(function(result, screenshotCapture)
				callbackRan = true
				if self.Destroyed or self.OperationId ~= operationId then
					return
				end
				self.App:SetCaptureMode(false)
				self.Busy = false
				if result ~= Enum.ScreenshotCaptureResult.Success or not screenshotCapture then
					self.App:ShowToast("CaptureUnavailable", "Warning")
					return
				end
				if Players.LocalPlayer:GetAttribute("AuraRushFlag_Capture") == false then
					self.App:ShowToast("CaptureUnavailable", "Warning")
					return
				end
				self.App:ShowToast("CaptureReady", "Success")
				self.App:CreatePostcard()
				local saveOk = pcall(function()
					CaptureService:PromptSaveCapturesToGallery(
						{ screenshotCapture },
						function(_results)
							-- The Roblox system prompt owns the final save decision.
						end
					)
				end)
				if not saveOk then
					self.App:ShowToast("CaptureUnavailable", "Warning")
				end
			end, { UICaptureMode = Enum.UICaptureMode.None })
		end)
		if
			not ok
			and not callbackRan
			and not self.Destroyed
			and self.OperationId == operationId
		then
			self.App:SetCaptureMode(false)
			self.Busy = false
			self.App:ShowToast("CaptureUnavailable", "Warning")
		end
	end)
end

function CaptureController.Destroy(self: CaptureController)
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.OperationId += 1
	if self.Busy then
		self.App:SetCaptureMode(false)
	end
	self.Busy = false
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return CaptureController
