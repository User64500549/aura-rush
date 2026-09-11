--!strict

local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")

local AppModule = require(script.Parent.Parent.UI.App)
local RemixOverlayModule = require(script.Parent.Parent.UI.RemixOverlay)
local RemoteRegistryModule = require(script.Parent.RemoteRegistry)

type App = AppModule.App
type RemixOverlay = RemixOverlayModule.RemixOverlay
type RemoteRegistry = RemoteRegistryModule.RemoteRegistry
type AnyMap = { [string]: any }

local RemixController = {}
RemixController.__index = RemixController

export type RemixController = typeof(setmetatable(
	{} :: {
		App: App,
		Remotes: RemoteRegistry,
		Overlay: RemixOverlay,
		Connections: { RBXScriptConnection },
		ActionRemote: RemoteEvent?,
		ViewportConnection: RBXScriptConnection?,
	},
	RemixController
))

function RemixController.new(app: App, remotes: RemoteRegistry): RemixController
	local parent = app.ScreenGui.Parent
	assert(parent and parent:IsA("PlayerGui"), "Remix City HUD requires PlayerGui")
	local overlay = RemixOverlayModule.new(parent)
	local self: RemixController = setmetatable({
		App = app,
		Remotes = remotes,
		Overlay = overlay,
		Connections = {},
		ActionRemote = remotes:GetEvent("RemixAction"),
		ViewportConnection = nil,
	}, RemixController)

	overlay:SetActionHandler(function(action: string, detail: AnyMap?)
		local event = self.ActionRemote or self.Remotes:GetEvent("RemixAction")
		self.ActionRemote = event
		if not event then
			return
		end
		local payload = if type(detail) == "table" then table.clone(detail) else {}
		payload.action = action
		event:FireServer(payload)
	end)
	table.insert(
		self.Connections,
		app:On("SaveRemix", function()
			local event = self.ActionRemote or self.Remotes:GetEvent("RemixAction")
			self.ActionRemote = event
			if event then
				event:FireServer({ action = "save_remix" })
			end
		end)
	)

	local updateEvent = remotes:GetEvent("RemixUpdate")
	if updateEvent then
		table.insert(
			self.Connections,
			updateEvent.OnClientEvent:Connect(function(payload: any)
				if type(payload) == "table" and type(payload.data) == "table" then
					if payload.kind == "ReplayPlayback" then
						self.Overlay:PlayReplay(payload.data)
					elseif string.sub(tostring(payload.kind or ""), 1, 9) == "CityPulse" then
						self.Overlay:ApplyCityPulse(payload.data)
					else
						self.Overlay:Apply(payload.data)
					end
				end
			end)
		)
	end

	table.insert(
		self.Connections,
		ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
			if prompt:GetAttribute("AuraRushDistrictPreview") == true then
				self.App:ShowToast("DistrictPreview", "Info", {
					name = tostring(prompt:GetAttribute("DistrictNameRu") or "Район"),
					hint = tostring(
						prompt:GetAttribute("DistrictHintRu") or "Новый маршрут"
					),
				})
			end
		end)
	)

	table.insert(
		self.Connections,
		app:On("SnapshotApplied", function(snapshot: any)
			if type(snapshot) == "table" and type(snapshot.remix) == "table" then
				self.Overlay:Apply(snapshot.remix)
			end
		end)
	)
	table.insert(
		self.Connections,
		app:On("LocalSettingsChanged", function(settings: any)
			if type(settings) == "table" then
				self.Overlay:SetReducedMotion(settings.reducedMotion == true)
			end
		end)
	)

	local settings = app:GetSettings()
	overlay:SetReducedMotion(settings.reducedMotion == true)
	local function syncPresentation(): ()
		overlay:SetSuppressed(app.ScreenGui:GetAttribute("SuppressSecondaryHud") == true)
	end
	table.insert(
		self.Connections,
		app.ScreenGui:GetAttributeChangedSignal("SuppressSecondaryHud"):Connect(syncPresentation)
	)
	syncPresentation()
	local function bindViewport(): ()
		if self.ViewportConnection then
			self.ViewportConnection:Disconnect()
			self.ViewportConnection = nil
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			overlay:UpdateViewport(Vector2.new(1280, 720))
			return
		end
		overlay:UpdateViewport(camera.ViewportSize)
		self.ViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			overlay:UpdateViewport(camera.ViewportSize)
		end)
	end
	bindViewport()
	table.insert(
		self.Connections,
		Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport)
	)

	return self
end

function RemixController.Destroy(self: RemixController): ()
	if self.ViewportConnection then
		self.ViewportConnection:Disconnect()
		self.ViewportConnection = nil
	end
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self.Overlay:Destroy()
end

return RemixController
