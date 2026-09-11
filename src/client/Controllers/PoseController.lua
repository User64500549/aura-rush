--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AppModule = require(script.Parent.Parent.UI.App)
type App = AppModule.App

local PoseController = {}
PoseController.__index = PoseController

type JointMap = {
	rightShoulder: Motor6D?,
	leftShoulder: Motor6D?,
	neck: Motor6D?,
	waist: Motor6D?,
}

export type PoseController = typeof(setmetatable(
	{} :: {
		App: App,
		Character: Model?,
		Joints: JointMap,
		Phase: string,
		Connections: { RBXScriptConnection },
	},
	PoseController
))

local ACTIVE_PHASES = table.freeze({ MixLab = true, Finale = true, Results = true })

local function findMotor(character: Model, names: { string }): Motor6D?
	for _, name in names do
		local candidate = character:FindFirstChild(name, true)
		if candidate and candidate:IsA("Motor6D") then
			return candidate
		end
	end
	return nil
end

local function getJoints(character: Model): JointMap
	return {
		rightShoulder = findMotor(character, { "RightShoulder", "Right Shoulder" }),
		leftShoulder = findMotor(character, { "LeftShoulder", "Left Shoulder" }),
		neck = findMotor(character, { "Neck" }),
		waist = findMotor(character, { "Waist", "RootJoint", "Root" }),
	}
end

local function resetJoints(joints: JointMap): ()
	for _, joint in joints do
		if joint and joint.Parent then
			joint.Transform = CFrame.identity
		end
	end
end

local function poseTransforms(poseId: string, timeNow: number): (CFrame, CFrame, CFrame, CFrame)
	local normalized = string.lower(poseId)
	local sway = math.sin(timeNow * 2.2)
	local right = CFrame.Angles(math.rad(-8), 0, math.rad(12))
	local left = CFrame.Angles(math.rad(-8), 0, math.rad(-12))
	local neck = CFrame.Angles(0, math.rad(sway * 3), 0)
	local waist = CFrame.new(0, math.sin(timeNow * 1.8) * 0.035, 0)

	if string.find(normalized, "wave") then
		right = CFrame.Angles(math.rad(-20), math.rad(-8), math.rad(92 + sway * 9))
		left = CFrame.Angles(math.rad(-4), 0, math.rad(-16))
	elseif string.find(normalized, "peace") or string.find(normalized, "star_point") then
		right = CFrame.Angles(math.rad(-28), 0, math.rad(76))
		left = CFrame.Angles(math.rad(-12), 0, math.rad(-32))
		neck = CFrame.Angles(0, math.rad(-8), math.rad(-4))
	elseif string.find(normalized, "zero_g") or string.find(normalized, "cloud_float") then
		right = CFrame.Angles(math.rad(8), math.rad(-12), math.rad(58))
		left = CFrame.Angles(math.rad(8), math.rad(12), math.rad(-58))
		waist = CFrame.new(0, 0.14 + sway * 0.08, 0) * CFrame.Angles(0, 0, math.rad(sway * 3))
	elseif string.find(normalized, "detective") then
		right = CFrame.Angles(math.rad(-22), math.rad(-8), math.rad(28))
		left = CFrame.Angles(math.rad(-30), math.rad(10), math.rad(-44))
		neck = CFrame.Angles(math.rad(-4), math.rad(14), 0)
	elseif string.find(normalized, "editorial") or string.find(normalized, "vogue") then
		right = CFrame.Angles(math.rad(-16), math.rad(-12), math.rad(72))
		left = CFrame.Angles(math.rad(12), math.rad(8), math.rad(-48))
		waist = CFrame.Angles(0, math.rad(-12), math.rad(5))
	elseif string.find(normalized, "bloom") or string.find(normalized, "squad") then
		right = CFrame.Angles(math.rad(-14), 0, math.rad(68))
		left = CFrame.Angles(math.rad(-14), 0, math.rad(-68))
		neck = CFrame.Angles(math.rad(-4), 0, 0)
	elseif string.find(normalized, "power") then
		right = CFrame.Angles(math.rad(-18), 0, math.rad(36))
		left = CFrame.Angles(math.rad(-18), 0, math.rad(-36))
		waist = CFrame.Angles(math.rad(-4), math.rad(8), 0)
	end
	return right, left, neck, waist
end

function PoseController.new(app: App): PoseController
	local self: PoseController = setmetatable({
		App = app,
		Character = nil,
		Joints = {},
		Phase = app:GetPhase(),
		Connections = {},
	}, PoseController)

	local function bindCharacter(character: Model): ()
		resetJoints(self.Joints)
		self.Character = character
		self.Joints = getJoints(character)
	end

	if Players.LocalPlayer.Character then
		bindCharacter(Players.LocalPlayer.Character)
	end
	table.insert(self.Connections, Players.LocalPlayer.CharacterAdded:Connect(bindCharacter))
	table.insert(
		self.Connections,
		app:On("PhaseChanged", function(phase: string)
			self.Phase = phase
			if not ACTIVE_PHASES[phase] then
				resetJoints(self.Joints)
			end
		end)
	)
	table.insert(
		self.Connections,
		RunService.PreSimulation:Connect(function()
			local character = self.Character
			if not character or not ACTIVE_PHASES[self.Phase] then
				return
			end
			local poseId = character:GetAttribute("AuraPose")
			if type(poseId) ~= "string" then
				poseId = "pose_hero"
			end
			local right, left, neck, waist = poseTransforms(poseId, workspace:GetServerTimeNow())
			if self.Joints.rightShoulder then
				self.Joints.rightShoulder.Transform = right
			end
			if self.Joints.leftShoulder then
				self.Joints.leftShoulder.Transform = left
			end
			if self.Joints.neck then
				self.Joints.neck.Transform = neck
			end
			if self.Joints.waist then
				self.Joints.waist.Transform = waist
			end
		end)
	)
	return self
end

function PoseController.Destroy(self: PoseController): ()
	resetJoints(self.Joints)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
end

return PoseController
