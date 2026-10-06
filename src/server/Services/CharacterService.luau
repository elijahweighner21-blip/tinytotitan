--!strict
--[[
	CharacterService
	Character lifecycle and safety.

	  * Characters load only after data has loaded (CharacterAutoLoads off),
	    are scaled BEFORE being placed, and spawn at the right region for the
	    player's current tier (or their chosen respawn station).
	  * Collision groups: players never collide with each other, with moving
	    props or with debris — giant players cannot shove, block or launch
	    tiny players, and thrown objects cannot be used to grief.
	  * Kill plane / fall recovery: falling out of the world returns the player
	    to safety with no death and no lost progress.
	  * Stuck rescue: if growing leaves a character wedged in geometry, it is
	    moved to a safe spawn.
	  * SafeTeleport is the only server teleport; it opens a short grace window
	    so anti-exploit never flags legitimate teleports.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Signal = require(Shared.Util.Signal)
local Trove = require(Shared.Util.Trove)
local Log = require(Shared.Util.Log)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local ScaleService = require(script.Parent.ScaleService)

local CharacterService = {}

-- (player, character)
CharacterService.Spawned = Signal.new() :: Signal.Signal<Player, Model>
-- (player, reason)
CharacterService.Teleported = Signal.new() :: Signal.Signal<Player, string>
CharacterService.Died = Signal.new() :: Signal.Signal<Player>

local respawnPoints: { [Player]: { position: Vector3, zone: string } } = {}
local characterTroves: { [Player]: Trove.Trove } = {}

local function setupCollisionGroups()
	local groups = {
		GameConfig.PlayerCollisionGroup,
		GameConfig.MovingPropGroup,
		GameConfig.DebrisGroup,
		GameConfig.EnemyGroup,
	}
	for _, name in groups do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end
	local P, M, D, E =
		GameConfig.PlayerCollisionGroup, GameConfig.MovingPropGroup, GameConfig.DebrisGroup, GameConfig.EnemyGroup
	PhysicsService:CollisionGroupSetCollidable(P, P, false)
	PhysicsService:CollisionGroupSetCollidable(P, M, false)
	PhysicsService:CollisionGroupSetCollidable(P, D, false)
	PhysicsService:CollisionGroupSetCollidable(P, E, false)
	PhysicsService:CollisionGroupSetCollidable(E, E, false)
	PhysicsService:CollisionGroupSetCollidable(D, E, false)
end

local function assignGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = GameConfig.PlayerCollisionGroup
	end
end

-- Position of a spawn point lifted so a character of `scale` stands on it.
local function standingPosition(ground: Vector3, scale: number): Vector3
	return ground + Vector3.new(0, ScaleMath.height(scale) * 0.55 + 1, 0)
end

function CharacterService:GetSpawnPosition(player: Player): Vector3
	local tier = ProgressionService:GetTier(player)
	local chosen = respawnPoints[player]
	if chosen then
		local zone = ZoneConfig.get(chosen.zone)
		if zone and tier >= zone.RequiredTier then
			return chosen.position
		end
	end
	return ZoneConfig.highestUnlocked(tier).Spawn
end

function CharacterService:SetRespawnPoint(player: Player, position: Vector3, zoneId: string)
	respawnPoints[player] = { position = position, zone = zoneId }
end

function CharacterService:GetRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function CharacterService:IsAlive(player: Player): boolean
	return CharacterService:GetRoot(player) ~= nil
end

-- Server-side teleport. `ground` is a point on the floor; the character is
-- lifted according to its size.
function CharacterService:SafeTeleport(player: Player, ground: Vector3, reason: string, facing: Vector3?): boolean
	local root = CharacterService:GetRoot(player)
	local character = player.Character
	if not root or not character then
		return false
	end
	local scale = ScaleService:GetScale(player)
	local position = standingPosition(ground, scale)
	player:SetAttribute("TeleportGrace", workspace:GetServerTimeNow())
	root.AssemblyLinearVelocity = Vector3.zero
	local look = facing or Vector3.new(0, 0, -1)
	character:PivotTo(CFrame.lookAt(position, position + Vector3.new(look.X, 0, look.Z)))
	CharacterService.Teleported:Fire(player, reason)
	Net.signal(player, "Teleported", { Reason = reason })
	return true
end

function CharacterService:Rescue(player: Player, reason: string)
	CharacterService:SafeTeleport(player, CharacterService:GetSpawnPosition(player), reason)
end

local function onCharacterAdded(player: Player, character: Model)
	local previous = characterTroves[player]
	if previous then
		previous:Clean()
	end
	local trove = Trove.new()
	characterTroves[player] = trove

	for _, d in character:GetDescendants() do
		assignGroup(d)
	end
	trove:Connect(character.DescendantAdded, assignGroup)

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		Log.warn("Character", "character missing parts for", player.UserId)
		return
	end
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.BreakJointsOnDeath = false
	-- Freeze while appearance loads + scaling happens so the player never
	-- sees a full-size body flash at spawn.
	root.Anchored = true

	if not player:HasAppearanceLoaded() then
		local loaded = false
		local conn = player.CharacterAppearanceLoaded:Connect(function()
			loaded = true
		end)
		local start = os.clock()
		while not loaded and os.clock() - start < 4 and character.Parent do
			task.wait(0.1)
		end
		conn:Disconnect()
	end
	if not character.Parent then
		return
	end

	ScaleService:ApplyNow(player)
	local spawn = CharacterService:GetSpawnPosition(player)
	local position = standingPosition(spawn, ScaleService:GetScale(player))
	player:SetAttribute("TeleportGrace", workspace:GetServerTimeNow())
	character:PivotTo(CFrame.new(position))
	root.Anchored = false

	trove:Connect(humanoid.Died, function()
		CharacterService.Died:Fire(player)
		task.delay(GameConfig.RespawnTime, function()
			if player.Parent and player.Character == character then
				player:LoadCharacterAsync()
			end
		end)
	end)
	trove:Add(function()
		characterTroves[player] = nil
	end)
	trove:Connect(character.AncestryChanged, function(_, parent)
		if not parent then
			trove:Clean()
		end
	end)
	CharacterService.Spawned:Fire(player, character)
end

function CharacterService:Init()
	Players.CharacterAutoLoads = false
	Players.RespawnTime = GameConfig.RespawnTime
	setupCollisionGroups()
end

function CharacterService:Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		-- A character that spawned before this service started (e.g. Studio
		-- auto-spawn during world building) is never set up; replace it.
		if player.Character then
			player.Character:Destroy()
			player.Character = nil
		end
		if PlayerDataService:IsLoaded(player) then
			task.spawn(function()
				player:LoadCharacterAsync()
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	PlayerDataService.Loaded:Connect(function(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			player:LoadCharacterAsync()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		respawnPoints[player] = nil
		local trove = characterTroves[player]
		if trove then
			trove:Clean()
		end
	end)
	ScaleService.GrewIntoGeometry:Connect(function(player)
		CharacterService:Rescue(player, "Unstuck")
		Net.signal(
			player,
			"Notify",
			{ Text = "You grew too big for that space! Moved you somewhere roomier.", Kind = "Info" }
		)
	end)

	-- Fall recovery / kill plane. Cheap: one position read per player.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local root = CharacterService:GetRoot(player)
				if root then
					local p = root.Position
					if p.Y < GameConfig.KillPlaneY or p.Y ~= p.Y or math.abs(p.X) > 60000 or math.abs(p.Z) > 60000 then
						CharacterService:Rescue(player, "FellOut")
					end
				end
			end
		end
	end)
end

return CharacterService
