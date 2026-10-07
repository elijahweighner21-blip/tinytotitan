local QuestLogic = require(Server.Logic.QuestLogic)
local AscensionLogic = require(Server.Logic.AscensionLogic)
local DailyLogic = require(Server.Logic.DailyLogic)
local SessionLock = require(Server.Logic.SessionLock)
local ReceiptLedger = require(Server.Logic.ReceiptLedger)
local DataSchema = require(Shared.Data.DataSchema)
local DailyConfig = require(Shared.Config.DailyConfig)
local AscensionConfig = require(Shared.Config.AscensionConfig)

local function ctx(tier, level, discoveries, zone)
	return { Tier = tier or 1, Level = level or 1, Discoveries = discoveries or {}, Zone = zone }
end

describe("QuestLogic", function()
	it("respects prerequisites and requirements", function()
		local q = { Active = {}, Completed = {}, Tracked = "" }
		expect((QuestLogic.isAvailable("FirstSteps", q, ctx()))).toBeTruthy()
		expect((QuestLogic.isAvailable("OrbHunter", q, ctx()))).toBeFalsy()
		q.Completed.FirstSteps = 1
		expect((QuestLogic.isAvailable("OrbHunter", q, ctx()))).toBeTruthy()
		q.Completed.AntProblem = 1
		q.Completed.OrbHunter = 1
		expect((QuestLogic.isAvailable("QueenOfTheFloor", q, ctx(2)))).toBeFalsy()
		expect((QuestLogic.isAvailable("QueenOfTheFloor", q, ctx(3)))).toBeTruthy()
	end)
	it("never re-offers completed or active quests", function()
		local q = { Active = { FirstSteps = { Progress = {}, StartedAt = 0 } }, Completed = {}, Tracked = "" }
		expect((QuestLogic.isAvailable("FirstSteps", q, ctx()))).toBeFalsy()
		q.Active = {}
		q.Completed.FirstSteps = 5
		expect((QuestLogic.isAvailable("FirstSteps", q, ctx()))).toBeFalsy()
	end)
	it("matches events to objectives and caps progress", function()
		local active = QuestLogic.newProgress("OrbHunter", ctx(), 0)
		for _ = 1, 20 do
			QuestLogic.applyEvent("OrbHunter", active, "Collected", "GrowthOrb", "id", "FloorWorld")
		end
		expect(active.Progress[1]).toBe(12)
		expect(QuestLogic.isComplete("OrbHunter", active)).toBeFalsy()
		QuestLogic.applyState("OrbHunter", active, ctx(2))
		expect(QuestLogic.isComplete("OrbHunter", active)).toBeTruthy()
	end)
	it("ignores wrong targets and junk amounts", function()
		local active = QuestLogic.newProgress("AntProblem", ctx(), 0)
		expect(QuestLogic.applyEvent("AntProblem", active, "EnemyDefeated", "Beetle")).toBeFalsy()
		expect(QuestLogic.applyEvent("AntProblem", active, "EnemyDefeated", "Ant")).toBeTruthy()
		expect(
			QuestLogic.applyEvent(
				"LabWork",
				QuestLogic.newProgress("LabWork", ctx(), 0),
				"ResourceGathered",
				"DustCores",
				0 / 0
			)
		).toBeFalsy()
		expect(QuestLogic.applyEvent("AntProblem", active, "NotAnEvent", "Ant")).toBeFalsy()
	end)
	it("credits prior discoveries and current zone on accept", function()
		local active = QuestLogic.newProgress("ShoeSummit", ctx(2, 1, { WireJungle = 1 }), 0)
		expect(active.Progress[1]).toBe(1)
		expect(active.Progress[2]).toBe(0)
		local entered = QuestLogic.newProgress("BedroomExpedition", ctx(3, 1, {}, "Bedroom"), 0)
		expect(entered.Progress[1]).toBe(1)
	end)
	it("objectives can be completed in any order", function()
		local active = QuestLogic.newProgress("FirstSteps", ctx(), 0)
		QuestLogic.applyEvent("FirstSteps", active, "TalkedTo", "Mote")
		for _ = 1, 3 do
			QuestLogic.applyEvent("FirstSteps", active, "Collected", "GrowthOrb")
		end
		expect(QuestLogic.isComplete("FirstSteps", active)).toBeTruthy()
	end)
	it("auto-start finds the first story quest for a new player", function()
		local list = QuestLogic.autoStartable({ Active = {}, Completed = {}, Tracked = "" }, ctx())
		expect(table.find(list, "FirstSteps") ~= nil).toBeTruthy()
		expect(table.find(list, "BedroomExpedition")).toBe(nil)
	end)
end)

