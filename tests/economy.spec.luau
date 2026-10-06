local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Pricing = require(Shared.Formulas.Pricing)
local RewardMath = require(Shared.Formulas.RewardMath)
local RewardConfig = require(Shared.Config.RewardConfig)
local CombatMath = require(Shared.Formulas.CombatMath)
local AscensionConfig = require(Shared.Config.AscensionConfig)
local Stats = require(Shared.Formulas.Stats)

describe("Upgrade pricing", function()
	it("costs are positive, finite and non-decreasing", function()
		for _, def in UpgradeConfig.List do
			local last = 0
			for level = 0, def.MaxLevel - 1 do
				local cost = Pricing.upgradeCost(def, level)
				expect(cost).toBeFinite()
				expect(cost).toBeGreaterThan(0)
				expect(cost).toBeAtLeast(last)
				last = cost
			end
			expect(Pricing.upgradeCost(def, def.MaxLevel)).toBe(math.huge)
		end
	end)
	it("discount reduces cost but is capped", function()
		local def = UpgradeConfig.get("WalkSpeed")
		expect(Pricing.upgradeCost(def, 5, 0.2)).toBeLessThan(Pricing.upgradeCost(def, 5))
		expect(Pricing.upgradeCost(def, 5, 5)).toBe(Pricing.upgradeCost(def, 5, 0.6))
	end)
	it("resource costs only apply on the configured cadence", function()
		local def = UpgradeConfig.get("MassGain")
		local r, n = Pricing.resourceCost(def, 0)
		expect(r).toBe(nil)
		r, n = Pricing.resourceCost(def, 9)
		expect(r).toBe("SugarCrystals")
		expect(n).toBe(10)
	end)
	it("max-level upgrades never exceed a sane total", function()
		for _, def in UpgradeConfig.List do
			expect(Pricing.totalCost(def, 0, def.MaxLevel)).toBeLessThan(1e12)
		end
	end)
end)

describe("Reward stacking", function()
	local mods = {
		{ Source = "Event", Currency = "Mass", Kind = "Additive", Value = 0.25 },
		{ Source = "VIP", Currency = "Mass", Kind = "Additive", Value = 0.10 },
		{ Source = "Boost:Mass2x", Currency = "Mass", Kind = "Multiplicative", Value = 2, Group = "Boost" },
	}
	it("matches the documented example (100 base -> 270)", function()
		local b = RewardMath.apply("Mass", 100, mods, true)
		expect(b.Final).toBe(270)
	end)
	it("two boosts in the same group do not stack", function()
		local m = table.clone(mods)
		table.insert(m, { Source = "Boost:Mass2x#2", Currency = "Mass", Kind = "Multiplicative", Value = 2, Group = "Boost" })
		expect(RewardMath.apply("Mass", 100, m, true).Final).toBe(270)
	end)
	it("does not apply to other currencies", function()
		expect(RewardMath.apply("GrowthEnergy", 100, mods, true).Final).toBe(100)
	end)
	it("titan shards are never multiplied", function()
		local m = { { Source = "X", Currency = "*", Kind = "Multiplicative", Value = 5, Group = "Boost" } }
		expect(RewardMath.apply("TitanShards", 10, m, true).Final).toBe(10)
	end)
	it("caps additive and total multipliers", function()
		local m = {}
		for i = 1, 50 do
			table.insert(m, { Source = "A" .. i, Currency = "Mass", Kind = "Additive", Value = 1 })
			table.insert(m, { Source = "M" .. i, Currency = "Mass", Kind = "Multiplicative", Value = 3, Group = "G" .. i })
		end
		local b = RewardMath.apply("Mass", 100, m, true)
		expect(b.Final).toBe(100 * RewardConfig.MaxTotalMultiplier)
	end)
	it("rejects NaN / negative / infinite input", function()
		expect(RewardMath.apply("Mass", 0 / 0, mods, true).Final).toBe(0)
		expect(RewardMath.apply("Mass", -5, mods, true).Final).toBe(0)
		expect(RewardMath.apply("Mass", math.huge, mods, true).Final).toBe(0)
		local bad = { { Source = "NaN", Currency = "Mass", Kind = "Additive", Value = 0 / 0 } }
		expect(RewardMath.apply("Mass", 100, bad, true).Final).toBe(100)
	end)
	it("disabled multipliers return base", function()
		expect(RewardMath.apply("Mass", 100, mods, false).Final).toBe(100)
	end)
end)

describe("Combat", function()
	it("bigger attackers deal more damage", function()
		local small = CombatMath.playerDamage("Light", 1, 1, 0, false)
		local big = CombatMath.playerDamage("Light", 10, 1, 0, false)
		expect(big).toBeGreaterThan(small)
	end)
	it("enemy damage is capped per hit", function()
		expect(CombatMath.enemyDamage(1e9, 100, 0.2, 0)).toBeAtMost(60)
	end)
	it("defense reduces damage", function()
		expect(CombatMath.enemyDamage(10, 1, 1, 0.5)).toBeLessThan(CombatMath.enemyDamage(10, 1, 1, 0))
	end)
	it("unknown attack deals nothing", function()
		expect(CombatMath.playerDamage("Nope", 1, 1, 0, false)).toBe(0)
	end)
	it("titans get almost nothing from farming ants", function()
		expect(CombatMath.rewardFactor(300, 0.3)).toBeLessThan(0.05)
		expect(CombatMath.rewardFactor(1, 1)).toBe(1)
	end)
	it("arc check works", function()
		local o = Vector3.new(0, 0, 0)
		local f = Vector3.new(0, 0, -1)
		expect(CombatMath.inArc(o, f, Vector3.new(0, 0, -3), 5, 90)).toBeTruthy()
		expect(CombatMath.inArc(o, f, Vector3.new(0, 0, 3), 5, 90)).toBeFalsy()
		expect(CombatMath.inArc(o, f, Vector3.new(0, 0, -9), 5, 360)).toBeFalsy()
	end)
end)

describe("Ascension", function()
	it("no points below the required tier", function()
		expect(AscensionConfig.pointsFor(11, 1e9)).toBe(0)
	end)
	it("points increase with tier and mass", function()
		local a = AscensionConfig.pointsFor(12, 2.2e6)
		local b = AscensionConfig.pointsFor(13, 2.2e6)
		local c = AscensionConfig.pointsFor(12, 2.2e8)
		expect(b).toBeGreaterThan(a)
		expect(c).toBeGreaterThan(a)
		expect(AscensionConfig.pointsFor(15, 1e15)).toBeFinite()
	end)
	it("tree requirements reference real nodes", function()
		for _, node in AscensionConfig.Tree do
			for _, req in node.Requires do
				expect(AscensionConfig.getNode(req) ~= nil).toBeTruthy()
			end
		end
	end)
end)

describe("Stats", function()
	it("caps dangerous stats", function()
		local stats = Stats.compute({ Upgrades = { AbilityCooldowns = 999 } })
		expect(stats.CooldownReduction).toBeAtMost(0.6)
	end)
	it("ignores unknown or invalid entries", function()
		local stats = Stats.compute({ Upgrades = { Fake = 10, WalkSpeed = "x" }, Skills = { Nope = true } })
		expect(stats.WalkSpeed).toBe(0)
	end)
	it("derived values are finite for every tier", function()
		local SizeConfig = require(Shared.Config.SizeConfig)
		for _, tier in SizeConfig.Tiers do
			local d = Stats.derive(Stats.empty(), tier.Scale)
			for k, v in d do
				expect(v).toBeFinite()
			end
		end
	end)
end)
