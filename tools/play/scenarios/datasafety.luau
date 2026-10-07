-- Hostile / corrupted / old saves through the real load path, session locks
-- held by another server, and DataStore outages at join and leave.
local E = __E
local GameConfig = E.sharedModule("Config.GameConfig")
local DataSchema = E.sharedModule("Data.DataSchema")
local function store()
	E.game:GetService("DataStoreService"):GetDataStore(GameConfig.DataStoreName)
	for key, s in E.dataStores do
		if string.find(key, "ds:" .. GameConfig.DataStoreName, 1, true) then
			return s
		end
	end
	error("no store")
end
local bad = DataSchema.migrate and table.clone(DataSchema.Defaults) or {}
-- Corrupted record: negative / absurd / wrong-typed values.
store()[GameConfig.DataKeyPrefix .. "61"] = {
	Data = {
		Version = DataSchema.Version,
		Currencies = { Mass = -500, GrowthEnergy = "lots", TitanShards = 1e300, SkillPoints = -3 },
		Progress = { Level = -7, XP = -1, Tier = 99, HighestTier = 0 },
		Upgrades = { MassGain = 9999, NotARealUpgrade = 5, WalkSpeed = -2 },
		Skills = { DoubleJump = true, FakeSkill = true },
		Quests = { Active = { FakeQuest = { Progress = { 1 } } }, Completed = {}, Tracked = 5 },
		Settings = { MusicVolume = 99, PerformancePreset = "Ultra" },
	},
	SavedAt = 0,
}
-- Old version 1 record with only a few fields.
store()[GameConfig.DataKeyPrefix .. "62"] = { Data = { Version = 1, Currencies = { Mass = 1234 } }, SavedAt = 0 }
-- Raw legacy value (not wrapped in a record at all).
store()[GameConfig.DataKeyPrefix .. "63"] = "garbage"
-- A record locked by a live session on another server.
store()[GameConfig.DataKeyPrefix .. "64"] = {
	Data = { Version = DataSchema.Version, Currencies = { Mass = 777 } },
	Session = { JobId = "other-server", PlaceId = 0, Time = os.time() },
	SavedAt = os.time(),
}
E.startServer()
E.run(3)
local PDS = E.serverModule("Services.PlayerDataService")

print("== Corrupted save")
local p1 = E.addPlayer("Corrupt", { UserId = 61 })
E.waitFor(function()
	return PDS:IsLoaded(p1)
end, 40, "corrupt load")
local d = E.data(p1)
E.check("corrupted save still loads", d ~= nil)
if d then
	E.check("negative Mass repaired", d.Currencies.Mass >= 0, d.Currencies.Mass)
	E.check("wrong-typed currency repaired", type(d.Currencies.GrowthEnergy) == "number" and d.Currencies.GrowthEnergy >= 0, tostring(d.Currencies.GrowthEnergy))
	E.check("absurd currency clamped", d.Currencies.TitanShards <= GameConfig.MaxCurrency, d.Currencies.TitanShards)
	E.check("level repaired", d.Progress.Level >= 1, d.Progress.Level)
	E.check("upgrade level clamped to its max", d.Upgrades.MassGain <= 40, d.Upgrades.MassGain)
	E.check("unknown upgrade dropped", d.Upgrades.NotARealUpgrade == nil)
	E.check("negative upgrade dropped/zeroed", (d.Upgrades.WalkSpeed or 0) >= 0)
	E.check("unknown skill dropped", d.Skills.FakeSkill == nil)
	E.check("unknown quest dropped", d.Quests.Active.FakeQuest == nil)
	E.check("settings clamped", d.Settings.MusicVolume <= 1 and d.Settings.PerformancePreset ~= "Ultra", tostring(d.Settings.MusicVolume) .. " " .. tostring(d.Settings.PerformancePreset))
	E.check("missing sections filled with defaults", d.Daily ~= nil and d.Cosmetics ~= nil and d.Monetization ~= nil)
end

print("== Old-format saves")
local p2 = E.addPlayer("Old", { UserId = 62 })
local p3 = E.addPlayer("Raw", { UserId = 63 })
E.waitFor(function()
	return PDS:IsLoaded(p2) and PDS:IsLoaded(p3)
end, 40, "old load")
E.check("version 1 save migrated, Mass kept", E.data(p2) and E.data(p2).Currencies.Mass == 1234, E.data(p2) and E.data(p2).Currencies.Mass)
E.check("migrated to current version", E.data(p2) and E.data(p2).Version == DataSchema.Version)
E.check("unreadable legacy value doesn't block the player", E.data(p3) ~= nil or (E.kicks and #E.kicks > 0))

print("== Session locked by another server")
local p4 = E.addPlayer("Locked", { UserId = 64 })
E.run(8)
E.check("locked save is not loaded immediately (no double-session)", not PDS:IsLoaded(p4) or #(E.kicks or {}) > 0)
E.run(GameConfig.SessionLockTimeout + 60)
local loaded4 = p4.Parent and PDS:IsLoaded(p4)
local kicked4 = false
for _, k in E.kicks or {} do
	if k.Player == "Locked" then
		kicked4 = true
	end
end
E.check("after the lock expires the player gets their data or a safe rejoin message", loaded4 or kicked4)
if loaded4 then
	E.check("locked save loaded with its real data", E.data(p4).Currencies.Mass == 777, E.data(p4).Currencies.Mass)
end

print("== DataStore outage at join")
E.dsFailNext = 4
local p5 = E.addPlayer("Outage", { UserId = 65 })
E.waitFor(function()
	return PDS:IsLoaded(p5) or not p5.Parent
end, 90, "outage load")
E.check("join survives a short outage (retries)", PDS:IsLoaded(p5), "kicked: " .. tostring(not p5.Parent))

print("== Outage when leaving")
local beforeLeave = E.data(p5) and E.data(p5).Currencies
E.serverModule("Services.RewardService"):Grant(p5, { Mass = 50 }, { Source = "Quest" })
local massNow = E.data(p5).Currencies.Mass
E.dsFailNext = 3
E.removePlayer(p5)
E.run(30)
local rec = store()[GameConfig.DataKeyPrefix .. "65"]
E.check("progress saved despite failures on leave (retries)", rec and rec.Data.Currencies.Mass == massNow, rec and rec.Data.Currencies.Mass)
local _ = beforeLeave
local _b = bad
E.summary()
