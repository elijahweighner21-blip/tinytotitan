--!strict
--[[
	PlayerDataService
	Loads, validates, replicates and saves player data. Data loss is the worst
	bug a game can have, so this service is deliberately conservative:

	  * UpdateAsync only (never SetAsync) for the main store.
	  * Session locking: a record is only written by the server that owns its
	    session. Another server holding a fresh lock is asked (via
	    MessagingService) to release it; a crashed server's lock expires after
	    GameConfig.SessionLockTimeout.
	  * A server that discovers it has LOST the lock stops saving and kicks the
	    player rather than overwrite newer progress.
	  * Saves for one player never overlap; a save requested mid-save is queued.
	  * Rejoining the same server waits for the previous release-save.
	  * Autosaves are staggered and skipped when the request budget is low.
	  * Rolling backups go to a separate store every BackupInterval.
	  * BindToClose saves everyone in parallel.
	  * Every load passes through DataSchema.prepare (migrate, reconcile,
	    sanitise); every save sanitises a snapshot first.

	Other services mutate `PlayerDataService:Get(player)` directly and then
	call `:Changed(player, topLevelKey)` to replicate.
]]

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local DataSchema = require(Shared.Data.DataSchema)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)
local Log = require(Shared.Util.Log)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local SessionLock = require(ServerRoot.Logic.SessionLock)
local MockDataStore = require(ServerRoot.Logic.MockDataStore)
local ContentSanitizer = require(ServerRoot.Logic.ContentSanitizer)

type Data = DataSchema.Data

type Profile = {
	Player: Player,
	UserId: number,
	Key: string,
	Data: Data,
	Loaded: boolean,
	Released: boolean,
	Leaving: boolean,
	Saving: boolean,
	LastSave: number,
	NextAutosave: number,
	LastBackup: number,
	Dirty: { [string]: boolean },
	FlushScheduled: boolean,
	SessionStart: number,
}

type Store = {
	UpdateAsync: (PlayerDataService: any, key: string, transform: (any) -> any) -> any,
}

local RELEASE_TOPIC = "TT_ReleaseSession"
local TAG = "PlayerData"

local PlayerDataService = {}

-- Fired once a player's data is ready: (player, data)
PlayerDataService.Loaded = Signal.new() :: Signal.Signal<Player, Data>
-- Fired right before a player's profile is released (they left): (player, data)
PlayerDataService.Releasing = Signal.new() :: Signal.Signal<Player, Data>

local profiles: { [Player]: Profile } = {}
local releasing: { [number]: boolean } = {} -- userId -> release save in flight
local beforeSaveHooks: { (player: Player, data: Data, isFinal: boolean) -> () } = {}
local mainStore: Store
local backupStore: Store
local usingMock = false
local shuttingDown = false

------------------------------------------------------------------ stores

local function openStores()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	local okBackup, backup = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.BackupDataStoreName)
	end)
	local reachable = ok and okBackup
	if reachable and RunService:IsStudio() then
		-- Probe: in Studio without API access every request errors.
		local probeOk = pcall(function()
			(store :: GlobalDataStore):GetAsync("__probe")
		end)
		reachable = probeOk
	end
	if reachable then
		mainStore = store :: any
		backupStore = backup :: any
		return
	end
	if RunService:IsStudio() and GameConfig.AllowMockDataStoreInStudio then
		Log.warn(TAG, "DataStores unavailable in Studio — using in-memory mock (progress will NOT persist).")
		usingMock = true
		mainStore = MockDataStore.new() :: any
		backupStore = MockDataStore.new() :: any
		return
	end
	-- Live server without DataStores: keep the real handles; loads will retry
	-- and kick with a friendly message rather than risk overwriting data.
	mainStore = store :: any
	backupStore = backup :: any
	Log.error(TAG, "DataStore open failed:", store)
end

local function budgetOk(): boolean
	if usingMock then
		return true
	end
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	end)
	return not ok or (budget :: number) > 4
end

------------------------------------------------------------------ replication

