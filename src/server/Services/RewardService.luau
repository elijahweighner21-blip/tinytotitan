--!strict
--[[
	RewardService
	THE centralised reward pipeline. Every gameplay reward in the game (quests,
	challenges, collectibles, bosses, events, daily objectives, purchases)
	goes through :Grant so multipliers are applied exactly once, consistently,
	and auditably.

	Modifier sources gathered per grant (see Config/RewardConfig for rules):
	  Additive        stat bonuses (MassGain, GrowthEnergyGain, XPGain, ResourceGain)
	                  category bonuses (QuestRewards, ChallengeRewards, Discovery MapReveal)
	                  VIP perks, party bonus, server events (GlobalModifierService)
	  Multiplicative  timed boosts (group "Boost"), 2× Growth Energy pass (group "Pass")

	Context.Source in RewardConfig.NoMultiplierSources (Purchase, Admin, ...)
	skips multipliers entirely — Robux rewards are exactly what was bought.
	Titan Shards never receive boosts; only the ShardGain stat (ascension
	tree) applies to gameplay shard rewards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local RewardConfig = require(Shared.Config.RewardConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local RewardMath = require(Shared.Formulas.RewardMath)
local MathUtil = require(Shared.Util.MathUtil)
local Log = require(Shared.Util.Log)
local Signal = require(Shared.Util.Signal)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local ProgressionService = require(script.Parent.ProgressionService)
local StatService = require(script.Parent.StatService)
local BoostService = require(script.Parent.BoostService)
local EntitlementService = require(script.Parent.EntitlementService)
local GlobalModifierService = require(script.Parent.GlobalModifierService)
local PartyService = require(script.Parent.PartyService)
local InventoryService = require(script.Parent.InventoryService)
local StatisticsService = require(script.Parent.StatisticsService)

type Reward = Types.Reward

export type Context = {
	Source: string, -- "Quest", "Challenge", "Collectible", "Boss", "Purchase", ...
	SourceId: string?,
	Category: string?, -- "Quest" | "Challenge" | "Discovery" for category bonuses
	Multipliers: boolean?, -- default true unless Source is exempt
	Notify: boolean?, -- default true: show reward popup
	Position: Vector3?, -- world position for floating reward text
	Jackpot: boolean?, -- allow the BonusRewardChance double (default true)
}

export type Granted = {
	Mass: number,
	XP: number,
	GrowthEnergy: number,
	TitanShards: number,
	SkillPoints: number,
	ExplorationTokens: number,
	AscensionPoints: number,
	Resources: { [string]: number },
	Items: { [string]: number },
	Cosmetics: { string },
	Titles: { string },
	Boosts: { [string]: number },
	Jackpot: boolean,
	Breakdown: { RewardMath.Breakdown },
}

local RewardService = {}

-- (player, granted, context)
RewardService.Granted = Signal.new() :: Signal.Signal<Player, Granted, Context>

local rng = Random.new()

function RewardService:GetModifiers(player: Player, context: Context?): { RewardMath.Modifier }
	local mods: { RewardMath.Modifier } = {}
	local stats = StatService:GetStats(player)

	local function add(source: string, currency: string, value: number)
		if value > 0 then
			table.insert(mods, { Source = source, Currency = currency, Kind = "Additive", Value = value })
		end
	end

	add("Stat:MassGain", "Mass", stats.MassGain)
	add("Stat:EnergyGain", "GrowthEnergy", stats.GrowthEnergyGain)
	add("Stat:XPGain", "XP", stats.XPGain)
	add("Stat:ResourceGain", "Resources", stats.ResourceGain)

	local category = context and context.Category
	if category == "Quest" then
		for _, c in { "Mass", "GrowthEnergy", "XP" } do
			add("Stat:QuestRewards", c, stats.QuestRewards)
		end
	elseif category == "Challenge" then
		for _, c in { "Mass", "GrowthEnergy", "XP" } do
			add("Stat:ChallengeRewards", c, stats.ChallengeRewards)
		end
	elseif category == "Discovery" then
		for _, c in { "Mass", "GrowthEnergy", "XP" } do
			add("Stat:MapReveal", c, stats.MapReveal)
		end
	end

	if EntitlementService:Owns(player, "VIP") then
		add("VIP", "GrowthEnergy", MonetizationConfig.VIPPerks.GrowthEnergyBonus)
		add("VIP", "XP", MonetizationConfig.VIPPerks.XPBonus)
	end
	if EntitlementService:Owns(player, "DoubleGrowthEnergy") then
		table.insert(mods, {
			Source = "Pass:2xGrowthEnergy",
			Currency = "GrowthEnergy",
			Kind = "Multiplicative",
			Value = 2,
			Group = RewardConfig.Groups.Pass,
		})
	end

	local party = PartyService:GetBonus(player)
	if party > 0 then
		for _, c in { "Mass", "GrowthEnergy", "XP" } do
			add("Party", c, party)
		end
	end

	for _, mod in BoostService:GetModifiers(player) do
		table.insert(mods, mod)
	end
	for _, mod in GlobalModifierService:GetModifiers() do
		table.insert(mods, mod)
	end
	return mods
end

local function emptyGranted(): Granted
	return {
		Mass = 0,
		XP = 0,
		GrowthEnergy = 0,
		TitanShards = 0,
		SkillPoints = 0,
		ExplorationTokens = 0,
		AscensionPoints = 0,
		Resources = {},
		Items = {},
		Cosmetics = {},
		Titles = {},
		Boosts = {},
		Jackpot = false,
		Breakdown = {},
	}
end

local function positive(n: any): number
	if MathUtil.isFinite(n) and n > 0 then
		return n
	end
	return 0
end

function RewardService:Grant(player: Player, reward: Reward, context: Context): Granted
	local granted = emptyGranted()
	if not PlayerDataService:IsLoaded(player) then
		Log.warn("Reward", "grant before data loaded", player.UserId, context.Source)
		return granted
	end
	local enabled = context.Multipliers ~= false and not RewardConfig.NoMultiplierSources[context.Source]
	local mods = if enabled then RewardService:GetModifiers(player, context) else {}
	local stats = StatService:GetStats(player)

	-- Jackpot: a chance to double the whole (base) reward. Gameplay only.
	local base = 1
	if
		enabled
		and context.Jackpot ~= false
		and stats.BonusRewardChance > 0
		and rng:NextNumber() < stats.BonusRewardChance
	then
		base = 2
		granted.Jackpot = true
	end

	local function scaled(currency: string, amount: any): number
		local value = positive(amount) * base
		if value <= 0 then
			return 0
		end
		local b = RewardMath.apply(currency, value, mods, enabled)
		table.insert(granted.Breakdown, b)
		return b.Final
	end

	-- Mass / XP drive progression and must go through ProgressionService.
	local mass = scaled("Mass", reward.Mass)
	if mass > 0 and ProgressionService:AddMass(player, mass, context.Source) then
		granted.Mass = mass
	end
	local xp = scaled("XP", reward.XP)
	if xp > 0 then
		ProgressionService:AddXP(player, xp, context.Source)
		granted.XP = xp
	end
	local energy = scaled("GrowthEnergy", reward.GrowthEnergy)
	if energy > 0 and CurrencyService:Add(player, "GrowthEnergy", energy, context.Source) then
		granted.GrowthEnergy = energy
	end

	local shards = positive(reward.TitanShards) * base
	if shards > 0 then
		if enabled then
			shards = math.floor(shards * (1 + stats.ShardGain))
		end
		if CurrencyService:Add(player, "TitanShards", shards, context.Source) then
			granted.TitanShards = shards
			if context.Source ~= "Purchase" then
				StatisticsService:Increment(player, "TitanShardsEarned", shards)
			end
		end
	end

	for _, key in { "SkillPoints", "ExplorationTokens", "AscensionPoints" } do
		local amount = math.floor(positive((reward :: any)[key]))
		if amount > 0 and CurrencyService:Add(player, key, amount, context.Source) then
			(granted :: any)[key] = amount
		end
	end

	if reward.Resources then
		for resource, amount in reward.Resources do
			local value = scaled("Resources", amount)
			if
				value > 0
				and enabled
				and stats.RareResourceChance > 0
				and rng:NextNumber() < stats.RareResourceChance
			then
				value *= 2
			end
			value = math.floor(value)
			if value > 0 and CurrencyService:AddResource(player, resource, value, context.Source) then
				granted.Resources[resource] = value
				GameEvents.fire("ResourceGathered", player, resource, value)
			end
		end
	end
	if reward.Items then
		for item, amount in reward.Items do
			if InventoryService:AddItem(player, item, math.floor(positive(amount))) then
				granted.Items[item] = amount
			end
		end
	end
	if reward.Cosmetics then
		for _, id in reward.Cosmetics do
			if InventoryService:GrantCosmetic(player, id) then
				table.insert(granted.Cosmetics, id)
			end
		end
	end
	if reward.Titles then
		for _, id in reward.Titles do
			if InventoryService:GrantTitle(player, id) then
				table.insert(granted.Titles, id)
			end
		end
	end
	if reward.Boosts then
		for boostId, seconds in reward.Boosts do
			if BoostService:Add(player, boostId, positive(seconds)) then
				granted.Boosts[boostId] = seconds
			end
		end
	end

	if context.Notify ~= false then
		Net.signal(player, "Reward", {
			Source = context.Source,
			SourceId = context.SourceId,
			Position = context.Position,
			Mass = granted.Mass,
			XP = granted.XP,
			GrowthEnergy = granted.GrowthEnergy,
			TitanShards = granted.TitanShards,
			SkillPoints = granted.SkillPoints,
			ExplorationTokens = granted.ExplorationTokens,
			Resources = granted.Resources,
			Items = granted.Items,
			Cosmetics = granted.Cosmetics,
			Titles = granted.Titles,
			Boosts = granted.Boosts,
			Jackpot = granted.Jackpot,
		})
	end
	if Log.isDebug() and #granted.Breakdown > 0 then
		for _, b in granted.Breakdown do
			Log.debug(
				"Reward",
				string.format(
					"%s %s: %g -> %g (+%d%% ×%g) %s",
					context.Source,
					b.Currency,
					b.Base,
					b.Final,
					math.floor(b.Additive * 100),
					b.Multiplier,
					table.concat(b.Sources, ", ")
				)
			)
		end
	end
	RewardService.Granted:Fire(player, granted, context)
	return granted
end

-- Zone scaling: Mass and Growth Energy scale with the zone's RewardScale,
-- XP with its square root (keeps levelling pace sane late game). Titan
-- Shards, resources, items and cosmetics are NEVER zone-scaled.
function RewardService:ScaleZone(reward: Reward, zoneId: string, extraFactor: number?): Reward
	local zone = ZoneConfig.get(zoneId)
	local scale = if zone then zone.RewardScale else 1
	local extra = extraFactor or 1
	local out: { [string]: any } = table.clone(reward :: any)
	if reward.Mass then
		out.Mass = math.floor(reward.Mass * scale * extra)
	end
	if reward.GrowthEnergy then
		out.GrowthEnergy = math.floor(reward.GrowthEnergy * scale * extra)
	end
	if reward.XP then
		out.XP = math.floor(reward.XP * math.sqrt(scale) * extra)
	end
	return out :: any
end

-- Multiplies every numeric field of a reward (fractions such as repeat-kill
-- rewards). Use ScaleZone for zone scaling.
function RewardService:Scale(reward: Reward, factor: number): Reward
	local out: { [string]: any } = {}
	for key, value in reward :: any do
		if type(value) == "number" then
			out[key] = math.floor(value * factor)
		elseif key == "Resources" and type(value) == "table" then
			local res = {}
			for r, n in value do
				res[r] = math.max(1, math.floor(n * factor))
			end
			out[key] = res
		else
			out[key] = value
		end
	end
	return out :: any
end

return RewardService