describe("AscensionLogic", function()
	local function titanData()
		local d = DataSchema.new()
		d.Progress.Tier = 12
		d.Progress.RunMass = 5e6
		d.Currencies.Mass = 5e6
		d.Currencies.GrowthEnergy = 99999
		d.Currencies.TitanShards = 1234
		d.Currencies.SkillPoints = 3
		d.Upgrades.WalkSpeed = 10
		d.Resources.DustCores = 50
		d.Skills.DoubleJump = true
		d.Skills.AirDash = true
		d.Cosmetics.Owned.VIPAura = true
		d.Titles.Owned.Titan = true
		d.Achievements.TitanSized = 100
		d.Collectibles.FloorWorld_TitanShard_1 = true
		d.Discoveries.ShoeSummit = 5
		d.FastTravel.Kitchen = true
		d.Monetization.Receipts.abc = 1
		d.Monetization.StarterPackBought = true
		d.Boosts.Mass2x = 600
		d.Progress.Level = 40
		d.Quests.Active.CoreSpire = { Progress = { 1, 0 }, StartedAt = 0 }
		d.Quests.Active.CityOfGiants = { Progress = { 1, 0 }, StartedAt = 0 }
		d.Quests.Completed.FirstSteps = 1
		d.Bosses.Queen = { Kills = 3, BestTime = 50, LastRewardAt = 0 }
		return d
	end
	it("refuses below the required tier", function()
		local d = DataSchema.new()
		expect((AscensionLogic.canAscend(d))).toBeFalsy()
		d.Progress.Tier = AscensionConfig.RequiredTier
		expect((AscensionLogic.canAscend(d))).toBeTruthy()
	end)
	it("resets exactly the promised things", function()
		local d = titanData()
		local summary = AscensionLogic.apply(d, 1000, 0, false)
		expect(d.Currencies.Mass).toBe(0)
		expect(d.Currencies.GrowthEnergy).toBe(0)
		expect(next(d.Upgrades)).toBe(nil)
		expect(d.Resources.DustCores).toBe(0)
		expect(next(d.Skills)).toBe(nil)
		expect(d.Progress.Tier).toBe(1)
		expect(d.Progress.RunMass).toBe(0)
		expect(d.Quests.Active.CoreSpire).toBe(nil) -- non-story progress reset
		expect(summary.Points).toBeGreaterThan(0)
		expect(d.Currencies.AscensionPoints).toBe(summary.Points)
	end)
	it("keeps everything it promises to keep", function()
		local d = titanData()
		AscensionLogic.apply(d, 1000, 0, false)
		expect(d.Currencies.TitanShards).toBe(1234)
		expect(d.Progress.Level).toBe(40)
		expect(d.Cosmetics.Owned.VIPAura).toBeTruthy()
		expect(d.Titles.Owned.Titan).toBeTruthy()
		expect(d.Achievements.TitanSized).toBe(100)
		expect(d.Collectibles.FloorWorld_TitanShard_1).toBeTruthy()
		expect(d.Discoveries.ShoeSummit).toBe(5)
		expect(d.FastTravel.Kitchen).toBeTruthy()
		expect(d.Monetization.Receipts.abc).toBe(1)
		expect(d.Monetization.StarterPackBought).toBeTruthy()
		expect(d.Boosts.Mass2x).toBe(600)
		expect(d.Quests.Completed.FirstSteps).toBe(1)
		expect(d.Quests.Active.CityOfGiants ~= nil).toBeTruthy() -- story quest kept
		expect(d.Bosses.Queen.Kills).toBe(3)
	end)
	it("refunds spent skill points and applies start perks", function()
		local d = titanData()
		local summary = AscensionLogic.apply(d, 1000, 4000, true)
		expect(summary.RefundedSkillPoints).toBe(3) -- DoubleJump 1 + AirDash 2
		expect(d.Currencies.SkillPoints).toBe(6)
		expect(d.Currencies.GrowthEnergy).toBe(4000)
		expect(d.Skills.DoubleJump).toBeTruthy()
		expect(d.Skills.Slide).toBeTruthy()
		expect(d.Ascension.Count).toBe(1)
	end)
end)

