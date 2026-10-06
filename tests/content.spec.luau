-- Cross-config integrity: every reference between content tables must resolve.
local QuestConfig = require(Shared.Config.QuestConfig)
local SkillConfig = require(Shared.Config.SkillConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)
local BossConfig = require(Shared.Config.BossConfig)
local EnemyConfig = require(Shared.Config.EnemyConfig)
local DiscoveryConfig = require(Shared.Config.DiscoveryConfig)
local NPCConfig = require(Shared.Config.NPCConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local TitleConfig = require(Shared.Config.TitleConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local AchievementConfig = require(Shared.Config.AchievementConfig)
local ChallengeConfig = require(Shared.Config.ChallengeConfig)
local LoreConfig = require(Shared.Config.LoreConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local LevelConfig = require(Shared.Config.LevelConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local DailyConfig = require(Shared.Config.DailyConfig)
local CollectibleConfig = require(Shared.Config.CollectibleConfig)
local ShopRotation = require(Shared.Formulas.ShopRotation)
local SizeConfig = require(Shared.Config.SizeConfig)

local function checkReward(where, reward)
	if not reward then return end
	for _, t in reward.Titles or {} do
		if not TitleConfig.get(t) then error(where .. ": unknown title " .. t) end
	end
	for _, c in reward.Cosmetics or {} do
		if not CosmeticConfig.get(c) then error(where .. ": unknown cosmetic " .. c) end
	end
	for b in reward.Boosts or {} do
		if not MonetizationConfig.Boosts[b] then error(where .. ": unknown boost " .. b) end
	end
	for k, v in reward do
		if type(v) == "number" and (v ~= v or v < 0) then error(where .. ": bad amount " .. k) end
	end
end

local validTargets = {
	Collect = function(t) return t == "Any" or CollectibleConfig.get(t) ~= nil end,
	Discover = function(t) return t == "Any" or DiscoveryConfig.get(t) ~= nil end,
	DefeatEnemy = function(t) return t == "Any" or EnemyConfig.get(t) ~= nil end,
	DefeatBoss = function(t) return BossConfig.get(t) ~= nil end,
	CompleteChallenge = function(t) return t == "Any" or ChallengeConfig.get(t) ~= nil end,
	TalkTo = function(t) return NPCConfig.get(t) ~= nil end,
	BuyUpgrade = function(t) return t == "Any" or UpgradeConfig.get(t) ~= nil end,
	UnlockSkill = function(t) return t == "Any" or SkillConfig.get(t) ~= nil end,
	UseAbility = function(t) return AbilityConfig.get(t) ~= nil end,
	BreakObject = function() return true end,
	MoveObject = function(t) return t == "Push" or t == "Carry" or t == "Throw" end,
	EnterZone = function(t) return ZoneConfig.get(t) ~= nil end,
	GatherResource = function(t) return t ~= nil end,
	ReachTier = function() return true end,
	ReachLevel = function() return true end,
	EarnMass = function() return true end,
	JoinEvent = function() return true end,
	FastTravel = function() return true end,
	Ascend = function() return true end,
}

describe("Quests", function()
	it("every objective type and target is valid", function()
		for _, q in QuestConfig.List do
			for _, o in q.Objectives do
				local check = validTargets[o.Type]
				if not check then error(q.Id .. ": unknown objective type " .. o.Type) end
				if not check(o.Target) then error(q.Id .. ": bad target " .. tostring(o.Target)) end
				if o.Count < 1 then error(q.Id .. ": count < 1") end
			end
			checkReward(q.Id, q.Rewards)
		end
	end)
	it("prerequisites, next quests, givers and zones exist", function()
		for _, q in QuestConfig.List do
			for _, p in q.Prerequisites or {} do
				if not QuestConfig.get(p) then error(q.Id .. ": missing prereq " .. p) end
			end
			if q.NextQuest and not QuestConfig.get(q.NextQuest) then error(q.Id .. ": bad next") end
			if q.Giver and not NPCConfig.get(q.Giver) then error(q.Id .. ": bad giver") end
			if q.Zone and not ZoneConfig.get(q.Zone) then error(q.Id .. ": bad zone") end
		end
	end)
	it("the prerequisite graph has no cycles", function()
		local state = {}
		local function visit(id)
			if state[id] == 1 then error("cycle at " .. id) end
			if state[id] == 2 then return end
			state[id] = 1
			for _, p in QuestConfig.get(id).Prerequisites or {} do visit(p) end
			state[id] = 2
		end
		for _, q in QuestConfig.List do visit(q.Id) end
	end)
	it("NPC featured quests exist", function()
		for _, npc in NPCConfig.List do
			for _, id in npc.Quests do
				if not QuestConfig.get(id) then error(npc.Id .. ": unknown quest " .. id) end
			end
			if not ZoneConfig.get(npc.Zone) then error(npc.Id .. ": bad zone") end
		end
	end)
end)

describe("Skills & abilities", function()
	it("skill prerequisites exist and abilities match", function()
		for _, s in SkillConfig.List do
			for _, p in s.Prerequisites do
				if not SkillConfig.get(p) then error(s.Id .. ": bad prereq " .. p) end
			end
			if s.Grants.Ability then
				local a = AbilityConfig.get(s.Grants.Ability)
				if not a then error(s.Id .. ": unknown ability") end
				if a.RequiresSkill ~= s.Id then error(s.Id .. ": ability requires " .. tostring(a.RequiresSkill)) end
			end
			if s.Requirements.Boss and not BossConfig.get(s.Requirements.Boss) then error(s.Id .. ": bad boss") end
		end
	end)
	it("every ability that needs a skill is grantable", function()
		for _, a in AbilityConfig.List do
			if a.RequiresSkill and not SkillConfig.get(a.RequiresSkill) then
				error(a.Id .. ": requires missing skill " .. a.RequiresSkill)
			end
		end
	end)
end)

describe("Bosses, enemies, challenges", function()
	it("boss references resolve", function()
		for _, b in BossConfig.List do
			if not ZoneConfig.get(b.Zone) then error(b.Id .. ": zone") end
			checkReward(b.Id, b.Rewards)
			checkReward(b.Id, b.FirstKillRewards)
			local last = 2
			for _, phase in b.Phases do
				if phase.HealthBelow >= last then error(b.Id .. ": phases must descend") end
				last = phase.HealthBelow
				for _, atk in phase.Attacks do
					if atk.Kind == "Summon" and not EnemyConfig.get(atk.Minion) then error(b.Id .. ": minion") end
				end
			end
		end
	end)
	it("enemy zones exist", function()
		for _, e in EnemyConfig.List do
			if not ZoneConfig.get(e.Zone) then error(e.Id .. ": zone") end
		end
	end)
	it("challenge medals are ordered and feasible", function()
		for _, c in ChallengeConfig.List do
			local t = c.Thresholds
			if c.LowerIsBetter then
				if not (t.Titan < t.Gold and t.Gold < t.Silver and t.Silver < t.Bronze and t.Bronze < c.TimeLimit) then
					error(c.Id .. ": time medal order")
				end
				if c.MinPlausibleTime >= t.Titan then error(c.Id .. ": plausibility above titan") end
			else
				if not (t.Titan > t.Gold and t.Gold > t.Silver and t.Silver > t.Bronze) then error(c.Id .. ": score order") end
			end
			if not ZoneConfig.get(c.Zone) then error(c.Id .. ": zone") end
			local zone = ZoneConfig.get(c.Zone)
			if c.RequiredTier < zone.RequiredTier then error(c.Id .. ": below zone requirement") end
			for _, r in c.Rewards do checkReward(c.Id, r) end
		end
	end)
	it("medalFor works both directions", function()
		local timed = ChallengeConfig.get("CrumbSprint")
		expect(ChallengeConfig.medalFor(timed, timed.Thresholds.Titan - 0.01)).toBe(4)
		expect(ChallengeConfig.medalFor(timed, timed.Thresholds.Bronze + 1)).toBe(0)
		local scored = ChallengeConfig.get("CoinRush")
		expect(ChallengeConfig.medalFor(scored, 100)).toBe(4)
		expect(ChallengeConfig.medalFor(scored, 0)).toBe(0)
	end)
end)

describe("Rewards & cosmetics", function()
	it("achievements, levels and products reference real items", function()
		for _, a in AchievementConfig.List do checkReward(a.Id, a.Rewards) end
		for _, m in LevelConfig.Milestones do checkReward("Level" .. m.Level, m.Reward) end
		for key, p in MonetizationConfig.DeveloperProducts do
			expect(p.Key).toBe(key)
			checkReward(key, p.Contents)
			if p.DuplicateCompensation then checkReward(key, p.DuplicateCompensation) end
		end
		for key, p in MonetizationConfig.GamePasses do
			expect(p.Key).toBe(key)
			checkReward(key, p.Grants)
		end
	end)
	it("featured keys exist", function()
		for _, key in MonetizationConfig.Featured do
			expect(MonetizationConfig.getPass(key) ~= nil or MonetizationConfig.getProduct(key) ~= nil).toBeTruthy()
		end
	end)
	it("cosmetic categories exist and prices are positive", function()
		for _, c in CosmeticConfig.List do
			if not CosmeticConfig.getCategory(c.Category) then error(c.Id .. ": category") end
			if c.Price then expect(c.Price.Amount).toBeGreaterThan(0) end
			if c.Limited then expect(c.Limited.End).toBeGreaterThan(c.Limited.Start) end
		end
	end)
	it("discovery lore entries exist", function()
		for _, d in DiscoveryConfig.List do
			if d.Lore and not LoreConfig.get(d.Lore) then error(d.Id .. ": lore " .. d.Lore) end
			if not ZoneConfig.get(d.Zone) then error(d.Id .. ": zone") end
		end
	end)
	it("daily shop rotation is deterministic and limited items expire", function()
		local a = ShopRotation.daily(20000)
		local b = ShopRotation.daily(20000)
		expect(#a).toBeGreaterThan(0)
		for i = 1, #a do expect(a[i]).toBe(b[i]) end
		expect(ShopRotation.isPurchasable("PumpkinTrail", 0, 1790812800 + 10)).toBeTruthy()
		expect(ShopRotation.isPurchasable("PumpkinTrail", 0, 1794009600 + 10)).toBeFalsy()
		expect(ShopRotation.isPurchasable("VIPAura", 0, 1790812800)).toBeFalsy()
	end)
end)

describe("Daily streak", function()
	it("is forgiving", function()
		expect(DailyConfig.nextStreak(0, 0, 100)).toBe(1)
		expect(DailyConfig.nextStreak(4, 99, 100)).toBe(5)
		expect(DailyConfig.nextStreak(4, 98, 100)).toBe(5) -- one missed day is forgiven
		expect(DailyConfig.nextStreak(6, 95, 100)).toBe(2) -- missed 4 days: lose 4
		expect(DailyConfig.nextStreak(5, 100, 100)).toBe(5) -- same day: unchanged
		expect(DailyConfig.nextStreak(2, 50, 100)).toBe(1)
	end)
end)

describe("Zones", function()
	it("each zone's spawn lies inside its own bounds", function()
		for _, z in ZoneConfig.Zones do
			if not ZoneConfig.contains(z, z.Spawn) then error(z.Id .. ": spawn outside") end
			if ZoneConfig.zoneAt(z.Spawn).Id ~= z.Id then error(z.Id .. ": spawn resolves to " .. ZoneConfig.zoneAt(z.Spawn).Id) end
		end
	end)
	it("zone requirements are reachable tiers", function()
		for _, z in ZoneConfig.Zones do
			expect(z.RequiredTier).toBeAtMost(SizeConfig.MaxTier)
		end
	end)
end)
