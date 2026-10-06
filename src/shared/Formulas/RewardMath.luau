--!strict
--[[
	RewardMath
	The single audit-able multiplier pipeline. RewardService feeds it the list
	of active modifiers for a player and gets back the final amounts plus a
	breakdown that can be logged or shown in the debug panel.
]]

local RewardConfig = require(script.Parent.Parent.Config.RewardConfig)
local MathUtil = require(script.Parent.Parent.Util.MathUtil)

export type Modifier = {
	Source: string, -- "VIP", "Event:GrowthSurge", "Boost:Mass2x", ...
	Currency: string, -- "Mass", "XP", "GrowthEnergy", "Resources", or "*"
	Kind: "Additive" | "Multiplicative",
	Value: number, -- additive: +0.25 = +25%; multiplicative: 2 = ×2
	Group: string?, -- multiplicative group; strongest per group wins
}

export type Breakdown = {
	Currency: string,
	Base: number,
	Additive: number,
	Multiplier: number,
	Final: number,
	Sources: { string },
}

local RewardMath = {}

-- Returns the effective total multiplier for a currency and the sources used.
function RewardMath.multiplierFor(currency: string, modifiers: { Modifier }): (number, number, number, { string })
	local additive = 0
	local groups: { [string]: { value: number, source: string } } = {}
	local sources = {}
	for _, mod in modifiers do
		if mod.Currency ~= currency and mod.Currency ~= "*" then
			continue
		end
		if not MathUtil.isFinite(mod.Value) then
			continue
		end
		if mod.Kind == "Additive" then
			if mod.Value > 0 then
				additive += mod.Value
				table.insert(sources, string.format("%s +%d%%", mod.Source, math.floor(mod.Value * 100 + 0.5)))
			end
		else
			local group = mod.Group or mod.Source
			local existing = groups[group]
			if mod.Value > 1 and (not existing or mod.Value > existing.value) then
				groups[group] = { value = mod.Value, source = mod.Source }
			end
		end
	end
	additive = math.min(additive, RewardConfig.MaxAdditive)
	local mult = 1
	for _, entry in groups do
		mult *= entry.value
		table.insert(sources, string.format("%s ×%g", entry.source, entry.value))
	end
	local total = math.min((1 + additive) * mult, RewardConfig.MaxTotalMultiplier)
	return total, additive, mult, sources
end

function RewardMath.apply(currency: string, base: number, modifiers: { Modifier }, enabled: boolean): Breakdown
	if not MathUtil.isFinite(base) or base <= 0 then
		return { Currency = currency, Base = 0, Additive = 0, Multiplier = 1, Final = 0, Sources = {} }
	end
	if not enabled or not RewardConfig.Multipliable[currency] then
		return {
			Currency = currency,
			Base = base,
			Additive = 0,
			Multiplier = 1,
			Final = math.floor(base),
			Sources = {},
		}
	end
	local total, additive, mult, sources = RewardMath.multiplierFor(currency, modifiers)
	return {
		Currency = currency,
		Base = base,
		Additive = additive,
		Multiplier = mult,
		Final = math.floor(base * total),
		Sources = sources,
	}
end

return RewardMath
