--!strict
--[[
	ScaleMath
	Everything that depends on character scale. These curves are deliberately
	sub-linear: tiny players are nimble (many body-lengths per second) while
	titans cover huge distances yet feel heavy (fewer body-lengths per second,
	stronger gravity). Shared so client movement and server validation agree.

	Reference values (body = 5 studs * scale):
	  scale 0.2  -> walk  5 st/s (5 bodies/s), jump 1.7 st, airtime ~0.4 s
	  scale 16   -> walk 118 st/s (1.5 bodies/s), jump 87 st, airtime ~1.2 s
	  scale 340  -> walk 1060 st/s (0.6 bodies/s), jump 1360 st, airtime ~2.9 s
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local ScaleMath = {}

ScaleMath.BASE_HEIGHT = 5 -- R15 default height in studs at scale 1
ScaleMath.WORLD_GRAVITY = 196.2

local function clampScale(scale: number): number
	return math.clamp(scale, GameConfig.MinScale, GameConfig.MaxScale)
end

function ScaleMath.height(scale: number): number
	return ScaleMath.BASE_HEIGHT * clampScale(scale)
end

function ScaleMath.walkSpeed(scale: number): number
	return 16 * clampScale(scale) ^ 0.72
end

function ScaleMath.sprintMultiplier(scale: number): number
	-- Sprinting matters a bit more for small players who traverse dense areas.
	return 1.55 - 0.08 * math.clamp(math.log10(clampScale(scale) / 0.2) / 3.2, 0, 1)
end

function ScaleMath.jumpHeight(scale: number): number
	return 7.2 * clampScale(scale) ^ 0.9
end

-- Extra gravity applied to the character (via a client VectorForce) so large
-- characters do not float for many seconds.
function ScaleMath.gravityMultiplier(scale: number): number
	return math.clamp(clampScale(scale) ^ 0.33, 0.65, 7)
end

function ScaleMath.effectiveGravity(scale: number): number
	return ScaleMath.WORLD_GRAVITY * ScaleMath.gravityMultiplier(scale)
end

function ScaleMath.jumpVelocity(scale: number, heightMultiplier: number?): number
	local h = ScaleMath.jumpHeight(scale) * (heightMultiplier or 1)
	return math.sqrt(2 * ScaleMath.effectiveGravity(scale) * h)
end

function ScaleMath.airTime(scale: number, heightMultiplier: number?): number
	return 2 * ScaleMath.jumpVelocity(scale, heightMultiplier) / ScaleMath.effectiveGravity(scale)
end

-- Horizontal distance covered by a running jump (used to generate feasible
-- challenge courses and to validate parkour finishes).
function ScaleMath.jumpDistance(scale: number, speedMultiplier: number?, heightMultiplier: number?): number
	return ScaleMath.walkSpeed(scale) * (speedMultiplier or 1) * ScaleMath.airTime(scale, heightMultiplier)
end

function ScaleMath.cameraDistance(scale: number): number
	return math.max(4, 11 * clampScale(scale) ^ 0.97)
end

function ScaleMath.cameraZoomLimits(scale: number): (number, number)
	local base = ScaleMath.cameraDistance(scale)
	return math.max(0.5, base * 0.25), math.max(12, base * 3.2)
end

-- Interaction / pickup distances measured from the root part.
function ScaleMath.interactRange(scale: number): number
	return 4 + ScaleMath.height(scale) * 1.4
end

function ScaleMath.collectRange(scale: number): number
	return 2.5 + ScaleMath.height(scale) * 0.75
end

function ScaleMath.strength(scale: number): number
	return 10 * clampScale(scale) ^ 1.4
end

-- Footstep / landing presentation parameters.
function ScaleMath.footstepPitch(scale: number): number
	return math.clamp(1.6 - 0.32 * math.log10(clampScale(scale) / 0.2 + 1) * 1.6, 0.35, 1.6)
end

function ScaleMath.footstepVolume(scale: number): number
	return math.clamp(0.15 + 0.12 * math.log10(clampScale(scale) / 0.2 + 1), 0.15, 0.75)
end

function ScaleMath.effectSize(scale: number): number
	return ScaleMath.height(scale) / ScaleMath.BASE_HEIGHT
end

-- Max plausible horizontal speed for anti-exploit validation. Includes sprint,
-- dash bursts and upgrade multipliers with headroom for latency.
function ScaleMath.maxPlausibleSpeed(scale: number, speedMultiplier: number): number
	local sprint = ScaleMath.walkSpeed(scale) * ScaleMath.sprintMultiplier(scale) * speedMultiplier
	return sprint * 3.2 + 40
end

return ScaleMath
