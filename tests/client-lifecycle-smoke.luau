--!strict

local StarterPlayer = game:GetService("StarterPlayer")

local checks = 0
local function check(condition: boolean, message: string): ()
	assert(condition, "AURA RUSH client lifecycle failure: " .. message)
	checks += 1
end

local clientRoot = StarterPlayer.StarterPlayerScripts:FindFirstChild("AuraRushClient")
check(clientRoot ~= nil and clientRoot:IsA("Folder"), "client root is missing")

local captureController = (clientRoot :: Folder):FindFirstChild("CaptureController", true)
check(
	captureController ~= nil and captureController:IsA("ModuleScript"),
	"CaptureController is missing"
)
local captureSource = (captureController :: ModuleScript).Source
local takeStart = string.find(captureSource, "function CaptureController.TakeScreenshot", 1, true)
local destroyStart = string.find(captureSource, "function CaptureController.Destroy", 1, true)
check(takeStart ~= nil and destroyStart ~= nil, "capture lifecycle functions are missing")
local takeSource = string.sub(captureSource, takeStart :: number, (destroyStart :: number) - 1)
local destroySource = string.sub(captureSource, destroyStart :: number)
check(
	string.find(takeSource, "connection:Disconnect()", 1, true) == nil,
	"taking one screenshot disables future photo spots"
)
check(
	string.find(destroySource, "connection:Disconnect()", 1, true) ~= nil,
	"CaptureController leaks its prompt listener on destroy"
)
check(
	string.find(destroySource, "table.clear(self.Connections)", 1, true) ~= nil,
	"CaptureController keeps dead connection references"
)

local adminController = (clientRoot :: Folder):FindFirstChild("AdminDashboardController", true)
check(
	adminController ~= nil and adminController:IsA("ModuleScript"),
	"AdminDashboardController is missing"
)
local adminSource = (adminController :: ModuleScript).Source
check(
	string.find(adminSource, "AutomaticCanvasSize = Enum.AutomaticSize.Y", 1, true) ~= nil
		and string.find(adminSource, "ScrollingFrame", 1, true) ~= nil,
	"admin dashboard can overlap instead of scrolling on a compact viewport"
)
check(
	string.find(adminSource, "function AdminDashboardController.Destroy", 1, true) ~= nil
		and string.find(adminSource, "connection:Disconnect()", 1, true) ~= nil,
	"admin dashboard does not release client connections"
)

print(`AURA_RUSH_CLIENT_LIFECYCLE_PASS ({checks} checks)`)
