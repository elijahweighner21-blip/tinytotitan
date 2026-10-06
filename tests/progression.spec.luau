local SizeConfig = require(Shared.Config.SizeConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Progression = require(Shared.Formulas.Progression)
local ScaleMath = require(Shared.Formulas.ScaleMath)

describe("Size tiers", function()
	it("thresholds and scales strictly increase", function()
		for i = 2, #SizeConfig.Tiers do
			local prev, cur = SizeConfig.Tiers[i - 1], SizeConfig.Tiers[i]
			expect(cur.MassRequired).toBeGreaterThan(prev.MassRequired)
			expect(cur.Scale).toBeGreaterThan(prev.Scale)
			expect(cur.Index).toBe(i)
		end
	end)
	it("tier scales stay within the safe physics range", function()
		for _, tier in SizeConfig.Tiers do
			expect(tier.Scale).toBeAtLeast(GameConfig.MinScale)
			expect(tier.Scale).toBeAtMost(GameConfig.MaxScale)
		end
	end)
	it("maps mass to tiers at exact thresholds", function()
		expect(Progression.tierForMass(0)).toBe(1)
		for i, tier in SizeConfig.Tiers do
			expect(Progression.tierForMass(tier.MassRequired)).toBe(i)
			if i > 1 then
				expect(Progression.tierForMass(tier.MassRequired - 0.01)).toBe(i - 1)
			end
		end
	end)
	it("scale is continuous and monotonic in mass", function()
		local last = 0
		local mass = 0
		while mass < 1e9 do
			local s = Progression.scaleForMass(mass)
			expect(s).toBeFinite()
			expect(s).toBeAtLeast(last - 1e-9)
			last = s
			mass = mass * 1.07 + 1
		end
	end)
	it("tier-up still produces a visible growth spurt", function()
		for i = 2, #SizeConfig.Tiers do
			local req = SizeConfig.Tiers[i].MassRequired
			local before = Progression.scaleForMass(req - 0.001)
			local after = Progression.scaleForMass(req)
			-- Endgame tiers sit near the physics cap, so their spurt is smaller.
			expect(after / before).toBeGreaterThan(if i <= 13 then 1.15 else 1.05)
		end
	end)
	it("never exceeds MaxScale even with absurd mass", function()
		expect(Progression.scaleForMass(1e300)).toBeAtMost(GameConfig.MaxScale)
		expect(Progression.scaleForMass(-50)).toBeAtLeast(GameConfig.MinScale)
	end)
	it("tierProgress fraction is within [0,1]", function()
		for _, m in { 0, 10, 119, 120, 5000, 3e6, 9e9 } do
			local _, f = Progression.tierProgress(m)
			expect(f).toBeAtLeast(0)
			expect(f).toBeAtMost(1)
		end
	end)
end)

describe("Levels", function()
	it("xp curve increases", function()
		for l = 1, 200 do
			expect(Progression.xpToNext(l + 1)).toBeGreaterThan(Progression.xpToNext(l))
		end
	end)
	it("applyXP carries leftover and multiple levels", function()
		local need1 = Progression.xpToNext(1)
		local need2 = Progression.xpToNext(2)
		local level, xp, gained = Progression.applyXP(1, 0, need1 + need2 + 5)
		expect(level).toBe(3)
		expect(xp).toBe(5)
		expect(gained).toBe(2)
	end)
	it("ignores negative xp", function()
		local level, xp = Progression.applyXP(5, 10, -1000)
		expect(level).toBe(5)
		expect(xp).toBe(10)
	end)
	it("caps at max level", function()
		local level, xp = Progression.applyXP(1, 0, 1e15)
		expect(level).toBe(GameConfig.MaxLevel)
		expect(xp).toBe(0)
	end)
end)

describe("ScaleMath", function()
	it("tiny players are more nimble per body length than titans", function()
		local tiny = ScaleMath.walkSpeed(0.2) / ScaleMath.height(0.2)
		local titan = ScaleMath.walkSpeed(340) / ScaleMath.height(340)
		expect(tiny).toBeGreaterThan(titan * 3)
	end)
	it("air time stays in a comfortable range at every size", function()
		for _, s in { 0.2, 0.5, 1, 4, 16, 60, 120, 340, 400 } do
			local t = ScaleMath.airTime(s)
			expect(t).toBeGreaterThan(0.3)
			expect(t).toBeLessThan(3.5)
		end
	end)
	it("jump velocity grows with scale", function()
		expect(ScaleMath.jumpVelocity(16)).toBeGreaterThan(ScaleMath.jumpVelocity(1))
	end)
	it("clamps out-of-range scales", function()
		expect(ScaleMath.height(0)).toBe(ScaleMath.height(GameConfig.MinScale))
		expect(ScaleMath.height(1e9)).toBe(ScaleMath.height(GameConfig.MaxScale))
	end)
end)
