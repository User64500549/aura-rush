--!strict

local DataStoreRetry = {}

export type Policy = {
	maxAttempts: number,
	initialDelaySeconds: number,
	backoffMultiplier: number,
	maximumDelaySeconds: number,
}

local DEFAULT_POLICY: Policy = table.freeze({
	maxAttempts = 3,
	initialDelaySeconds = 0.35,
	backoffMultiplier = 2,
	maximumDelaySeconds = 1.5,
})

function DataStoreRetry.NormalizePolicy(rawPolicy: any?): Policy
	local candidate = if type(rawPolicy) == "table" then rawPolicy else {}
	local maxAttempts =
		math.clamp(math.floor(tonumber(candidate.maxAttempts) or DEFAULT_POLICY.maxAttempts), 1, 8)
	local initialDelaySeconds = math.clamp(
		tonumber(candidate.initialDelaySeconds) or DEFAULT_POLICY.initialDelaySeconds,
		0,
		5
	)
	local backoffMultiplier =
		math.clamp(tonumber(candidate.backoffMultiplier) or DEFAULT_POLICY.backoffMultiplier, 1, 4)
	local maximumDelaySeconds = math.clamp(
		tonumber(candidate.maximumDelaySeconds) or DEFAULT_POLICY.maximumDelaySeconds,
		0,
		15
	)
	return {
		maxAttempts = maxAttempts,
		initialDelaySeconds = math.min(initialDelaySeconds, maximumDelaySeconds),
		backoffMultiplier = backoffMultiplier,
		maximumDelaySeconds = maximumDelaySeconds,
	}
end

function DataStoreRetry.Run(
	operation: (attempt: number) -> any,
	rawPolicy: any?,
	shouldRetry: ((failure: any, attempt: number) -> boolean)?,
	waiter: ((seconds: number) -> ())?
): (boolean, any, number)
	local policy = DataStoreRetry.NormalizePolicy(rawPolicy)
	local waitFor: (number) -> () = if waiter
		then waiter
		else function(seconds: number): ()
			task.wait(seconds)
		end
	local lastFailure: any = "operation_not_started"
	local attemptsUsed = 0

	for attempt = 1, policy.maxAttempts do
		attemptsUsed = attempt
		local success, result = pcall(operation, attempt)
		if success then
			return true, result, attempt
		end
		lastFailure = result
		if attempt >= policy.maxAttempts then
			break
		end
		if shouldRetry and not shouldRetry(result, attempt) then
			break
		end

		local delaySeconds = math.min(
			policy.maximumDelaySeconds,
			policy.initialDelaySeconds * policy.backoffMultiplier ^ (attempt - 1)
		)
		if delaySeconds > 0 then
			waitFor(delaySeconds)
		end
	end

	return false, lastFailure, attemptsUsed
end

return DataStoreRetry
