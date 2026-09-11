--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AppModule = require(script.Parent.Parent.UI.App)
local RemoteRegistryModule = require(script.Parent.RemoteRegistry)

type App = AppModule.App
type RemoteRegistry = RemoteRegistryModule.RemoteRegistry
type AnyMap = { [string]: any }

local RoundController = {}
RoundController.__index = RoundController

export type RoundController = typeof(setmetatable(
	{} :: {
		App: App,
		Remotes: RemoteRegistry,
		Connections: { RBXScriptConnection },
		LastStateVersion: number,
		CurrentRoundId: string,
		EndsAt: number,
		LastTimerSecond: number,
		Destroyed: boolean,
	},
	RoundController
))

function RoundController.new(app: App, remotes: RemoteRegistry): RoundController
	local self: RoundController = setmetatable({
		App = app,
		Remotes = remotes,
		Connections = {},
		LastStateVersion = -1,
		CurrentRoundId = "",
		EndsAt = 0,
		LastTimerSecond = -1,
		Destroyed = false,
	}, RoundController)

	self:_bindUi()
	self:_bindServer()
	self:_startTimer()
	task.defer(function()
		self:RequestSnapshot()
		self:RequestMeta()
	end)
	return self
end

function RoundController._fire(self: RoundController, remoteName: string, payload: AnyMap)
	local remote = self.Remotes:GetEvent(remoteName)
	if not remote then
		self.App:ShowToast("ConnectionUnavailable", "Warning")
		return
	end
	remote:FireServer(payload)
end

function RoundController._bindUi(self: RoundController)
	self.App:On("VoteBrief", function(briefId: string)
		if type(briefId) == "string" and #briefId > 0 then
			self:_fire("VoteBrief", { briefId = briefId })
		end
	end)

	self.App:On("ChooseRoute", function(routeId: string)
		if type(routeId) == "string" and #routeId > 0 then
			self:_fire("ChooseRoute", { routeId = routeId })
		end
	end)

	self.App:On("BeatHit", function(beatIndex: number, sampleTime: number, lane: number)
		if
			type(beatIndex) == "number"
			and type(sampleTime) == "number"
			and type(lane) == "number"
		then
			self:_fire("BeatHit", {
				beatIndex = math.floor(beatIndex),
				sampleTime = sampleTime,
				lane = math.clamp(math.floor(lane), 1, 4),
			})
		end
	end)

	self.App:On("PrismInput", function(index: number)
		if type(index) == "number" then
			self:_fire("SubmitPrism", { index = math.clamp(math.floor(index), 1, 4) })
		end
	end)

	self.App:On("SetStyleReady", function(ready: boolean)
		if type(ready) == "boolean" then
			self:_fire("SetStyleReady", { ready = ready })
		end
	end)

	self.App:On("SettingsChanged", function(settings: AnyMap)
		if type(settings) == "table" then
			self:_fire("UpdateSettings", { settings = settings })
		end
	end)

	self.App:On("DismissOnboarding", function()
		self:_fire("UpdateSettings", { settings = { onboardingComplete = true } })
	end)

	self.App:On("SaveLook", function()
		self:_fire("SaveLook", {})
	end)

	self.App:On("PostcardAction", function(action: string)
		if type(action) == "string" and #action > 0 then
			self:_fire("PostcardAction", { action = action })
		end
	end)

	self.App:On("Requeue", function()
		self:_fire("Requeue", {})
	end)

	self.App:On("ActivateToken", function(tokenId: string)
		if type(tokenId) == "string" and #tokenId > 0 then
			self:_fire("ActivateToken", { tokenId = tokenId })
		end
	end)
end

