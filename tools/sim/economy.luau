--[[
	Economy simulator — `node tools/test/runner.mjs --script tools/sim/economy.luau`

	Plays an idealised "average engaged player" minute by minute using the
	REAL configs and formulas (SizeConfig, ZoneConfig, RewardConfig, quests,
	discoveries, enemies, upgrade pricing, stat math) and prints how long
	each size tier takes. Use it after any balance change: if a tier jumps
	to hours or collapses to seconds, something is off.

	Player model (tunable below):
	  * plays in the highest zone they have unlocked
	  * collects ORBS_PER_MIN growth orbs and defeats KILLS_PER_MIN enemies
	    native to that zone
	  * finds a new discovery every DISCOVERY_EVERY minutes and completes a
	    zone quest every QUEST_EVERY minutes until the zone runs out
	  * spends Growth Energy greedily on the cheapest of Mass Gain / Growth
	    Energy Gain (resource costs are assumed affordable)
	  * no boosts, passes, party or ascension bonuses (the F2P baseline)
]]

local SizeConfig = require(Shared.Config.SizeConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local RewardConfig = require(Shared.Config.RewardConfig)
local CollectibleConfig = require(Shared.Config.CollectibleConfig)
local DiscoveryConfig = require(Shared.Config.DiscoveryConfig)
local QuestConfig = require(Shared.Config.QuestConfig)
local EnemyConfig = require(Shared.Config.EnemyConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Progression = require(Shared.Formulas.Progression)
local Pricing = require(Shared.Formulas.Pricing)
local Stats = require(Shared.Formulas.Stats)
local Format = require(Shared.Util.Format)

local ORBS_PER_MIN = 10
local KILLS_PER_MIN = 3
local DISCOVERY_EVERY = 2
local QUEST_EVERY = 4
local MAX_MINUTES = 60 * 40
local GREEDY = { "MassGain", "GrowthEnergyGain" }

local function zoneScaled(reward: any, zoneId: string): (number, number, number)
	local zone = ZoneConfig.get(zoneId)
	local scale = if zone then zone.RewardScale else 1
	return (reward.Mass or 0) * scale, (reward.GrowthEnergy or 0) * scale, (reward.XP or 0) * math.sqrt(scale)
end

-- One-time content per zone.
local discoveries: { [string]: { any } } = {}
for _, d in DiscoveryConfig.List do
	discoveries[d.Zone] = discoveries[d.Zone] or {}
	table.insert(discoveries[d.Zone], RewardConfig.zone(d.Zone, d.Weight * 1.5))
end
local quests: { [string]: { any } } = {}
for _, q in QuestConfig.List do
	if q.Zone then
		quests[q.Zone] = quests[q.Zone] or {}
		table.insert(quests[q.Zone], q.Rewards)
	end
end
local enemiesByZone: { [string]: { any } } = {}
for _, e in EnemyConfig.List do
	enemiesByZone[e.Zone] = enemiesByZone[e.Zone] or {}
	table.insert(enemiesByZone[e.Zone], e)
end

local orb = CollectibleConfig.get("GrowthOrb") :: any

local mass, energy = 0, 0
local upgrades: { [string]: number } = {}
local usedDiscoveries: { [string]: number } = {}
local usedQuests: { [string]: number } = {}
local reached: { [number]: { Minute: number, Zone: string } } = { [1] = { Minute = 0, Zone = "FloorWorld" } }
local spent = 0

for minute = 1, MAX_MINUTES do
	local tier = Progression.tierForMass(mass)
	local zone = ZoneConfig.highestUnlocked(tier)
	local stats = Stats.compute({ Upgrades = upgrades })
	local massMult = 1 + (stats.MassGain or 0)
	local energyMult = 1 + (stats.GrowthEnergyGain or 0)

	local m, g = 0, 0
	-- Orbs (zone scaled).
	local om, og = zoneScaled(orb.Reward, zone.Id)
	m += om * ORBS_PER_MIN
	g += og * ORBS_PER_MIN
	-- Enemies native to the zone (quests/rewards already zone-relative).
	local list = enemiesByZone[zone.Id]
	if list and #list > 0 then
		local e = list[(minute % #list) + 1]
		local em, eg = zoneScaled(e.Rewards, zone.Id)
		m += em * KILLS_PER_MIN
		g += eg * KILLS_PER_MIN
	end
	-- Discoveries and quests (finite per zone; config rewards are already zone-scaled).
	if minute % DISCOVERY_EVERY == 0 then
		local pool = discoveries[zone.Id] or {}
		local i = (usedDiscoveries[zone.Id] or 0) + 1
		if pool[i] then
			usedDiscoveries[zone.Id] = i
			m += pool[i].Mass or 0
			g += pool[i].GrowthEnergy or 0
		end
	end
	if minute % QUEST_EVERY == 0 then
		local pool = quests[zone.Id] or {}
		local i = (usedQuests[zone.Id] or 0) + 1
		if pool[i] then
			usedQuests[zone.Id] = i
			m += pool[i].Mass or 0
			g += pool[i].GrowthEnergy or 0
		end
	end
	mass += m * massMult
	energy += g * energyMult

	-- Spend greedily.
	while true do
		local bestId, bestCost = nil, math.huge
		for _, id in GREEDY do
			local def = UpgradeConfig.get(id)
			local level = upgrades[id] or 0
			if def and level < def.MaxLevel and (not def.RequiredTier or tier >= def.RequiredTier) then
				local cost = Pricing.upgradeCost(def, level, stats.UpgradeDiscount)
				if cost < bestCost then
					bestId, bestCost = id, cost
				end
			end
		end
		if not bestId or bestCost > energy then
			break
		end
		energy -= bestCost
		spent += bestCost
		upgrades[bestId] = (upgrades[bestId] or 0) + 1
	end

	local newTier = Progression.tierForMass(mass)
	for t = tier + 1, newTier do
		reached[t] = { Minute = minute, Zone = ZoneConfig.highestUnlocked(t - 1).Name }
	end
	if newTier >= #SizeConfig.Tiers then
		break
	end
end

print("")
print("TINY → TITAN economy simulation (F2P baseline)")
print(
	string.format(
		"orbs/min %d · kills/min %d · discovery every %d min · quest every %d min",
		ORBS_PER_MIN,
		KILLS_PER_MIN,
		DISCOVERY_EVERY,
		QUEST_EVERY
	)
)
print("")
print(string.format("%-4s %-16s %-14s %10s %10s", "Tier", "Size", "Earned in", "Reached", "Took"))
local previous = 0
for i, def in SizeConfig.Tiers do
	local r = reached[i]
	if r then
		print(
			string.format(
				"%-4d %-16s %-14s %10s %10s",
				i,
				def.Name,
				r.Zone,
				Format.duration(r.Minute * 60),
				Format.duration((r.Minute - previous) * 60)
			)
		)
		previous = r.Minute
	else
		print(string.format("%-4d %-16s %-14s %10s", i, def.Name, "-", "not reached"))
	end
end
print("")
print(
	string.format(
		"Growth Energy spent on upgrades: %s (Mass Gain Lv %d, Energy Gain Lv %d)",
		Format.abbreviate(spent),
		upgrades.MassGain or 0,
		upgrades.GrowthEnergyGain or 0
	)
)
