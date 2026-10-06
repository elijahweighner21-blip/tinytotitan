--!strict
--[[
	DataSchema
	Defines the save format: defaults, schema version, migrations and
	validation. Loaded data always goes through `prepare`:

	  raw (possibly old / corrupted)
	    -> migrate (version N -> latest, step by step)
	    -> reconcile (add any new default fields)
	    -> sanitize (clamp numbers, drop NaN/inf/negatives, bad types)

	Server-only keys (receipts, session lock) are never replicated to clients.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)
local MathUtil = require(script.Parent.Parent.Util.MathUtil)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local DataSchema = {}

DataSchema.Version = 3

DataSchema.Defaults = {
	Version = 3,
	Currencies = {
		Mass = 0,
		GrowthEnergy = 0,
		TitanShards = 0,
		AscensionPoints = 0,
		SkillPoints = 0,
		ExplorationTokens = 0,
	},
	Resources = {
		DustCores = 0,
		SugarCrystals = 0,
		NatureEssence = 0,
		Scrap = 0,
		TitanCells = 0,
	},
	Progress = {
		Level = 1,
		XP = 0,
		Tier = 1,
		HighestTier = 1,
		RunMass = 0, -- Mass earned since last Ascension
		ShrinkTier = 0, -- 0 = not shrunk; otherwise the chosen smaller tier
	},
	Upgrades = {} :: { [string]: number },
	Skills = {} :: { [string]: boolean },
	Ascension = {
		Count = 0,
		TotalPoints = 0,
		Tree = {} :: { [string]: number },
		LastAscendedAt = 0,
	},
	Quests = {
		Active = {} :: { [string]: { Progress: { number }, StartedAt: number } },
		Completed = {} :: { [string]: number },
		Tracked = "",
	},
	Challenges = {} :: { [string]: { Best: number, Medal: number, Completions: number, LastAt: number } },
	Collectibles = {} :: { [string]: boolean },
	CollectionClaims = {} :: { [string]: boolean },
	Discoveries = {} :: { [string]: number },
	Achievements = {} :: { [string]: number },
	Titles = {
		Owned = {} :: { [string]: boolean },
		Equipped = "",
	},
	Cosmetics = {
		Owned = {} :: { [string]: boolean },
		Equipped = {} :: { [string]: { string } },
	},
	Inventory = {
		KeyItems = {} :: { [string]: number },
		Relics = {} :: { [string]: boolean },
		Lore = {} :: { [string]: boolean },
	},
	Bosses = {} :: { [string]: { Kills: number, BestTime: number, LastRewardAt: number } },
	FastTravel = {} :: { [string]: boolean },
	Daily = {
		Day = 0,
		Objectives = {} :: { { Id: string, Progress: number, Claimed: boolean } },
		LoginDay = 0,
		Streak = 0,
		LoginClaimedDay = 0,
		Week = 0,
		Weekly = {} :: { { Id: string, Progress: number, Claimed: boolean } },
		ShopDay = 0,
		ShopBought = {} :: { [string]: boolean },
	},
	Boosts = {} :: { [string]: number }, -- boost id -> remaining ACTIVE-PLAY seconds
	Settings = {
		MusicVolume = 0.5,
		SfxVolume = 0.8,
		AmbientVolume = 0.6,
		CameraShake = 1,
		Particles = 1,
		DamageNumbers = true,
		UIScale = 1,
		MotionEffects = true,
		ScreenFlashes = true,
		FovEffects = true,
		PerformancePreset = "Auto",
		HideOtherEffects = false,
		SprintToggle = false,
		FieldOfView = 70,
		ShowTitles = true,
	},
	Stats = {
		TotalMassEarned = 0,
		HighestScale = 0,
		Playtime = 0,
		Distance = 0,
		Jumps = 0,
		Dashes = 0,
		ChallengesCompleted = 0,
		QuestsCompleted = 0,
		BossesDefeated = 0,
		EnemiesDefeated = 0,
		SecretsFound = 0,
		CollectiblesFound = 0,
		OrbsCollected = 0,
		ObjectsBroken = 0,
		UpgradesBought = 0,
		EventsJoined = 0,
		Logins = 0,
		TitanShardsEarned = 0,
	},
	Tutorial = {
		Step = 0,
		Done = false,
	},
	Monetization = {
		-- receipt PurchaseId -> unix time (bounded; see GameConfig.MaxProcessedReceipts)
		Receipts = {} :: { [string]: number },
		ProductCounts = {} :: { [string]: number },
		PassRewardsGranted = {} :: { [string]: boolean },
		StarterPackBought = false,
		RobuxSpent = 0,
	},
	Meta = {
		FirstJoin = 0,
		LastJoin = 0,
		LastSave = 0,
		SaveCount = 0,
		Sessions = 0,
	},
}

-- Keys never sent to clients.
DataSchema.ServerOnly = {
	Monetization = true,
	Meta = true,
} :: { [string]: boolean }

export type Data = typeof(DataSchema.Defaults)

-- Migrations: index N upgrades data from version N to N + 1.
local Migrations: { [number]: (data: { [string]: any }) -> () } = {
	[1] = function(data)
		-- v1 stored Mass at the top level.
		if type(data.Mass) == "number" then
			data.Currencies = data.Currencies or {}
			data.Currencies.Mass = data.Mass
			data.Mass = nil
		end
	end,
	[2] = function(data)
		-- v2 stored discoveries as booleans; v3 stores the unix time.
		if type(data.Discoveries) == "table" then
			for id, value in data.Discoveries do
				if value == true then
					data.Discoveries[id] = 1
				end
			end
		end
	end,
}

function DataSchema.migrate(data: { [string]: any }): { [string]: any }
	local version = if type(data.Version) == "number" then data.Version else 1
	while version < DataSchema.Version do
		local step = Migrations[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.Version = DataSchema.Version
	return data
end

local MAX = GameConfig.MaxCurrency

local function sanitizeNumberMap(map: any, lo: number, hi: number)
	if type(map) ~= "table" then
		return
	end
	for key, value in map do
		if type(key) ~= "string" then
			map[key] = nil
		elseif type(value) ~= "number" then
			map[key] = nil
		else
			map[key] = MathUtil.sanitize(value, lo, hi, 0)
		end
	end
end

local function sanitizeBoolMap(map: any)
	if type(map) ~= "table" then
		return
	end
	for key, value in map do
		if type(key) ~= "string" or value ~= true then
			map[key] = nil
		end
	end
end

function DataSchema.sanitize(data: { [string]: any })
	for key, value in data.Currencies do
		data.Currencies[key] = MathUtil.sanitize(value, 0, MAX, 0)
	end
	for key, value in data.Resources do
		data.Resources[key] = MathUtil.sanitize(value, 0, MAX, 0)
	end
	local p = data.Progress
	p.Level = MathUtil.sanitizeInt(p.Level, 1, GameConfig.MaxLevel, 1)
	p.XP = MathUtil.sanitize(p.XP, 0, MAX, 0)
	p.Tier = MathUtil.sanitizeInt(p.Tier, 1, 99, 1)
	p.HighestTier = MathUtil.sanitizeInt(p.HighestTier, 1, 99, 1)
	p.RunMass = MathUtil.sanitize(p.RunMass, 0, MAX, 0)
	p.ShrinkTier = MathUtil.sanitizeInt(p.ShrinkTier, 0, 99, 0)
	sanitizeNumberMap(data.Upgrades, 0, 1000)
	for key, value in data.Upgrades do
		data.Upgrades[key] = math.floor(value)
	end
	sanitizeBoolMap(data.Skills)
	sanitizeBoolMap(data.Collectibles)
	sanitizeBoolMap(data.CollectionClaims)
	sanitizeBoolMap(data.Titles.Owned)
	sanitizeBoolMap(data.Cosmetics.Owned)
	sanitizeBoolMap(data.FastTravel)
	sanitizeBoolMap(data.Inventory.Relics)
	sanitizeBoolMap(data.Inventory.Lore)
	sanitizeNumberMap(data.Inventory.KeyItems, 0, 1e6)
	sanitizeNumberMap(data.Discoveries, 0, 1e12)
	sanitizeNumberMap(data.Achievements, 0, 1e12)
	sanitizeNumberMap(data.Boosts, 0, 60 * 60 * 24 * 30)
	sanitizeNumberMap(data.Ascension.Tree, 0, 1000)
	sanitizeNumberMap(data.Quests.Completed, 0, 1e12)
	sanitizeNumberMap(data.Stats, 0, MAX)
	data.Ascension.Count = MathUtil.sanitizeInt(data.Ascension.Count, 0, 100000, 0)
	data.Ascension.TotalPoints = MathUtil.sanitize(data.Ascension.TotalPoints, 0, MAX, 0)
	if type(data.Titles.Equipped) ~= "string" then
		data.Titles.Equipped = ""
	end
	if type(data.Quests.Tracked) ~= "string" then
		data.Quests.Tracked = ""
	end
	-- Active quests: progress arrays of finite non-negative numbers.
	for id, entry in data.Quests.Active do
		if type(id) ~= "string" or type(entry) ~= "table" or type(entry.Progress) ~= "table" then
			data.Quests.Active[id] = nil
		else
			for i, v in entry.Progress do
				entry.Progress[i] = MathUtil.sanitize(v, 0, MAX, 0)
			end
			entry.StartedAt = MathUtil.sanitize(entry.StartedAt, 0, 1e12, 0)
		end
	end
	-- Equipped cosmetics: category -> array of ids.
	for category, list in data.Cosmetics.Equipped do
		if type(category) ~= "string" or type(list) ~= "table" then
			data.Cosmetics.Equipped[category] = nil
		else
			for i = #list, 1, -1 do
				if type(list[i]) ~= "string" then
					table.remove(list, i)
				end
			end
		end
	end
	for id, record in data.Challenges do
		if type(id) ~= "string" or type(record) ~= "table" then
			data.Challenges[id] = nil
		else
			record.Best = MathUtil.sanitize(record.Best, 0, 1e9, 0)
			record.Medal = MathUtil.sanitizeInt(record.Medal, 0, 4, 0)
			record.Completions = MathUtil.sanitizeInt(record.Completions, 0, 1e9, 0)
			record.LastAt = MathUtil.sanitize(record.LastAt, 0, 1e12, 0)
		end
	end
	for id, record in data.Bosses do
		if type(id) ~= "string" or type(record) ~= "table" then
			data.Bosses[id] = nil
		else
			record.Kills = MathUtil.sanitizeInt(record.Kills, 0, 1e9, 0)
			record.BestTime = MathUtil.sanitize(record.BestTime, 0, 1e9, 0)
			record.LastRewardAt = MathUtil.sanitize(record.LastRewardAt, 0, 1e12, 0)
		end
	end
	local s = data.Settings
	s.MusicVolume = MathUtil.sanitize(s.MusicVolume, 0, 1, 0.5)
	s.SfxVolume = MathUtil.sanitize(s.SfxVolume, 0, 1, 0.8)
	s.AmbientVolume = MathUtil.sanitize(s.AmbientVolume, 0, 1, 0.6)
	s.CameraShake = MathUtil.sanitize(s.CameraShake, 0, 1, 1)
	s.Particles = MathUtil.sanitize(s.Particles, 0, 1, 1)
	s.UIScale = MathUtil.sanitize(s.UIScale, 0.7, 1.3, 1)
	s.FieldOfView = MathUtil.sanitize(s.FieldOfView, 60, 100, 70)
	if s.PerformancePreset ~= "Low" and s.PerformancePreset ~= "Medium" and s.PerformancePreset ~= "High" and s.PerformancePreset ~= "Auto" then
		s.PerformancePreset = "Auto"
	end
	-- Bound the receipt ledger (oldest first) so the save never grows forever.
	local receipts = data.Monetization.Receipts
	local list = {}
	for id, t in receipts do
		if type(id) ~= "string" or type(t) ~= "number" then
			receipts[id] = nil
		else
			table.insert(list, { id = id, t = t })
		end
	end
	if #list > GameConfig.MaxProcessedReceipts then
		table.sort(list, function(a, b)
			return a.t < b.t
		end)
		for i = 1, #list - GameConfig.MaxProcessedReceipts do
			receipts[list[i].id] = nil
		end
	end
end

-- Full pipeline for data coming out of the DataStore (or nil for new players).
function DataSchema.prepare(raw: any): Data
	local data: { [string]: any }
	if type(raw) == "table" then
		data = TableUtil.deepCopy(raw)
	else
		data = TableUtil.deepCopy(DataSchema.Defaults) :: any
	end
	DataSchema.migrate(data)
	TableUtil.reconcile(data, DataSchema.Defaults :: any)
	DataSchema.sanitize(data)
	return (data :: any) :: Data
end

function DataSchema.new(): Data
	return DataSchema.prepare(nil)
end

-- A copy of the data safe to send to the owning client.
function DataSchema.clientView(data: { [string]: any }): { [string]: any }
	local view = {}
	for key, value in data do
		if not DataSchema.ServerOnly[key] then
			view[key] = value
		end
	end
	return view
end

return DataSchema
