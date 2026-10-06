--!strict
--[[
	Progression
	Mass -> tier -> scale, plus the XP/level curve. Pure functions: the server
	uses them as the authority and the client uses them only for display.
]]

local SizeConfig = require(script.Parent.Parent.Config.SizeConfig)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local MathUtil = require(script.Parent.Parent.Util.MathUtil)

local Progression = {}

local Tiers = SizeConfig.Tiers

function Progression.tierForMass(mass: number): number
	local tier = 1
	for i, def in Tiers do
		if mass >= def.MassRequired then
			tier = i
		else
			break
		end
	end
	return tier
end

-- Returns tier index, fraction toward the next tier [0,1], and the next tier's
-- requirement (nil at max tier).
function Progression.tierProgress(mass: number): (number, number, number?)
	local tier = Progression.tierForMass(mass)
	local current = Tiers[tier]
	local nextTier = Tiers[tier + 1]
	if not nextTier then
		return tier, 1, nil
	end
	local fraction = MathUtil.inverseLerp(current.MassRequired, nextTier.MassRequired, mass)
	return tier, math.clamp(fraction, 0, 1), nextTier.MassRequired
end

-- Natural (un-shrunk) character scale for a mass value. Within a tier, scale
-- creeps toward the next tier's scale but only covers 35% of the gap so the
-- tier-up still delivers a visible growth spurt.
local IN_TIER_SHARE = 0.35

function Progression.scaleForMass(mass: number): number
	local tier, fraction = Progression.tierProgress(mass)
	local current = Tiers[tier]
	local nextTier = Tiers[tier + 1]
	local scale: number
	if nextTier then
		scale = MathUtil.logLerp(current.Scale, nextTier.Scale, IN_TIER_SHARE * fraction ^ 0.9)
	else
		local overflow = math.max(1, mass / current.MassRequired)
		scale = current.Scale * (1 + SizeConfig.OverflowScalePerDoubling * math.log(overflow, 2))
	end
	return math.clamp(scale, GameConfig.MinScale, GameConfig.MaxScale)
end

-- XP needed to go from `level` to `level + 1`.
function Progression.xpToNext(level: number): number
	return math.floor(60 * level ^ 1.55 + 40)
end

-- Applies XP gain and returns new level, leftover XP and levels gained.
function Progression.applyXP(level: number, xp: number, gained: number): (number, number, number)
	local maxLevel = GameConfig.MaxLevel
	local levelsGained = 0
	xp += math.max(0, gained)
	while level < maxLevel do
		local needed = Progression.xpToNext(level)
		if xp < needed then
			break
		end
		xp -= needed
		level += 1
		levelsGained += 1
	end
	if level >= maxLevel then
		xp = 0
	end
	return level, xp, levelsGained
end

-- Skill points granted on reaching `level`.
function Progression.skillPointsForLevel(level: number): number
	if level % 10 == 0 then
		return 3
	elseif level % 5 == 0 then
		return 2
	end
	return 1
end

function Progression.totalSkillPointsAtLevel(level: number): number
	local total = 0
	for l = 2, level do
		total += Progression.skillPointsForLevel(l)
	end
	return total
end

return Progression
