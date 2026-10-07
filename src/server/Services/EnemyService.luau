--!strict
--[[
	EnemyService
	Ambient enemies with distance-based activation:

	  Spawner state  SLEEPING  no player within ActivationRadius → no enemies,
	                           no cost at all
	                 ACTIVE    enemies spawned and ticking at AITickRate
	  Enemy state    Idle / Patrol → Chase → Attack (telegraphed) / Retreat
	                 Stagger (on hit), Return (leashed), Dead

	Movement uses server-owned physics (AlignPosition / AlignOrientation on an
	unanchored root) so clients see smooth interpolated motion without the
	server streaming CFrames every frame. Enemies never collide with players
	(collision group), so a crowd can't trap or launch anyone.

	Targeting is size-aware: an enemy ignores players more than
	IgnoreSizeRatio times its size, and rewards shrink when a player far
	outgrows the enemy (no titan ant-farming).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyConfig = require(Shared.Config.EnemyConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local GameConfig = require(Shared.Config.GameConfig)
local CombatMath = require(Shared.Formulas.CombatMath)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Types = require(Shared.Types)
local Log = require(Shared.Util.Log)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local CreatureBuilder = require(ServerRoot.World.CreatureBuilder)
local CharacterService = require(script.Parent.CharacterService)
local CombatService = require(script.Parent.CombatService)
local RewardService = require(script.Parent.RewardService)
local StatisticsService = require(script.Parent.StatisticsService)
local ScaleService = require(script.Parent.ScaleService)
local PartyService = require(script.Parent.PartyService)

local EnemyService = {}

type Spawner = {
	Position: Vector3,
	EnemyId: string,
	Count: number,
	Radius: number,
	Zone: string,
	Active: boolean,
	LastNearby: number,
	Alive: { Enemy },
	NextSpawn: number,
}

export type Enemy = {
	Def: Types.Enemy,
	Model: Model,
	Root: BasePart,
	Align: AlignPosition,
	Orient: AlignOrientation,
	H: number,
	Health: number,
	MaxHealth: number,
	State: string,
	StateUntil: number,
	Target: Player?,
	Home: Vector3,
	LeashRadius: number,
	Zone: string,
	Damage: { [Player]: number },
	RewardMultiplier: number,
	Spawner: Spawner?,
	Unregister: () -> (),
	Dead: boolean,
	NextAttack: number,
	Pending: { at: number, position: Vector3, radius: number }?,
	ExpiresAt: number?,
	OnDeath: ((enemy: Enemy) -> ())?,
	GroundAt: Vector3?, -- last ground probe (reused while the goal barely moves)
	GroundY: number?,
}

local spawners: { Spawner } = {}
local enemies: { [Enemy]: boolean } = {}
local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function count(): number
	local n = 0
	for _ in enemies do
		n += 1
	end
	return n
end

local function groundY(position: Vector3, H: number): number?
	local origin = position + Vector3.new(0, H * 3, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -H * 12, 0), rayParams)
	return if result then result.Position.Y else nil
end

local function setTarget(enemy: Enemy, position: Vector3)
	local flyer = enemy.Def.Behavior == "Flyer"
	local y: number?
	local last = enemy.GroundAt
	if last and Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude < enemy.H * 0.75 then
		y = enemy.GroundY
	else
		y = groundY(position, enemy.H)
		enemy.GroundAt = position
		enemy.GroundY = y
	end
	local hover = if flyer then enemy.H * 2.2 else enemy.H * 0.5
	local targetY = if y then y + hover else enemy.Root.Position.Y
	enemy.Align.Position = Vector3.new(position.X, targetY, position.Z)
	local flat = Vector3.new(position.X - enemy.Root.Position.X, 0, position.Z - enemy.Root.Position.Z)
	if flat.Magnitude > enemy.H * 0.05 then
		enemy.Orient.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
	end
end

local function playerScale(player: Player): number
	return ScaleService:GetScale(player)
end

-- Safe zones around spawns and fast-travel pads (built in Start).
local safeZones: { { Position: Vector3, Radius: number } } = {}

local function inSafeZone(position: Vector3): boolean
	for _, zone in safeZones do
		local d = position - zone.Position
		if Vector3.new(d.X, 0, d.Z).Magnitude < zone.Radius then
			return true
		end
	end
	return false
end

-- Picks the closest valid player within detect range.
local function findTarget(enemy: Enemy): Player?
	local best: Player? = nil
	local bestDist = enemy.Def.DetectRange * enemy.H
	for _, player in Players:GetPlayers() do
		local root = CharacterService:GetRoot(player)
		if root then
			local scale = playerScale(player)
			if scale <= enemy.Def.Scale * EnemyConfig.IgnoreSizeRatio then
				local d = (root.Position - enemy.Root.Position).Magnitude - ScaleMath.height(scale) * 0.5
				if
					d < bestDist
					and (root.Position - enemy.Home).Magnitude < enemy.LeashRadius * 1.2
					and not inSafeZone(root.Position)
				then
					best = player
					bestDist = d
				end
			end
		end
	end
	return best
end

local function kill(enemy: Enemy, killer: Player?)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	enemy.Unregister()
	local position = enemy.Root.Position
	Net.fx("EnemyDeath", { P = position, S = enemy.Def.Scale, C = enemy.Def.Color })
	-- Rewards: every player who dealt a meaningful share.
	local total = 0
	for _, dmg in enemy.Damage do
		total += dmg
	end
	for player, dmg in enemy.Damage do
		if player.Parent and (player == killer or (total > 0 and dmg / total >= 0.15)) then
			local factor = CombatMath.rewardFactor(playerScale(player), enemy.Def.Scale) * enemy.RewardMultiplier
			local reward = RewardService:ScaleZone(enemy.Def.Rewards, enemy.Zone, factor)
			RewardService:Grant(player, reward, { Source = "Enemy", SourceId = enemy.Def.Id, Position = position })
			StatisticsService:Increment(player, "EnemiesDefeated")
			GameEvents.fire("EnemyDefeated", player, enemy.Def.Id, enemy.Zone)
			-- Party members nearby share quest credit (not rewards).
			for _, member in PartyService:NearbyMembers(player) do
				if not enemy.Damage[member] then
					GameEvents.fire("EnemyDefeated", member, enemy.Def.Id, enemy.Zone)
				end
			end
		end
	end
	if enemy.OnDeath then
		task.spawn(enemy.OnDeath, enemy)
	end
	enemies[enemy] = nil
	if enemy.Spawner then
		local list = enemy.Spawner.Alive
		local idx = table.find(list, enemy)
		if idx then
			table.remove(list, idx)
		end
		enemy.Spawner.NextSpawn = os.clock() + EnemyConfig.RespawnDelay
	end
	task.delay(0.25, function()
		enemy.Model:Destroy()
	end)
end

local function despawn(enemy: Enemy)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	enemy.Unregister()
	enemies[enemy] = nil
	enemy.Model:Destroy()
end

export type SpawnOptions = {
	RewardMultiplier: number?,
	Lifetime: number?,
	LeashRadius: number?,
	Spawner: any?,
	OnDeath: ((enemy: Enemy) -> ())?,
	HealthMultiplier: number?,
}

function EnemyService:Spawn(enemyId: string, position: Vector3, options: SpawnOptions?): Enemy?
	local def = EnemyConfig.get(enemyId)
	if not def or count() >= EnemyConfig.MaxEnemiesPerServer then
		return nil
	end
	local opts: SpawnOptions = options or {}
	local H = ScaleMath.height(def.Scale)
	local model = CreatureBuilder.build(def.Id, def.Shape, def.Color, def.Scale)
	local root = model.PrimaryPart :: BasePart
	local y = groundY(position, H)
	local start =
		Vector3.new(position.X, (y or position.Y) + H * (if def.Behavior == "Flyer" then 2.2 else 0.5), position.Z)
	model:PivotTo(CFrame.new(start))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = GameConfig.EnemyGroup
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxForce = math.huge
	align.MaxVelocity = def.Speed * H
	align.Responsiveness = 25
	align.Position = start
	align.Parent = root
	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.MaxTorque = math.huge
	orient.Responsiveness = 18
	orient.Parent = root
	local health = def.Health * (opts.HealthMultiplier or 1)
	model:SetAttribute("EnemyId", def.Id)
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", health)
	model:SetAttribute("Scale", def.Scale)
	CollectionService:AddTag(model, "Enemy")
	model.Parent = folder
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local zone = ZoneConfig.zoneAt(start)
	local enemy: Enemy
	enemy = {
		Def = def,
		Model = model,
		Root = root,
		Align = align,
		Orient = orient,
		H = H,
		Health = health,
		MaxHealth = health,
		State = "Idle",
		StateUntil = 0,
		Target = nil,
		Home = start,
		LeashRadius = opts.LeashRadius or H * 30,
		Zone = if zone then zone.Id else def.Zone,
		Damage = {},
		RewardMultiplier = opts.RewardMultiplier or 1,
		Spawner = opts.Spawner,
		Unregister = function() end,
		Dead = false,
		NextAttack = 0,
		Pending = nil,
		ExpiresAt = if opts.Lifetime then os.clock() + opts.Lifetime else nil,
		OnDeath = opts.OnDeath,
	}
	enemy.Unregister = CombatService:RegisterTarget({
		Id = def.Id,
		Kind = "Enemy",
		GetPosition = function()
			return root.Position
		end,
		GetScale = function()
			return def.Scale
		end,
		Radius = H * 0.5,
		IsBoss = false,
		CanBeHitBy = nil,
		Damage = function(player, amount, _kind, _crit)
			if enemy.Dead then
				return
			end
			enemy.Health -= amount
			enemy.Damage[player] = (enemy.Damage[player] or 0) + amount
			model:SetAttribute("Health", math.max(0, enemy.Health))
			if enemy.Health <= 0 then
				kill(enemy, player)
			else
				enemy.State = "Stagger"
				enemy.StateUntil = os.clock() + EnemyConfig.StaggerTime
				enemy.Target = enemy.Target or player
				enemy.Pending = nil
			end
		end,
		Stun = function(seconds)
			enemy.State = "Stagger"
			enemy.StateUntil = os.clock() + seconds
			enemy.Pending = nil
		end,
		Alive = function()
			return not enemy.Dead
		end,
	})
	enemies[enemy] = true
	return enemy
end

function EnemyService:Despawn(enemy: Enemy)
	despawn(enemy)
end

function EnemyService:Count(): number
	return count()
end

------------------------------------------------------------------ AI

local function attackResolve(enemy: Enemy)
	local pending = enemy.Pending
	enemy.Pending = nil
	if not pending then
		return
	end
	for _, player in Players:GetPlayers() do
		local root = CharacterService:GetRoot(player)
		if root then
			local scale = playerScale(player)
			local reach = pending.radius + ScaleMath.height(scale) * 0.4
			local flat = Vector3.new(root.Position.X - pending.position.X, 0, root.Position.Z - pending.position.Z)
			if
				flat.Magnitude <= reach
				and math.abs(root.Position.Y - pending.position.Y) <= reach + ScaleMath.height(scale)
			then
				CombatService:DamagePlayer(
					player,
					CombatMath.enemyDamage(enemy.Def.Damage, enemy.Def.Scale, scale, 0),
					enemy.Def.Name
				)
			end
		end
	end
end

local function beginAttack(enemy: Enemy, target: Player, targetRoot: BasePart, now: number)
	local def = enemy.Def
	local behavior = def.Behavior
	local windup = if behavior == "Ranged" then 0.8 elseif behavior == "Charger" then 0.6 else 0.45
	local position: Vector3
	local radius: number
	if behavior == "Ranged" then
		position = targetRoot.Position - Vector3.new(0, ScaleMath.height(playerScale(target)) * 0.5, 0)
		radius = math.max(enemy.H * 0.9, ScaleMath.height(playerScale(target)) * 0.8)
		Net.fx("Telegraph", { P = position, R = radius, T = windup, K = "Circle" })
	else
		local dir = (targetRoot.Position - enemy.Root.Position) * Vector3.new(1, 0, 1)
		local unit = if dir.Magnitude > 0 then dir.Unit else Vector3.new(0, 0, -1)
		position = enemy.Root.Position + unit * enemy.H * def.AttackRange * 0.6
		radius = enemy.H * def.AttackRange * 0.6
		Net.fx("EnemyWindup", { P = enemy.Root.Position, S = def.Scale, T = windup })
		if behavior == "Charger" then
			-- Lunge toward the target during the wind-up.
			task.delay(windup * 0.6, function()
				if not enemy.Dead then
					enemy.Align.MaxVelocity = def.Speed * enemy.H * 3
					setTarget(enemy, enemy.Root.Position + unit * enemy.H * 3)
					task.delay(0.5, function()
						if not enemy.Dead then
							enemy.Align.MaxVelocity = def.Speed * enemy.H
						end
					end)
				end
			end)
			position = enemy.Root.Position + unit * enemy.H * 2.4
		end
	end
	enemy.Pending = { at = now + windup, position = position, radius = radius }
	enemy.NextAttack = now + def.AttackCooldown
	enemy.State = "Attack"
	enemy.StateUntil = now + windup + 0.2
end

local function tick(enemy: Enemy, now: number)
	if enemy.Dead then
		return
	end
	if enemy.ExpiresAt and now > enemy.ExpiresAt then
		despawn(enemy)
		return
	end
	if not enemy.Root.Parent then
		despawn(enemy)
		return
	end
	local def = enemy.Def
	local pos = enemy.Root.Position
	if enemy.Pending and now >= enemy.Pending.at then
		attackResolve(enemy)
	end
	if enemy.State == "Stagger" or enemy.State == "Attack" then
		if now < enemy.StateUntil then
			return
		end
		enemy.State = "Chase"
	end
	-- Leash: return home and heal when dragged too far.
	if (pos - enemy.Home).Magnitude > enemy.LeashRadius then
		enemy.State = "Return"
		enemy.Target = nil
	end
	if enemy.State == "Return" then
		setTarget(enemy, enemy.Home)
		if (pos - enemy.Home).Magnitude < enemy.H * 2 then
			enemy.State = "Idle"
			enemy.Health = enemy.MaxHealth
			enemy.Model:SetAttribute("Health", enemy.Health)
			table.clear(enemy.Damage)
		end
		return
	end
	local target = enemy.Target
	local targetRoot = target and CharacterService:GetRoot(target)
	if
		not targetRoot
		or not target
		or playerScale(target) > def.Scale * EnemyConfig.IgnoreSizeRatio
		or inSafeZone(targetRoot.Position)
	then
		enemy.Target = findTarget(enemy)
		target = enemy.Target
		targetRoot = target and CharacterService:GetRoot(target)
	end
	if not target or not targetRoot then
		-- Patrol: wander around home.
		if now > enemy.StateUntil then
			local a = math.random() * math.pi * 2
			local r = math.random() * (if enemy.Spawner then enemy.Spawner.Radius else enemy.H * 6)
			setTarget(enemy, enemy.Home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			enemy.StateUntil = now + 2 + math.random() * 3
			enemy.State = "Patrol"
		end
		return
	end
	local dist = (targetRoot.Position - pos).Magnitude - ScaleMath.height(playerScale(target)) * 0.4
	if dist > def.DetectRange * enemy.H * 1.6 then
		enemy.Target = nil
		return
	end
	local range = def.AttackRange * enemy.H
	if def.Behavior == "Ranged" and dist < enemy.H * 2 then
		-- Keep distance.
		local away = (pos - targetRoot.Position) * Vector3.new(1, 0, 1)
		setTarget(enemy, pos + (if away.Magnitude > 0 then away.Unit else Vector3.new(1, 0, 0)) * enemy.H * 3)
		enemy.State = "Retreat"
	elseif dist <= range then
		setTarget(enemy, pos)
		if now >= enemy.NextAttack then
			beginAttack(enemy, target, targetRoot, now)
		end
	else
		enemy.State = "Chase"
		setTarget(enemy, targetRoot.Position)
	end
end

------------------------------------------------------------------ spawners

local function nearbyPlayer(spawner: Spawner): boolean
	local H = ScaleMath.height((EnemyConfig.get(spawner.EnemyId) :: Types.Enemy).Scale)
	local radius = spawner.Radius * EnemyConfig.ActivationRadiusMultiplier + H * 20
	for _, player in Players:GetPlayers() do
		local root = CharacterService:GetRoot(player)
		if
			root
			and (root.Position - spawner.Position).Magnitude < radius + ScaleMath.height(playerScale(player)) * 2
		then
			return true
		end
	end
	return false
end

local function updateSpawner(spawner: Spawner, now: number)
	if nearbyPlayer(spawner) then
		spawner.LastNearby = now
		spawner.Active = true
	elseif spawner.Active and now - spawner.LastNearby > EnemyConfig.SleepAfter then
		spawner.Active = false
		for _, enemy in table.clone(spawner.Alive) do
			despawn(enemy)
		end
		table.clear(spawner.Alive)
	end
	if spawner.Active and #spawner.Alive < spawner.Count and now >= spawner.NextSpawn then
		local a = math.random() * math.pi * 2
		local r = math.random() * spawner.Radius
		local enemy =
			EnemyService:Spawn(spawner.EnemyId, spawner.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), {
				Spawner = spawner,
				LeashRadius = spawner.Radius * EnemyConfig.LeashRadiusMultiplier + 20,
			})
		if enemy then
			table.insert(spawner.Alive, enemy)
		end
		spawner.NextSpawn = now + 0.5
	end
end

function EnemyService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	rayParams.FilterDescendantsInstances = { folder }
	for _, marker in CollectionService:GetTagged("EnemySpawner") do
		if marker:IsA("BasePart") then
			local enemyId = marker:GetAttribute("EnemyId")
			if type(enemyId) == "string" and EnemyConfig.get(enemyId) then
				local zone = ZoneConfig.zoneAt(marker.Position)
				table.insert(spawners, {
					Position = marker.Position,
					EnemyId = enemyId,
					Count = (marker:GetAttribute("Count") :: number?) or 3,
					Radius = (marker:GetAttribute("Radius") :: number?) or 20,
					Zone = if zone then zone.Id else "FloorWorld",
					Active = false,
					LastNearby = 0,
					Alive = {},
					NextSpawn = 0,
				})
			else
				Log.warn("Enemy", "spawner with unknown enemy", enemyId)
			end
		end
	end
end

function EnemyService:Start()
	for _, zone in ZoneConfig.Zones do
		local h = ScaleMath.height(SizeConfig.getTier(zone.RecommendedTiers[1]).Scale)
		table.insert(safeZones, { Position = zone.Spawn, Radius = h * EnemyConfig.SafeZoneHeights })
	end
	for _, pad in CollectionService:GetTagged("FastTravelStation") do
		local zone = ZoneConfig.get(pad:GetAttribute("StationId") :: string)
		if zone and pad:IsA("BasePart") then
			local h = ScaleMath.height(SizeConfig.getTier(zone.RecommendedTiers[1]).Scale)
			table.insert(safeZones, { Position = pad.Position, Radius = h * EnemyConfig.SafeZoneHeights * 0.6 })
		end
	end
	-- Character folders are excluded from ground raycasts as they appear.
	local function refreshFilter()
		local list: { Instance } = { folder }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(list, player.Character)
			end
		end
		rayParams.FilterDescendantsInstances = list
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(refreshFilter)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(refreshFilter)
	end
	Players.PlayerRemoving:Connect(function(player)
		for enemy in enemies do
			if enemy.Target == player then
				enemy.Target = nil
			end
			enemy.Damage[player] = nil
		end
		task.defer(refreshFilter)
	end)
	task.spawn(function()
		local spawnerTimer = 0
		while true do
			task.wait(EnemyConfig.AITickRate)
			local now = os.clock()
			spawnerTimer += EnemyConfig.AITickRate
			if spawnerTimer >= 1 then
				spawnerTimer = 0
				for _, spawner in spawners do
					local ok, err = pcall(function()
						updateSpawner(spawner, now)
					end)
					if not ok then
						Log.warn("Enemy", "spawner update failed", err)
					end
				end
			end
			for enemy in enemies do
				local ok, err = pcall(function()
					tick(enemy, now)
				end)
				if not ok then
					Log.warn("Enemy", "AI tick failed", err)
					despawn(enemy)
				end
			end
		end
	end)
end

return EnemyService
