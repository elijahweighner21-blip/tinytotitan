--!strict
--[[
	Pricing
	Upgrade cost curves. Costs grow geometrically per level with a gentle
	linear term so the first few levels are cheap and late levels stay in step
	with the zone-scaled income of later regions.
]]

local MathUtil = require(script.Parent.Parent.Util.MathUtil)

local Pricing = {}

export type PricedUpgrade = {
	BaseCost: number,
	CostGrowth: number,
	MaxLevel: number,
	ResourceCost: { Resource: string, Every: number, Amount: number }?,
}

-- Cost to buy the NEXT level when currently at `level` (0-based). `discount` is
-- a fraction in [0, 0.6] from Ascension perks.
function Pricing.upgradeCost(upgrade: PricedUpgrade, level: number, discount: number?): number
	if level >= upgrade.MaxLevel then
		return math.huge
	end
	local d = math.clamp(discount or 0, 0, 0.6)
	local raw = upgrade.BaseCost * upgrade.CostGrowth ^ level * (1 + 0.04 * level)
	-- Round to 2 significant-ish figures so prices read cleanly in the UI.
	local magnitude = 10 ^ math.max(0, math.floor(math.log10(math.max(raw, 1))) - 1)
	return math.max(1, math.floor(raw * (1 - d) / magnitude + 0.5) * magnitude)
end

-- Optional zone-resource cost required every `Every` levels.
function Pricing.resourceCost(upgrade: PricedUpgrade, level: number): (string?, number)
	local rc = upgrade.ResourceCost
	if not rc then
		return nil, 0
	end
	local nextLevel = level + 1
	if nextLevel % rc.Every ~= 0 then
		return nil, 0
	end
	return rc.Resource, rc.Amount * (nextLevel // rc.Every)
end

function Pricing.totalCost(upgrade: PricedUpgrade, fromLevel: number, toLevel: number, discount: number?): number
	local total = 0
	for l = fromLevel, math.min(toLevel, upgrade.MaxLevel) - 1 do
		total += Pricing.upgradeCost(upgrade, l, discount)
	end
	return total
end

-- Effect value of an upgrade at a level (shared with stat aggregation).
function Pricing.effectAt(perLevel: number, level: number): number
	return perLevel * MathUtil.clamp(level, 0, 10000)
end

return Pricing
