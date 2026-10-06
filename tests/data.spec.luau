local DataSchema = require(Shared.Data.DataSchema)
local GameConfig = require(Shared.Config.GameConfig)

describe("DataSchema", function()
	it("creates fresh data at the current version", function()
		local d = DataSchema.new()
		expect(d.Version).toBe(DataSchema.Version)
		expect(d.Currencies.Mass).toBe(0)
		expect(d.Progress.Level).toBe(1)
	end)
	it("migrates v1 top-level Mass", function()
		local d = DataSchema.prepare({ Version = 1, Mass = 500 })
		expect(d.Currencies.Mass).toBe(500)
		expect((d :: any).Mass).toBe(nil)
	end)
	it("migrates v2 boolean discoveries", function()
		local d = DataSchema.prepare({ Version = 2, Discoveries = { UnderTheBed = true } })
		expect(d.Discoveries.UnderTheBed).toBe(1)
	end)
	it("reconciles missing nested fields without touching existing ones", function()
		local d = DataSchema.prepare({ Version = 3, Currencies = { Mass = 42 }, Settings = { MusicVolume = 0.1 } })
		expect(d.Currencies.Mass).toBe(42)
		expect(d.Currencies.TitanShards).toBe(0)
		expect(d.Settings.MusicVolume).toBe(0.1)
		expect(d.Settings.SfxVolume).toBe(0.8)
	end)
	it("sanitizes NaN, infinity, negatives and wrong types", function()
		local d = DataSchema.prepare({
			Version = 3,
			Currencies = { Mass = 0 / 0, GrowthEnergy = math.huge, TitanShards = -50, SkillPoints = "lots" },
			Progress = { Level = -3, XP = 0 / 0 },
			Upgrades = { WalkSpeed = 2.7, Bad = "x" },
			Skills = { DoubleJump = true, Weird = 5 },
			Settings = { FieldOfView = 9999, PerformancePreset = "Ultra" },
		})
		expect(d.Currencies.Mass).toBe(0)
		-- Infinity can never be legitimate; it is treated as corruption.
		expect(d.Currencies.GrowthEnergy).toBe(0)
		expect(d.Currencies.TitanShards).toBe(0)
		expect(d.Currencies.SkillPoints).toBe(0)
		expect(d.Progress.Level).toBe(1)
		expect(d.Progress.XP).toBe(0)
		expect(d.Upgrades.WalkSpeed).toBe(2)
		expect(d.Upgrades.Bad).toBe(nil)
		expect(d.Skills.Weird).toBe(nil)
		expect(d.Settings.FieldOfView).toBe(100)
		expect(d.Settings.PerformancePreset).toBe("Auto")
	end)
	it("treats a corrupted root as new data", function()
		local d = DataSchema.prepare("garbage")
		expect(d.Currencies.Mass).toBe(0)
	end)
	it("bounds the receipt ledger, keeping the newest", function()
		local receipts = {}
		for i = 1, GameConfig.MaxProcessedReceipts + 30 do
			receipts["r" .. i] = i
		end
		local d = DataSchema.prepare({ Version = 3, Monetization = { Receipts = receipts } })
		local count = 0
		for _ in d.Monetization.Receipts do
			count += 1
		end
		expect(count).toBe(GameConfig.MaxProcessedReceipts)
		expect(d.Monetization.Receipts["r1"]).toBe(nil)
		expect(d.Monetization.Receipts["r" .. (GameConfig.MaxProcessedReceipts + 30)]).toBeTruthy()
	end)
	it("client view hides server-only keys", function()
		local view = DataSchema.clientView(DataSchema.new() :: any)
		expect(view.Monetization).toBe(nil)
		expect(view.Meta).toBe(nil)
		expect(view.Currencies ~= nil).toBeTruthy()
	end)
	it("prepare does not mutate the input table", function()
		local raw = { Version = 3, Currencies = { Mass = 5 } }
		DataSchema.prepare(raw)
		expect(raw.Currencies.TitanShards).toBe(nil)
	end)
end)
