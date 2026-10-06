--!strict
--[[
	MathUtil
	Numeric helpers shared by formulas, movement and UI. Includes the
	sanitisation helpers every server-side number from a client (or from saved
	data) must pass through so NaN / infinity / negative values never reach the
	economy.
]]

local MathUtil = {}

MathUtil.MAX_SAFE = 9.007199254740991e15 -- 2^53: largest exactly representable integer

function MathUtil.isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function MathUtil.clamp(n: number, lo: number, hi: number): number
	if n < lo then
		return lo
	elseif n > hi then
		return hi
	end
	return n
end

-- Returns a finite number in [lo, hi], or `fallback` if `n` is not a finite number.
function MathUtil.sanitize(n: any, lo: number, hi: number, fallback: number): number
	if not MathUtil.isFinite(n) then
		return fallback
	end
	return MathUtil.clamp(n :: number, lo, hi)
end

function MathUtil.sanitizeInt(n: any, lo: number, hi: number, fallback: number): number
	if not MathUtil.isFinite(n) then
		return fallback
	end
	return MathUtil.clamp(math.floor(n :: number), lo, hi)
end

function MathUtil.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function MathUtil.inverseLerp(a: number, b: number, v: number): number
	if a == b then
		return 0
	end
	return (v - a) / (b - a)
end

-- Interpolates in log space; used for scale so growth feels even at every size.
function MathUtil.logLerp(a: number, b: number, t: number): number
	return math.exp(MathUtil.lerp(math.log(a), math.log(b), t))
end

function MathUtil.round(n: number, step: number?): number
	local s = step or 1
	return math.floor(n / s + 0.5) * s
end

function MathUtil.smoothstep(t: number): number
	t = MathUtil.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function MathUtil.easeOutCubic(t: number): number
	t = MathUtil.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end

function MathUtil.easeInOutQuad(t: number): number
	t = MathUtil.clamp(t, 0, 1)
	return if t < 0.5 then 2 * t * t else 1 - (-2 * t + 2) ^ 2 / 2
end

-- Exponential smoothing that is frame-rate independent.
function MathUtil.damp(current: number, target: number, sharpness: number, dt: number): number
	return MathUtil.lerp(current, target, 1 - math.exp(-sharpness * dt))
end

function MathUtil.approach(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

-- Soft cap: linear until `knee`, then grows logarithmically. Keeps late-game
-- multipliers meaningful without exploding.
function MathUtil.softCap(n: number, knee: number, softness: number?): number
	if n <= knee then
		return n
	end
	local s = softness or knee
	return knee + s * math.log(1 + (n - knee) / s)
end

-- Deterministic 32-bit hash (FNV-1a) for seeding daily rotations etc.
function MathUtil.hashString(s: string): number
	local hash = 2166136261
	for i = 1, #s do
		hash = bit32.bxor(hash, string.byte(s, i))
		hash = (hash * 16777619) % 4294967296
	end
	return hash
end

return MathUtil
