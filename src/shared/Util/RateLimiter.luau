--!strict
--[[
	RateLimiter
	Token-bucket limiter keyed by an arbitrary key (usually player + action).
	Buckets refill continuously so short latency bursts (a few queued packets
	arriving together) are absorbed instead of punishing legitimate players.
]]

export type RateLimiter = {
	Check: (self: RateLimiter, key: any, cost: number?) -> boolean,
	Reset: (self: RateLimiter, key: any) -> (),
	Prune: (self: RateLimiter) -> (),
}

type Bucket = { tokens: number, updated: number }

local RateLimiter = {}
RateLimiter.__index = RateLimiter

-- `ratePerSecond` tokens refill per second, up to `burst` stored tokens.
function RateLimiter.new(ratePerSecond: number, burst: number?, clock: (() -> number)?): RateLimiter
	local self = setmetatable({
		_rate = ratePerSecond,
		_burst = burst or math.max(1, ratePerSecond),
		_buckets = {} :: { [any]: Bucket },
		_clock = clock or os.clock,
	}, RateLimiter)
	return (self :: any) :: RateLimiter
end

function RateLimiter.Check(self: any, key: any, cost: number?): boolean
	local now = self._clock()
	local amount = cost or 1
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._burst, updated = now }
		self._buckets[key] = bucket
	else
		local elapsed = math.max(0, now - bucket.updated)
		bucket.tokens = math.min(self._burst, bucket.tokens + elapsed * self._rate)
		bucket.updated = now
	end
	if bucket.tokens >= amount then
		bucket.tokens -= amount
		return true
	end
	return false
end

function RateLimiter.Reset(self: any, key: any)
	self._buckets[key] = nil
end

-- Drops full buckets (idle keys) so long-running servers do not accumulate them.
function RateLimiter.Prune(self: any)
	local now = self._clock()
	for key, bucket in self._buckets do
		if bucket.tokens + (now - bucket.updated) * self._rate >= self._burst then
			self._buckets[key] = nil
		end
	end
end

return RateLimiter
