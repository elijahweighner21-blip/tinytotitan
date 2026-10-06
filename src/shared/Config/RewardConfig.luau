--!strict
--[[
	RewardConfig
	Stacking rules for every multiplier in the game, plus the zone-scaled reward
	helpers content configs use. Keeping both here means balancing a quest or a
	boost never requires touching service code.

	STACKING RULES (see Formulas/RewardMath):
	  final = floor(base × (1 + Σ additive) × Π max(multiplicative per group))
	  * Additive bonuses (VIP, events, upgrades, ascension, party) are SUMMED,
	    never multiplied together, and capped by MaxAdditive.
	  * Multiplicative sources are grouped; only the strongest in each group
	    applies (two 2× Mass boosts do not make 4×; buying again extends time).
	  * The total multiplier is hard-capped by MaxTotalMultiplier.
	  * Purchases and admin grants bypass multipliers entirely.
]]

local ZoneConfig = require(script.Parent.ZoneConfig)
local Types = require(script.Parent.Parent.Types)

type Reward = Types.Reward

local RewardConfig = {
	MaxAdditive = 4.0, -- +400%
	MaxTotalMultiplier = 15,

	-- Which currencies each additive source affects.
	VIP = { GrowthEnergy = 0.10, XP = 0.05 },
	PartyPerMember = 0.05,
	PartyMax = 0.15,
	PartyRange = 3, -- multiples of the larger member's height

	-- Multiplicative groups.
	Groups = {
		Boost = "Boost", -- timed boosts (developer products / rewards)
		Pass = "Pass", -- permanent game passes (2x Growth Energy)
	},

	-- Sources whose rewards never receive multipliers.
	NoMultiplierSources = {
		Purchase = true,
		Admin = true,
		Refund = true,
		Ascension = true,
		Migration = true,
	} :: { [string]: boolean },

	-- Currencies that multipliers may touch at all. Titan Shards are excluded
	-- from boosts by design (premium currency stays predictable).
	Multipliable = {
		Mass = true,
		XP = true,
		GrowthEnergy = true,
		Resources = true,
	} :: { [string]: boolean },
}

-- Zone-scaled reward used by content definitions. `weight` is a hand-tuned
-- importance factor (1 = a typical small task in that zone).
function RewardConfig.zone(zoneId: string, weight: number, extra: Reward?): Reward
	local zone = ZoneConfig.get(zoneId)
	local scale = if zone then zone.RewardScale else 1
	local reward: Reward = {
		Mass = math.floor(40 * scale * weight),
		GrowthEnergy = math.floor(18 * scale * weight),
		XP = math.floor(25 * math.sqrt(scale) * weight),
	}
	if extra then
		for k, v in extra :: any do
			(reward :: any)[k] = v
		end
	end
	return reward
end

-- Resource amount appropriate for a zone.
function RewardConfig.resource(zoneId: string, weight: number): { [string]: number }?
	local zone = ZoneConfig.get(zoneId)
	if not zone or not zone.Resource then
		return nil
	end
	return { [zone.Resource] = math.max(1, math.floor(3 * weight)) }
end

return RewardConfig