local function flush(profile: Profile)
	profile.FlushScheduled = false
	if not profile.Loaded or not profile.Player.Parent then
		return
	end
	local patch = {}
	local any = false
	for key in profile.Dirty do
		if not DataSchema.ServerOnly[key] then
			patch[key] = TableUtil.deepCopy((profile.Data :: any)[key])
			any = true
		end
	end
	table.clear(profile.Dirty)
	if any then
		Net.state(profile.Player, "Patch", patch)
	end
end

function PlayerDataService:Changed(player: Player, key: string)
	local profile = profiles[player]
	if not profile or not profile.Loaded then
		return
	end
	profile.Dirty[key] = true
	if not profile.FlushScheduled then
		profile.FlushScheduled = true
		task.defer(flush, profile)
	end
end

function PlayerDataService:SendFull(player: Player)
	local profile = profiles[player]
	if profile and profile.Loaded then
		Net.state(player, "Full", TableUtil.deepCopy(DataSchema.clientView(profile.Data :: any)))
	end
end

------------------------------------------------------------------ save

local function runBeforeSave(profile: Profile, isFinal: boolean)
	for _, hook in beforeSaveHooks do
		local ok, err = pcall(function()
			hook(profile.Player, profile.Data, isFinal)
		end)
		if not ok then
			Log.error(TAG, "before-save hook failed:", err)
		end
	end
end

local function writeBackup(profile: Profile, snapshot: any, now: number)
	profile.LastBackup = now
	task.spawn(function()
		local ok, err = pcall(function()
			backupStore:UpdateAsync(profile.Key, function()
				return { Data = snapshot, SavedAt = now, JobId = game.JobId }
			end)
		end)
		if not ok then
			Log.warn(TAG, "backup failed for", profile.UserId, err)
		end
	end)
end

-- Returns true when the data is safely persisted.
local function saveProfile(profile: Profile, release: boolean, reason: string): boolean
	if profile.Released or not profile.Loaded then
		return false
	end
	-- Never overlap saves for the same player; wait for the current one.
	local waited = 0
	while profile.Saving and waited < 30 do
		task.wait(0.1)
		waited += 0.1
	end
	if profile.Released then
		return false
	end
	profile.Saving = true
	runBeforeSave(profile, release)

	local now = os.time()
	local data = profile.Data :: any
	data.Meta.LastSave = now
	data.Meta.SaveCount += 1
	local snapshot = TableUtil.deepCopy(data)
	DataSchema.sanitize(snapshot)

	local lostLock = false
	local success = false
	local lastErr: any = nil
	for attempt = 1, 4 do
		lostLock = false
		local ok, err = pcall(function()
			mainStore:UpdateAsync(profile.Key, function(record)
				local _, session = SessionLock.unwrap(record)
				local allowed = SessionLock.canClaim(session, game.JobId, os.time(), GameConfig.SessionLockTimeout)
				if not allowed then
					lostLock = true
					return nil
				end
				return {
					Data = snapshot,
					Session = if release then nil else SessionLock.make(game.JobId, game.PlaceId, os.time()),
					SavedAt = now,
					Version = DataSchema.Version,
				}
			end)
		end)
		if ok and not lostLock then
			success = true
			break
		end
		if lostLock then
			break
		end
		lastErr = err
		if attempt < 4 and not shuttingDown then
			task.wait(1.5 * attempt)
		end
	end

	profile.Saving = false
	if success then
		profile.LastSave = now
		profile.NextAutosave = now + GameConfig.AutosaveInterval
		if release then
			profile.Released = true
		elseif now - profile.LastBackup >= GameConfig.BackupInterval then
			writeBackup(profile, snapshot, now)
		end
		Log.debug(TAG, "saved", profile.UserId, reason)
	elseif lostLock then
		-- Another server owns this player's data now. Our copy is stale:
		-- stop saving it and get the player out of this server.
		profile.Released = true
		Log.error(TAG, "session lost for", profile.UserId, "- refusing to overwrite newer data")
		if profile.Player.Parent then
			profile.Player:Kick("Your progress was opened on another server. Please rejoin to continue safely.")
		end
	else
		profile.NextAutosave = now + 30 -- retry sooner after a failure
		Log.error(TAG, "save failed for", profile.UserId, reason, lastErr)
	end
	return success
