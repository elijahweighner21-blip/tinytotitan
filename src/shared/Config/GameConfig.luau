--!strict
--[[
	GameConfig
	Global constants: versions, persistence tuning, admin access, safety limits.
	Anything that is a "knob" for live operations belongs here rather than being
	hard-coded in a service.
]]

local GameConfig = {
	GameName = "TINY → TITAN",
	Version = "1.0.0",

	-- Persistence ---------------------------------------------------------
	DataStoreName = "TinyToTitan_Players_v1",
	BackupDataStoreName = "TinyToTitan_Backups_v1",
	DataKeyPrefix = "player_",
	AutosaveInterval = 150, -- seconds between autosaves per player
	BackupInterval = 900, -- seconds between rolling backups per player
	-- A session lock older than this is considered abandoned (server crashed).
	-- Must be comfortably larger than AutosaveInterval because autosaves refresh it.
	SessionLockTimeout = 420,
	SessionLockRetries = 6,
	SessionLockRetryDelay = 4,
	MaxProcessedReceipts = 120,
	-- When DataStores are unavailable in Studio (no API access), fall back to an
	-- in-memory store so the game is still playable. Never used in live servers.
	AllowMockDataStoreInStudio = true,

	-- Monetisation ----------------------------------------------------------
	-- Studio-only fake receipts for testing ProcessReceipt end to end. The
	-- server additionally requires RunService:IsStudio(), so this cannot grant
	-- anything in a live game even if left enabled.
	AllowStudioTestPurchases = true,

	-- Access ------------------------------------------------------------------
	-- UserIds allowed to use admin/debug tools. The server is the only authority.
	Admins = {} :: { number },
	AdminGroup = nil :: { GroupId: number, MinRank: number }?,
	-- Owners of a Studio test session are admins automatically.
	StudioIsAdmin = true,

	-- Safety limits -------------------------------------------------------------
	MaxCurrency = 1e15,
	MaxMass = 1e15,
	MaxLevel = 250,
	MinScale = 0.2,
	MaxScale = 400,
	KillPlaneY = -350,

	-- Respawn / world -------------------------------------------------------------
	RespawnTime = 3,
	PlayerCollisionGroup = "Players",
	MovingPropGroup = "MovingProps",
	DebrisGroup = "Debris",
	EnemyGroup = "Enemies",

	-- Daily reset happens at this UTC hour.
	DailyResetHourUtc = 0,

	-- Leaderboards
	LeaderboardRefreshInterval = 150,
	LeaderboardSubmitInterval = 300,
	LeaderboardSize = 50,
}

return GameConfig
