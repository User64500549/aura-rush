--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local AppModule = require(script.Parent.Parent.UI.App)
type App = AppModule.App

local AvatarPreviewController = {}
AvatarPreviewController.__index = AvatarPreviewController

export type AvatarPreviewController = typeof(setmetatable(
	{} :: {
		App: App,
		Viewport: ViewportFrame,
		WorldModel: WorldModel,
		PreviewCamera: Camera,
		Fallback: TextLabel,
		Connections: { RBXScriptConnection },
		Avatar: Model?,
		Stage: BasePart?,
		Yaw: number,
		RefreshToken: number,
		Dragging: boolean,
		LastPointerX: number,
		Destroyed: boolean,
	},
	AvatarPreviewController
))

local function stripUnsafeDescendants(model: Model)
	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Tool")
			or descendant:IsA("Sound")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam")
			or descendant:IsA("Highlight")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = true
		elseif descendant:IsA("Humanoid") then
			descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			descendant.AutoRotate = false
		end
	end
end

local function cloneCharacter(character: Model): Model?
	local wasArchivable = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function()
		return character:Clone()
	end)
	character.Archivable = wasArchivable
	if not ok or not clone or not clone:IsA("Model") then
		return nil
	end
	stripUnsafeDescendants(clone)
	clone.Name = "PreviewAvatar"
	return clone
end

function AvatarPreviewController.new(app: App): AvatarPreviewController
	local self: AvatarPreviewController = setmetatable({
		App = app,
		Viewport = app.Refs.MixViewport :: ViewportFrame,
		WorldModel = app.Refs.MixWorldModel :: WorldModel,
		PreviewCamera = app.Refs.MixPreviewCamera :: Camera,
		Fallback = app.Refs.MixPreviewFallback :: TextLabel,
		Connections = {},
		Avatar = nil,
		Stage = nil,
		Yaw = 0,
		RefreshToken = 0,
		Dragging = false,
		LastPointerX = 0,
		Destroyed = false,
	}, AvatarPreviewController)

	self:_bind()
	self:_queueRefresh(0)
	return self
end

function AvatarPreviewController._bind(self: AvatarPreviewController)
	local player = Players.LocalPlayer
	table.insert(
		self.Connections,
		player.CharacterAdded:Connect(function()
			self:_queueRefresh(0.2)
		end)
	)
	table.insert(
		self.Connections,
		player.CharacterAppearanceLoaded:Connect(function()
			self:_queueRefresh(0.05)
		end)
	)
	self.App:On("StylePreviewChanged", function()
		self:_queueRefresh(0.18)
	end)
	self.App:On("PreviewRotate", function(direction: number)
		if type(direction) == "number" then
			self.Yaw += math.rad(22) * math.sign(direction)
			self:_applyRotation()
		end
	end)
	self.App:On("PreviewReset", function()
		self.Yaw = 0
		self:_applyRotation()
	end)
	self.App:On("PhaseChanged", function(phase: string)
		if phase == "MixLab" and not self.Avatar then
			self:_queueRefresh(0)
		end
	end)

	table.insert(
		self.Connections,
		self.Viewport.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				self.Dragging = true
				self.LastPointerX = input.Position.X
			end
		end)
	)
	table.insert(
		self.Connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if not self.Dragging then
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local nextX = input.Position.X
			self.Yaw += (nextX - self.LastPointerX) * 0.012
			self.LastPointerX = nextX
			self:_applyRotation()
		end)
	)
	table.insert(
		self.Connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				self.Dragging = false
			end
		end)
	)
end

function AvatarPreviewController._queueRefresh(self: AvatarPreviewController, delaySeconds: number)
	self.RefreshToken += 1
	local token = self.RefreshToken
	self.Fallback.Visible = true
	task.delay(math.max(0, delaySeconds), function()
		if token == self.RefreshToken and not self.Destroyed then
			self:_refresh()
		end
	end)
end

function AvatarPreviewController._refresh(self: AvatarPreviewController)
	local character = Players.LocalPlayer.Character
	if not character or not character.Parent then
		self.Fallback.Visible = true
		return
	end

	local clone = cloneCharacter(character)
	if not clone then
		self.Fallback.Visible = true
		return
	end

	if self.Avatar then
		self.Avatar:Destroy()
	end
	if self.Stage then
		self.Stage:Destroy()
	end

	clone.Parent = self.WorldModel
	clone:PivotTo(CFrame.Angles(0, self.Yaw, 0))
	self.Avatar = clone

	local boundsCFrame, boundsSize = clone:GetBoundingBox()
	local stage = Instance.new("Part")
	stage.Name = "PreviewStage"
	stage.Shape = Enum.PartType.Cylinder
	stage.Size = Vector3.new(0.18, math.max(boundsSize.X, 5.2), math.max(boundsSize.Z, 5.2))
	stage.CFrame = CFrame.new(0, boundsCFrame.Position.Y - boundsSize.Y * 0.5 - 0.12, 0)
		* CFrame.Angles(0, 0, math.rad(90))
	stage.Anchored = true
	stage.CanCollide = false
	stage.CanTouch = false
	stage.CanQuery = false
	stage.CastShadow = false
	stage.Material = Enum.Material.Glass
	stage.Color = self.Viewport.Ambient:Lerp(Color3.new(1, 1, 1), 0.22)
	stage.Transparency = 0.32
	stage.Parent = self.WorldModel
	self.Stage = stage

	local target = boundsCFrame.Position + Vector3.new(0, boundsSize.Y * 0.03, 0)
	local halfHeight = math.max(boundsSize.Y * 0.58, 2.5)
	local distance = halfHeight / math.tan(math.rad(self.PreviewCamera.FieldOfView * 0.5))
	distance += math.max(boundsSize.Z, boundsSize.X) * 0.36
	self.PreviewCamera.CFrame =
		CFrame.lookAt(target + Vector3.new(0, boundsSize.Y * 0.02, -distance), target)
	self.Fallback.Visible = false
end

function AvatarPreviewController._applyRotation(self: AvatarPreviewController)
	local avatar = self.Avatar
	if not avatar or not avatar.Parent then
		return
	end
	avatar:PivotTo(CFrame.Angles(0, self.Yaw, 0))
end

function AvatarPreviewController.Destroy(self: AvatarPreviewController)
	self.Destroyed = true
	self.RefreshToken += 1
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	if self.Avatar then
		self.Avatar:Destroy()
	end
	if self.Stage then
		self.Stage:Destroy()
	end
end

return AvatarPreviewController
