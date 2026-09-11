--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local serverRoot = ServerScriptService:WaitForChild("AuraRushServer")
local servicesRoot = serverRoot:WaitForChild("Services")
local RemoteService = require(servicesRoot:WaitForChild("RemoteService"))

local checks = 0
local function check(condition: boolean, message: string): ()
	assert(condition, "AURA RUSH network security failure: " .. message)
	checks += 1
end

local function expectValid(payload: any): ()
	local valid, reason = RemoteService.ValidatePayload(payload)
	check(valid, "valid payload rejected: " .. reason)
end

local function expectRejected(payload: any, expectedReason: string): ()
	local valid, reason = RemoteService.ValidatePayload(payload)
	check(not valid and reason == expectedReason, `expected {expectedReason}, got {reason}`)
end

local limits = RemoteService.GetPayloadLimits()
check(limits.maxDepth == 5, "payload depth budget drifted")
check(limits.maxNodes == 96, "payload node budget drifted")
check(limits.maxStringBytes == 256, "payload string budget drifted")

expectValid(nil)
expectValid(true)
expectValid(42)
expectValid("route_prism")
expectValid({ action = "react", settings = { reducedMotion = true, uiScale = 1.1 } })
expectValid(string.rep("a", limits.maxStringBytes))
expectValid({ targetUserId = 8_765_432_109 })

expectRejected(0 / 0, "non_finite_number")
expectRejected(math.huge, "non_finite_number")
expectRejected(string.rep("a", limits.maxStringBytes + 1), "string_limit")
expectRejected(Vector3.zero, "unsupported_type")

local instancePayload = Instance.new("Folder")
expectRejected(instancePayload, "unsupported_type")
instancePayload:Destroy()

local deepPayload: any = {}
local deepCursor = deepPayload
for _ = 1, limits.maxDepth do
	local child = {}
	deepCursor.child = child
	deepCursor = child
end
expectRejected(deepPayload, "depth_limit")

local widePayload = {}
for index = 1, limits.maxNodes do
	widePayload[index] = index
end
expectRejected(widePayload, "node_limit")

local longKeyPayload = {}
longKeyPayload[string.rep("k", 65)] = true
expectRejected(longKeyPayload, "key_limit")

local cyclicPayload: any = {}
cyclicPayload.self = cyclicPayload
expectRejected(cyclicPayload, "cycle")

local source = (servicesRoot:WaitForChild("RemoteService") :: ModuleScript).Source
local eventBinding = string.find(source, "remote.OnServerEvent:Connect", 1, true)
local functionBinding = string.find(source, "remote.OnServerInvoke = function", 1, true)
local validatorCalls = {}
local cursor = 1
while true do
	local found = string.find(source, "RemoteService.ValidatePayload(payload)", cursor, true)
	if not found then
		break
	end
	table.insert(validatorCalls, found)
	cursor = found + 1
end
check(eventBinding ~= nil and functionBinding ~= nil, "remote bindings are missing")
check(#validatorCalls == 2, "payload guard is not applied to both remote classes")
check(
	eventBinding < validatorCalls[1] and validatorCalls[1] < functionBinding,
	"RemoteEvent payload guard is outside its boundary"
)
check(functionBinding < validatorCalls[2], "RemoteFunction payload guard is outside its boundary")

print(`AURA_RUSH_NETWORK_SECURITY_PASS ({checks} checks)`)