end

------------------------------------------------------------------ load

local function requestRelease(userId: number)
	if usingMock then
		return
	end
	pcall(function()
		MessagingService:PublishAsync(RELEASE_TOPIC, { UserId = userId, From = game.JobId })
	end)
end

local function newProfile(player: Player): Profile
	return {
		Player = player,
		UserId = player.UserId,
		Key = GameConfig.DataKeyPrefix .. tostring(player.UserId),
		Data = DataSchema.new(),
		Loaded = false,
		Released = false,
		Leaving = false,
		Saving = false,
		LastSave = os.time(),
		NextAutosave = os.time() + GameConfig.AutosaveInterval + math.random(0, 30),
		LastBackup = os.time(),
		Dirty = {},
		FlushScheduled = false,
		SessionStart = os.clock(),
	}
end

local function loadProfile(player: Player)
	local profile = newProfile(player)
	profiles[player] = profile

	-- Same-server rejoin: wait for the previous session's release-save.
	local waited = 0
	while releasing[profile.UserId] and waited < 30 do
		task.wait(0.25)
		waited += 0.25
	end

	local loadedRaw: any = nil
	local lockedOut = false
	local loaded = false
	for attempt = 1, GameConfig.SessionLockRetries do
		if not player.Parent then
			break
		end
		lockedOut = false
		local ok, err = pcall(function()
			mainStore:UpdateAsync(profile.Key, function(record)
				local raw, session = SessionLock.unwrap(record)
				local allowed, why = SessionLock.canClaim(session, game.JobId, os.time(), GameConfig.SessionLockTimeout)
				if not allowed then
					lockedOut = true
					return nil
				end
				if why == "stale" then
					Log.warn(TAG, "taking over stale session for", profile.UserId)
				end
				loadedRaw = raw
				return {
					Data = raw,
					Session = SessionLock.make(game.JobId, game.PlaceId, os.time()),
					SavedAt = if type(record) == "table" and record.SavedAt then record.SavedAt else os.time(),
					Version = DataSchema.Version,
				}
			end)
		end)
		if ok and not lockedOut then
			loaded = true
			break
		end
		if lockedOut then
			requestRelease(profile.UserId)
		else
			Log.warn(TAG, "load attempt", attempt, "failed for", profile.UserId, err)
		end
		task.wait(GameConfig.SessionLockRetryDelay * (if lockedOut then 1 else attempt))
	end

	if not loaded then
		profiles[player] = nil
		if player.Parent then
			player:Kick(
				if lockedOut
					then "Your progress is still being saved on another server. Please rejoin in a moment."
					else "We couldn't load your progress right now (Roblox data services are busy). Nothing was lost — please rejoin."
			)
		end
		return
	end

	local data = DataSchema.prepare(loadedRaw)
	local fixes = ContentSanitizer.apply(data)
	if #fixes > 0 then
		Log.warn("PlayerData", "repaired save for", player.UserId, table.concat(fixes, "; "))
	end
	local now = os.time()
	local meta = (data :: any).Meta
	if meta.FirstJoin == 0 then
		meta.FirstJoin = now
	end
	meta.LastJoin = now
	meta.Sessions += 1
	profile.Data = data
	profile.Loaded = true

	if not player.Parent then
		-- Left while loading: we hold the lock, so release it right away.
		releasing[profile.UserId] = true
		saveProfile(profile, true, "left-during-load")
		releasing[profile.UserId] = nil
		profiles[player] = nil
		return
	end

	player:SetAttribute("DataLoaded", true)
	PlayerDataService.Loaded:Fire(player, data)
	Log.debug(TAG, "loaded", profile.UserId, if loadedRaw == nil then "(new player)" else "")
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Leaving = true
	if not profile.Loaded then
		return -- loadProfile handles the left-during-load case
	end
	releasing[profile.UserId] = true
	PlayerDataService.Releasing:Fire(player, profile.Data)
	-- Give Releasing listeners one frame to finish synchronous bookkeeping.
	task.wait()
	saveProfile(profile, true, "leave")
	releasing[profile.UserId] = nil
	profiles[player] = nil
