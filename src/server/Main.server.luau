--[[
	Main (server entry point)
	Boot order:
	  1. Remotes (so clients never infinite-yield waiting for them)
	  2. Procedural world (services index its tagged markers)
	  3. Services: Init in order, then Start
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Util.Log)

local Server = script.Parent
local Net = require(Server.Net)
local Loader = require(Server.Loader)
local WorldBuilder = require(Server.World.WorldBuilder)
local ModelSkins = require(Server.World.ModelSkins)

-- Characters must not spawn until the world exists and the save is loaded:
-- an auto-spawned character would fall into the void while the world is
-- still being built. (Also set in default.project.json.)
game:GetService("Players").CharacterAutoLoads = false

Net.init()
-- Start fetching uploaded 3D models now; creatures use their block bodies
-- until each model arrives.
ModelSkins.preload()
-- A world-building error must never stop the services from starting:
-- without them nobody's save loads and nobody spawns.
local built, buildErr = pcall(function()
	WorldBuilder.build()
end)
if not built then
	Log.error("Boot", "world build failed:", buildErr)
end
if not ReplicatedStorage:FindFirstChild("WorldIndex") then
	-- Clients wait for this during loading; never leave them waiting.
	local index = Instance.new("Folder")
	index.Name = "WorldIndex"
	index.Parent = ReplicatedStorage
end

-- Explicit order: core first, then gameplay, then meta systems. Anything not
-- listed still loads afterwards (with a warning) so new services are never
-- silently skipped.
local ORDER = {
	-- core
	"PlayerDataService",
	"CurrencyService",
	"StatisticsService",
	"EntitlementService",
	"BoostService",
	"GlobalModifierService",
	"StatService",
	"InventoryService",
	"PartyService",
	"ProgressionService",
	"ScaleService",
	"RewardService",
	"CharacterService",
	"ZoneService",
	"FastTravelService",
	-- gameplay
	"AnalyticsService",
	"AntiExploitService",
	"EnergyService",
	"AbilityService",
	"CombatService",
	"EnemyService",
	"BossService",
	"HazardService",
	"CollectibleService",
	"DiscoveryService",
	"InteractionService",
	"UpgradeService",
	"SkillService",
	"QuestService",
	"ChallengeService",
	"NPCService",
	"EnvironmentService",
	"WorldEventService",
	-- meta
	"DailyService",
	"AchievementService",
	"LevelRewardService",
	"AscensionService",
	"ShopService",
	"MonetizationService",
	"VipLoungeService",
	"LeaderboardService",
	"SettingsService",
	"TutorialService",
	"AdminService",
}

local count = Loader.run(Server.Services, ORDER)
Log.info(
	"Boot",
	string.format(
		"%s v%s — %d services running%s",
		GameConfig.GameName,
		GameConfig.Version,
		count,
		if RunService:IsStudio() then " (Studio)" else ""
	)
)