describe("DailyLogic", function()
	it("selection is deterministic and respects tier", function()
		local a = DailyLogic.pick(DailyConfig.DailyPool, 3, DailyLogic.dailySeed(123, 20000), 1)
		local b = DailyLogic.pick(DailyConfig.DailyPool, 3, DailyLogic.dailySeed(123, 20000), 1)
		expect(#a).toBe(3)
		for i = 1, 3 do
			expect(a[i].Id).toBe(b[i].Id)
			expect(DailyConfig.findObjective(a[i].Id).MinTier).toBeAtMost(1)
		end
		local c = DailyLogic.pick(DailyConfig.DailyPool, 3, DailyLogic.dailySeed(123, 20001), 15)
		expect(#c).toBe(3)
	end)
	it("progress caps and claims once", function()
		local slots = { { Id = "D_Orbs", Progress = 0, Claimed = false } }
		for _ = 1, 100 do
			DailyLogic.applyEvent(slots, "OrbCollected", 1)
		end
		expect(slots[1].Progress).toBe(25)
		expect(DailyLogic.canClaim(slots[1])).toBeTruthy()
		slots[1].Claimed = true
		expect(DailyLogic.canClaim(slots[1])).toBeFalsy()
		expect(DailyLogic.applyEvent(slots, "OrbCollected", 1)).toBeFalsy()
	end)
end)

describe("SessionLock", function()
	it("claims free, own and stale locks only", function()
		expect((SessionLock.canClaim(nil, "A", 100, 60))).toBeTruthy()
		local mine = SessionLock.make("A", 1, 100)
		expect((SessionLock.canClaim(mine, "A", 120, 60))).toBeTruthy()
		expect((SessionLock.canClaim(mine, "B", 120, 60))).toBeFalsy()
		expect((SessionLock.canClaim(mine, "B", 200, 60))).toBeTruthy()
	end)
	it("unwraps legacy raw records", function()
		local data, session = SessionLock.unwrap({ Version = 1, Mass = 5 })
		expect(data.Mass).toBe(5)
		expect(session).toBe(nil)
		local d2, s2 = SessionLock.unwrap({ Data = { x = 1 }, Session = { JobId = "A", PlaceId = 1, Time = 3 } })
		expect(d2.x).toBe(1)
		expect(s2.JobId).toBe("A")
		expect((SessionLock.unwrap(nil))).toBe(nil)
	end)
end)

describe("ReceiptLedger", function()
	it("records and detects duplicates", function()
		local ledger = {}
		expect(ReceiptLedger.has(ledger, "p1")).toBeFalsy()
		ReceiptLedger.record(ledger, "p1", 10)
		expect(ReceiptLedger.has(ledger, "p1")).toBeTruthy()
	end)
	it("prunes oldest beyond the cap", function()
		local ledger = {}
		for i = 1, 10 do
			ReceiptLedger.record(ledger, "p" .. i, i)
		end
		ReceiptLedger.prune(ledger, 4)
		local n = 0
		for _ in ledger do
			n += 1
		end
		expect(n).toBe(4)
		expect(ledger.p1).toBe(nil)
		expect(ledger.p10).toBe(10)
	end)
end)

describe("ContentSanitizer", function()
	local ContentSanitizer = require(Server.Logic.ContentSanitizer)
	local DataSchema = require(Shared.Data.DataSchema)
	it("removes retired ids and clamps upgrade levels", function()
		local data = DataSchema.new()
		data.Upgrades.MassGain = 9999
		data.Upgrades.Gone = 3
		data.Skills.Gone = true
		data.Quests.Active.Gone = { Progress = { 1 }, StartedAt = 0 }
		data.Quests.Tracked = "Gone"
		data.Cosmetics.Owned.Gone = true
		data.Cosmetics.Equipped.Trail = { "Gone" }
		local fixes = ContentSanitizer.apply(data)
		expect(data.Upgrades.MassGain).toBe(40)
		expect(data.Upgrades.Gone).toBe(nil)
		expect(data.Skills.Gone).toBe(nil)
		expect(data.Quests.Active.Gone).toBe(nil)
		expect(data.Quests.Tracked).toBe("")
		expect(data.Cosmetics.Owned.Gone).toBe(nil)
		expect(data.Cosmetics.Equipped.Trail).toBe(nil)
		expect(#fixes >= 5).toBe(true)
	end)
	it("leaves valid data untouched", function()
		local data = DataSchema.new()
		data.Upgrades.MassGain = 3
		data.Skills.Slide = true
		expect(#ContentSanitizer.apply(data)).toBe(0)
		expect(data.Upgrades.MassGain).toBe(3)
	end)
end)
