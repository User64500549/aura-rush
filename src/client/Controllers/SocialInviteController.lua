--!strict

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local AppModule = require(script.Parent.Parent.UI.App)

type App = AppModule.App

local SocialInviteController = {}
SocialInviteController.__index = SocialInviteController

export type SocialInviteController = typeof(setmetatable(
	{} :: {
		App: App,
		LastPromptAt: number,
		Destroyed: boolean,
	},
	SocialInviteController
))

function SocialInviteController.new(app: App): SocialInviteController
	local self: SocialInviteController = setmetatable({
		App = app,
		LastPromptAt = 0,
		Destroyed = false,
	}, SocialInviteController)

	self.App:On("InviteRequested", function(source: string)
		self:_prompt(if type(source) == "string" then source else "game")
	end)
	return self
end

function SocialInviteController._unavailable(self: SocialInviteController)
	self.App:ShowToast("toast.invalid_action", "Warning")
end

function SocialInviteController._prompt(self: SocialInviteController, source: string)
	if self.Destroyed or os.clock() - self.LastPromptAt < 2 then
		return
	end
	self.LastPromptAt = os.clock()
	local player = Players.LocalPlayer
	local canCheckOk, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if canCheckOk and canInvite ~= true then
		self:_unavailable()
		return
	end

	local options: any = nil
	pcall(function()
		options = Instance.new("ExperienceInviteOptions")
		local roundId = string.sub(self.App:GetRoundId(), 1, 96)
		options.LaunchData = `source={string.sub(source, 1, 24)}&round={roundId}`
	end)

	local promptOk = pcall(function()
		if options then
			SocialService:PromptGameInvite(player, options)
		else
			SocialService:PromptGameInvite(player)
		end
	end)
	if options then
		options:Destroy()
	end
	if not promptOk then
		self:_unavailable()
	end
end

function SocialInviteController.Destroy(self: SocialInviteController)
	self.Destroyed = true
end

return SocialInviteController