end

------------------------------------------------------------------ public API

function PlayerDataService:Get(player: Player): Data?
	local profile = profiles[player]
	if profile and profile.Loaded and not profile.Released then
		return profile.Data
	end
	return nil
end

function PlayerDataService:IsLoaded(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Loaded and not profile.Released
end

function PlayerDataService:WaitForData(player: Player, timeout: number?): Data?
	local limit = timeout or 30
	local start = os.clock()
	while player.Parent and os.clock() - start < limit do
		local data = PlayerDataService:Get(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return nil
end

-- Immediately persists the player's data (used after Robux purchases).
function PlayerDataService:ForceSave(player: Player, reason: string): boolean
	local profile = profiles[player]
	if not profile or not profile.Loaded or profile.Released then
		return false
	end
	return saveProfile(profile, false, reason)
end

function PlayerDataService:AddBeforeSave(hook: (player: Player, data: Data, isFinal: boolean) -> ())
	table.insert(beforeSaveHooks, hook)
end

function PlayerDataService:SessionSeconds(player: Player): number
	local profile = profiles[player]
	return if profile then os.clock() - profile.SessionStart else 0
end

function PlayerDataService:IsUsingMock(): boolean
	return usingMock
end

-- Admin: replace a player's data with fresh defaults (keeps purchases ledger).
function PlayerDataService:ResetData(player: Player)
	local profile = profiles[player]
	if not profile or not profile.Loaded then
		return
	end
	local keepMonetization = TableUtil.deepCopy((profile.Data :: any).Monetization)
	profile.Data = DataSchema.new();
	(profile.Data :: any).Monetization = keepMonetization
	PlayerDataService:SendFull(player)
end

------------------------------------------------------------------ lifecycle

function PlayerDataService:Init()
	openStores()
	Net.setReadyCheck(function(player)
		return PlayerDataService:IsLoaded(player)
	end)
	Net.onAction("ClientReady", nil, function(player)
		PlayerDataService:SendFull(player)
	end)
end

function PlayerDataService:Start()
	-- Deferred so every other service's Start has connected to `Loaded`
	-- first (with the Studio mock store a load completes without yielding).
	task.defer(function()
		Players.PlayerAdded:Connect(loadProfile)
		for _, player in Players:GetPlayers() do
			task.spawn(loadProfile, player)
		end
	end)
	Players.PlayerRemoving:Connect(releaseProfile)

	if not usingMock then
		pcall(function()
			MessagingService:SubscribeAsync(RELEASE_TOPIC, function(message)
				local body = message.Data
				if type(body) ~= "table" or body.From == game.JobId then
					return
				end
				for player, profile in profiles do
					if profile.UserId == body.UserId and profile.Loaded and not profile.Released then
						-- The player is joining elsewhere; this session must yield.
						if player.Parent then
							player:Kick("You joined from another server.")
						end
					end
				end
			end)
		end)
	end

	-- Staggered autosave loop.
	task.spawn(function()
		while not shuttingDown do
			task.wait(5)
			local now = os.time()
			for _, profile in profiles do
				if profile.Loaded and not profile.Released and not profile.Leaving and not profile.Saving then
					if now >= profile.NextAutosave and budgetOk() then
						task.spawn(saveProfile, profile, false, "autosave")
					end
				end
			end
		end
	end)

	game:BindToClose(function()
		shuttingDown = true
		local pending = 0
		for player, profile in profiles do
			if profile.Loaded and not profile.Released then
				pending += 1
				task.spawn(function()
					PlayerDataService.Releasing:Fire(player, profile.Data)
					saveProfile(profile, true, "shutdown")
					pending -= 1
				end)
			end
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 26 do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
