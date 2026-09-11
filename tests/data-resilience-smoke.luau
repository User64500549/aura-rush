--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverRoot = ServerScriptService:WaitForChild("AuraRushServer")
local retryModule = serverRoot:WaitForChild("Util"):WaitForChild("DataStoreRetry")
local DataStoreRetry = require(retryModule)

local checks = 0
local function check(condition: boolean, message: string): ()
	assert(condition, "AURA RUSH data resilience failure: " .. message)
	checks += 1
end

local normalized = DataStoreRetry.NormalizePolicy({
	maxAttempts = 99,
	initialDelaySeconds = -3,
	backoffMultiplier = 99,
	maximumDelaySeconds = 0.15,
})
check(normalized.maxAttempts == 8, "attempt count was not bounded")
check(normalized.initialDelaySeconds == 0, "negative initial delay was accepted")
check(normalized.backoffMultiplier == 4, "backoff multiplier was not bounded")
check(normalized.maximumDelaySeconds == 0.15, "maximum delay changed unexpectedly")

local immediateCalls = 0
local immediateSuccess, immediateResult, immediateAttempts = DataStoreRetry.Run(
	function(attempt: number)
		immediateCalls += 1
		return `ok_{attempt}`
	end,
	nil,
	nil,
	function(_seconds: number) end
)
check(immediateSuccess, "successful operation was rejected")
check(immediateResult == "ok_1", "successful result was not preserved")
check(immediateAttempts == 1 and immediateCalls == 1, "successful operation was retried")

local transientCalls = 0
local observedDelays = {}
local recovered, recoveredResult, recoveredAttempts = DataStoreRetry.Run(
	function(attempt: number)
		transientCalls += 1
		if attempt < 4 then
			error(`transient_{attempt}`)
		end
		return 42
	end,
	{
		maxAttempts = 4,
		initialDelaySeconds = 0.1,
		backoffMultiplier = 2,
		maximumDelaySeconds = 0.15,
	},
	nil,
	function(seconds: number)
		table.insert(observedDelays, seconds)
	end
)
check(recovered and recoveredResult == 42, "transient failure did not recover")
check(recoveredAttempts == 4 and transientCalls == 4, "retry attempt count drifted")
check(#observedDelays == 3, "backoff delay count drifted")
check(math.abs(observedDelays[1] - 0.1) < 0.0001, "first backoff delay drifted")
check(math.abs(observedDelays[2] - 0.15) < 0.0001, "backoff maximum was not applied")
check(math.abs(observedDelays[3] - 0.15) < 0.0001, "backoff maximum was not stable")

local permanentCalls = 0
local permanentSuccess, permanentError, permanentAttempts = DataStoreRetry.Run(
	function(attempt: number)
		permanentCalls += 1
		error(`permanent_{attempt}`)
	end,
	{
		maxAttempts = 6,
		initialDelaySeconds = 0.1,
	},
	function(_failure: any, attempt: number): boolean
		return attempt < 2
	end,
	function(_seconds: number) end
)
check(not permanentSuccess, "permanent failure was reported as success")
check(string.find(tostring(permanentError), "permanent_2", 1, true) ~= nil, "last failure was lost")
check(permanentAttempts == 2 and permanentCalls == 2, "retry predicate did not stop attempts")

local servicesRoot = serverRoot:WaitForChild("Services")
local dataModule = servicesRoot:WaitForChild("DataService")
local dataSource = (dataModule :: ModuleScript).Source
for _, token in
	{
		"DataStoreRetry.Run",
		"GetRequestBudgetForRequestType",
		'requestType("StandardRead")',
		'requestType("StandardWrite")',
		"GetUserIds",
		"GetMetadata",
		"GetPersistenceDiagnostics",
		"autosaveEpoch",
		"autosaveStarted",
	}
do
	check(string.find(dataSource, token, 1, true) ~= nil, `data resilience token missing: {token}`)
end

local Config = require(ReplicatedStorage:WaitForChild("AuraRushShared"):WaitForChild("Config"))
check(type(Config.Persistence) == "table", "persistence policy is missing")
check(Config.Persistence.MaximumAttempts == 3, "production retry count drifted")
check(Config.Persistence.RequestBudgetWaitSeconds == 2, "budget wait policy drifted")

print(`AURA_RUSH_DATA_RESILIENCE_PASS ({checks} checks)`)