function RoundController._bindServer(self: RoundController)
	local snapshotEvent = self.Remotes:GetEvent("RoundSnapshot")
	if snapshotEvent then
		table.insert(
			self.Connections,
			snapshotEvent.OnClientEvent:Connect(function(payload: any)
				if type(payload) == "table" then
					self:_applySnapshot(payload)
				end
			end)
		)
	end

	local progressEvent = self.Remotes:GetEvent("ProgressUpdate")
	if progressEvent then
		table.insert(
			self.Connections,
			progressEvent.OnClientEvent:Connect(function(payload: any)
				if type(payload) ~= "table" then
					return
				end
				if
					type(payload.userId) == "number"
					and payload.userId ~= Players.LocalPlayer.UserId
				then
					return
				end
				self.App:ApplyProgressEvent(payload)
			end)
		)
	end

	local toastEvent = self.Remotes:GetEvent("Toast")
	if toastEvent then
		table.insert(
			self.Connections,
			toastEvent.OnClientEvent:Connect(function(payload: any)
				if type(payload) == "table" then
					local args = if type(payload.args) == "table"
						then table.clone(payload.args)
						else {}
					if payload.detail ~= nil then
						args.detail = tostring(payload.detail)
					end
					if payload.from ~= nil then
						args.from = tostring(payload.from)
					end
					self.App:ShowToast(
						if type(payload.key) == "string" then payload.key else "Info",
						if type(payload.tone) == "string" then payload.tone else "Info",
						args
					)
				elseif type(payload) == "string" then
					-- Legacy servers may still send a free-form string. Never render it
					-- directly; current servers use allowlisted localization keys.
					self.App:ShowToast("Info", "Info")
				end
			end)
		)
	end

	local postcardEvent = self.Remotes:GetEvent("PostcardUpdate")
	if postcardEvent then
		table.insert(
			self.Connections,
			postcardEvent.OnClientEvent:Connect(function(payload: any)
				if type(payload) == "table" and payload.kind == "Created" then
					self.App:ShowToast("postcard_created", "Success")
				end
			end)
		)
	end

	for _, definition in
		{
			{ name = "MetaUpdate", apply = "meta" },
			{ name = "RunUpdate", apply = "run" },
		}
	do
		local optionalEvent = self.Remotes:GetEvent(definition.name)
		if optionalEvent then
			table.insert(
				self.Connections,
				optionalEvent.OnClientEvent:Connect(function(payload: any)
					if type(payload) ~= "table" then
						return
					end
					if definition.apply == "meta" then
						self.App:ApplyMetaUpdate(payload)
					else
						self.App:ApplyRunUpdate(payload)
					end
				end)
			)
		end
	end
end

function RoundController._applySnapshot(self: RoundController, snapshot: AnyMap)
	local roundId = if type(snapshot.roundId) == "string" then snapshot.roundId else ""
	local stateVersion = tonumber(snapshot.stateVersion) or 0
	if roundId == self.CurrentRoundId and stateVersion < self.LastStateVersion then
		return
	end

	if roundId ~= self.CurrentRoundId then
		self.CurrentRoundId = roundId
		self.LastStateVersion = -1
	end
	self.LastStateVersion = stateVersion
	self.EndsAt = tonumber(snapshot.endsAt) or 0
	self.LastTimerSecond = -1
	self.App:ApplySnapshot(snapshot)
end

function RoundController.RequestSnapshot(self: RoundController)
	if self.Destroyed then
		return
	end
	local request = self.Remotes:GetFunction("RequestSnapshot")
	if not request then
		self.App:SetLoadingStatus("Не удалось войти в район")
		self.App:ShowToast("ConnectionUnavailable", "Warning")
		return
	end

	self.App:SetLoadingStatus("Получаем тему раунда…")
	local ok, result = pcall(function()
		return request:InvokeServer()
	end)
	if not ok then
		self.App:SetLoadingStatus("Синхронизация задерживается…")
		task.delay(2.5, function()
			if not self.Destroyed then
				self:RequestSnapshot()
			end
		end)
		return
	end

	if type(result) == "table" then
		local snapshot = if type(result.snapshot) == "table" then result.snapshot else result
		self:_applySnapshot(snapshot)
	else
		self.App:SetLoadingStatus("Открываем портал…")
	end
end

function RoundController.RequestMeta(self: RoundController)
	if self.Destroyed then
		return
	end
	local request = self.Remotes:GetFunction("RequestMeta")
	if not request then
		return
	end
	local ok, result = pcall(function()
		return request:InvokeServer({})
	end)
	if not ok or type(result) ~= "table" then
		return
	end
	self.App:ApplyMetaUpdate(result)
	local run = result.runPlan or result.run
	if type(run) == "table" then
		self.App:ApplyRunUpdate(run)
	end
end

function RoundController._startTimer(self: RoundController)
	table.insert(
		self.Connections,
		RunService.Heartbeat:Connect(function()
			if self.EndsAt <= 0 then
				if self.LastTimerSecond ~= 0 then
					self.LastTimerSecond = 0
					self.App:SetTimer(0)
				end
				return
			end
			local remaining = math.max(0, self.EndsAt - workspace:GetServerTimeNow())
			local rounded = math.ceil(remaining)
			if rounded ~= self.LastTimerSecond then
				self.LastTimerSecond = rounded
				self.App:SetTimer(remaining)
			end
		end)
	)
end

function RoundController.Destroy(self: RoundController)
	self.Destroyed = true
	for _, connection in self.Connections do
		connection:Disconnect()
	end
end

return RoundController
