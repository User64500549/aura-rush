--!strict

export type Rate = {
	capacity: number,
	refillPerSecond: number,
}

type Bucket = {
	tokens: number,
	updatedAt: number,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Limiter = typeof(setmetatable(
	{} :: {
		_buckets: { [string]: Bucket },
		_clock: () -> number,
	},
	RateLimiter
))

function RateLimiter.new(clock: (() -> number)?): Limiter
	local resolvedClock = clock or os.clock
	return setmetatable({
		_buckets = {},
		_clock = resolvedClock,
	}, RateLimiter)
end

function RateLimiter.Allow(self: Limiter, key: string, rate: Rate, cost: number?): (boolean, number)
	assert(rate.capacity > 0, "rate.capacity must be positive")
	assert(rate.refillPerSecond >= 0, "rate.refillPerSecond must not be negative")

	local resolvedCost = cost or 1
	assert(resolvedCost > 0, "cost must be positive")

	local now = self._clock()
	local bucket = self._buckets[key]
	if bucket == nil then
		bucket = {
			tokens = rate.capacity,
			updatedAt = now,
		}
		self._buckets[key] = bucket
	end

	local elapsed = math.max(0, now - bucket.updatedAt)
	bucket.tokens = math.min(rate.capacity, bucket.tokens + elapsed * rate.refillPerSecond)
	bucket.updatedAt = now

	if bucket.tokens >= resolvedCost then
		bucket.tokens -= resolvedCost
		return true, 0
	end

	if rate.refillPerSecond == 0 then
		return false, math.huge
	end

	return false, (resolvedCost - bucket.tokens) / rate.refillPerSecond
end

function RateLimiter.Reset(self: Limiter, key: string)
	self._buckets[key] = nil
end

function RateLimiter.ResetPrefix(self: Limiter, prefix: string)
	for key in self._buckets do
		if string.sub(key, 1, #prefix) == prefix then
			self._buckets[key] = nil
		end
	end
end

function RateLimiter.Prune(self: Limiter, maximumIdleSeconds: number): number
	assert(maximumIdleSeconds >= 0, "maximumIdleSeconds must not be negative")
	local now = self._clock()
	local removed = 0
	for key, bucket in self._buckets do
		if now - bucket.updatedAt >= maximumIdleSeconds then
			self._buckets[key] = nil
			removed += 1
		end
	end
	return removed
end

return table.freeze(RateLimiter)
