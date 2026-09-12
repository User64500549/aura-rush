--!strict

-- Shared guard for small, server-owned DataStore records outside the player
-- profile. Callers still own idempotency: an UpdateAsync failure can have an
-- unknown final state, so every retried transform must tolerate replay.
local DataStoreService = game:GetService("DataStoreService")

local DataStoreRetry = require(script.Parent.DataStoreRetry)

local DataStoreOperation = {}

export type Diagnostics = {
	requests: number,
	attempts: number,
	retries: number,
	failures: number,
	budgetWaits: number,
}

local function requestType(name: string): any
	local requestTypes: any = Enum.DataStoreRequestType
	local ok, result = pcall(function()
		return requestTypes[name]
	end)
	return if ok and typeof(result) == "EnumItem" then result else nil
end

local function setting(config: any, primary: string, secondary: string, fallback: number): number
	local value = if type(config) == "table" then config[primary] else nil
	if value == nil and type(config) == "table" then
		value = config[secondary]
	end
	local numberValue = tonumber(value)
	if numberValue == nil or numberValue ~= numberValue or numberValue == math.huge then
		return fallback
	end
	return numberValue
end

local function retryPolicy(config: any): any
	return {
		maxAttempts = math.clamp(
			math.floor(setting(config, "MaximumAttempts", "maxAttempts", 3)),
			1,
			8
		),
		initialDelaySeconds = math.clamp(
			setting(config, "InitialRetryDelaySeconds", "initialDelaySeconds", 0.35),
			0,
			5
		),
		backoffMultiplier = math.clamp(
			setting(config, "BackoffMultiplier", "backoffMultiplier", 2),
			1,
			4
		),
		maximumDelaySeconds = math.clamp(
			setting(config, "MaximumRetryDelaySeconds", "maximumDelaySeconds", 1.5),
			0,
			15
		),
	}
end

local function shouldRetry(failure: any, _attempt: number): boolean
	local message = string.lower(tostring(failure))
	for _, token in
		{
			"keynameempty",
			"keynamelimit",
			"valuenotallowed",
			"studioaccesstoapisnotallowed",
			"datamodelnoaccess",
			"luawebsrvsnoaccess",
			"invalidargument",
		}
	do
		if string.find(message, token, 1, true) then
			return false
		end
	end
	return true
end

local function hasBudget(operation: "Read" | "Update"): boolean
	local standardRead = requestType("StandardRead")
	local standardWrite = requestType("StandardWrite")
	if standardRead then
		if DataStoreService:GetRequestBudgetForRequestType(standardRead) <= 0 then
			return false
		end
		if operation == "Read" or standardWrite == nil then
			return true
		end
		return DataStoreService:GetRequestBudgetForRequestType(standardWrite) > 0
	end
	local legacy = requestType(if operation == "Read" then "GetAsync" else "UpdateAsync")
	return if legacy then DataStoreService:GetRequestBudgetForRequestType(legacy) > 0 else true
end

local function waitForBudget(
	operation: "Read" | "Update",
	config: any,
	diagnostics: Diagnostics
): boolean
	local maximumWait = math.clamp(
		setting(config, "RequestBudgetWaitSeconds", "requestBudgetWaitSeconds", 2),
		0,
		10
	)
	local pollSeconds = math.clamp(
		setting(config, "RequestBudgetPollSeconds", "requestBudgetPollSeconds", 0.1),
		0.05,
		1
	)
	local deadline = os.clock() + maximumWait
	local waited = false
	while true do
		local ok, available = pcall(hasBudget, operation)
		if not ok or available then
			if waited then
				diagnostics.budgetWaits += 1
			end
			return true
		end
		if os.clock() >= deadline then
			if waited then
				diagnostics.budgetWaits += 1
			end
			return false
		end
		waited = true
		task.wait(math.min(pollSeconds, math.max(0, deadline - os.clock())))
	end
end

function DataStoreOperation.NewDiagnostics(): Diagnostics
	return {
		requests = 0,
		attempts = 0,
		retries = 0,
		failures = 0,
		budgetWaits = 0,
	}
end

function DataStoreOperation.Snapshot(diagnostics: Diagnostics?): Diagnostics
	if not diagnostics then
		return DataStoreOperation.NewDiagnostics()
	end
	return table.clone(diagnostics)
end

function DataStoreOperation.Run<T>(
	operation: "Read" | "Update",
	callback: () -> T,
	config: any,
	diagnostics: Diagnostics
): (boolean, T | any)
	diagnostics.requests += 1
	local ok, result, attempts = DataStoreRetry.Run(function()
		if not waitForBudget(operation, config, diagnostics) then
			error("DataStore request budget unavailable", 0)
		end
		return callback()
	end, retryPolicy(config), shouldRetry)
	diagnostics.attempts += attempts
	diagnostics.retries += math.max(0, attempts - 1)
	if not ok then
		diagnostics.failures += 1
	end
	return ok, result
end

function DataStoreOperation.Read(
	store: any,
	key: string,
	config: any,
	diagnostics: Diagnostics
): (boolean, any)
	return DataStoreOperation.Run("Read", function()
		return store:GetAsync(key)
	end, config, diagnostics)
end

function DataStoreOperation.Update(
	store: any,
	key: string,
	transform: (current: any) -> any,
	config: any,
	diagnostics: Diagnostics
): (boolean, any)
	return DataStoreOperation.Run("Update", function()
		return store:UpdateAsync(key, transform)
	end, config, diagnostics)
end

return table.freeze(DataStoreOperation)
