--!strict
--[[
	BossService
	Five phased bosses built from shared attack primitives (BossConfig):
	Slam, Sweep, Charge, Shockwave (jump to dodge), Volley, Rain, Summon.
	Every attack is telegraphed to clients first and resolved on the server.

	Fight rules
	  * A fight starts when a living player enters the arena.
	  * Health scales with the number of participants (late joiners add HP).
	  * Damage only counts from inside the arena (no sniping from far away).
	  * Reset if no living participant is inside for ResetAfterEmpty seconds,
	    or after MaxBossTime; minions are cleaned up on reset/defeat.
	  * Rewards go to participants who were present for enough of the fight
	    OR dealt enough damage (no last-second tagging). First kills give the
	    special first-kill rewards; repeat kills inside the reward cooldown
	    pay a fraction, so bosses stay replayable without infinite farming.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossConfig = require(Shared.Config.BossConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Types = require(Shared.Types)
local CombatMath = require(Shared.Formulas.CombatMath)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local TableUtil = require(Shared.Util.TableUtil)
local Log = require(Shared.Util.Log)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local CreatureBuilder = require(ServerRoot.World.CreatureBuilder)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CharacterService = require(script.Parent.CharacterService)
local CombatService = require(script.Parent.CombatService)
local RewardService = require(script.Parent.RewardService)
local StatisticsService = require(script.Parent.StatisticsService)
local ScaleService = require(script.Parent.ScaleService)
local EnemyService = require(script.Parent.EnemyService)
local PartyService = require(script.Parent.PartyService)

local BossService = {}

type Participant = { Present: number, Damage: number }
type Pending = { at: number, resolve: () -> () }

type Fight = {
	Def: Types.Boss,
	Center: Vector3,
	Radius: number,
	H: number,
	State: string, -- Waiting | Fighting | Defeated
	Model: Model?,
	Root: BasePart?,
	Align: AlignPosition?,
	Orient: AlignOrientation?,
	Health: number,
	MaxHealth: number,
	Phase: number,
	NextAttack: number,
	StartedAt: number,
	LastOccupied: number,
	RespawnAt: number,
	Participants: { [Player]: Participant },
	PeakParticipants: number,
	Pending: { Pending },
	Minions: { any },
	Target: Player?,
	RetargetAt: number,
	Unregister: () -> (),
	LastBroadcast: number,
	Stunned: number,
}

local fights: { [string]: Fight } = {}
local rng = Random.new()

local function scaleOf(player: Player): number
	return ScaleService:GetScale(player)
end

local function insideArena(fight: Fight, position: Vector3, margin: number?): boolean
	local flat = Vector3.new(position.X - fight.Center.X, 0, position.Z - fight.Center.Z)
	return flat.Magnitude <= fight.Radius * (margin or 1)
		and math.abs(position.Y - fight.Center.Y) <= fight.Radius * 1.5 + fight.H * 2
end

-- Bosses only engage players big enough for the fight; smaller players can
-- walk through an arena safely (and are told why nothing happens).
local function eligible(fight: Fight, player: Player): boolean
	return ((player:GetAttribute("Tier") :: number?) or 1) >= fight.Def.RequiredTier
end

local tooSmallWarned: { [Player]: number } = {}

local function livingInside(fight: Fight): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		local root = CharacterService:GetRoot(player)
		if root and insideArena(fight, root.Position) then
			if eligible(fight, player) then
				table.insert(out, player)
			elseif os.clock() - (tooSmallWarned[player] or 0) > 30 then
				tooSmallWarned[player] = os.clock()
				Net.signal(player, "Notify", {
					Kind = "Info",
					Text = string.format(
						"%s ignores you — grow to %s to challenge it.",
						fight.Def.Name,
						SizeConfig.getTier(fight.Def.RequiredTier).Name
					),
				})
			end
		end
	end
	return out
end

local function currentPhase(fight: Fight): Types.BossPhase
	local fraction = fight.Health / math.max(1, fight.MaxHealth)
	local chosen = fight.Def.Phases[1]
	local index = 1
	for i, phase in fight.Def.Phases do
		if fraction <= phase.HealthBelow then
			chosen = phase
			index = i
		end
	end
	if index ~= fight.Phase then
		fight.Phase = index
		Net.fx("BossPhase", { Id = fight.Def.Id, Name = chosen.Name, P = fight.Center })
		fight.Stunned = os.clock() + 1.2
	end
	return chosen
end

local function broadcast(fight: Fight, state: string?)
	local phase = fight.Def.Phases[fight.Phase]
	local payload = {
		Id = fight.Def.Id,
		Name = fight.Def.Name,
		Title = fight.Def.Title,
		State = state or fight.State,
		Health = math.max(0, math.floor(fight.Health)),
		Max = math.floor(fight.MaxHealth),
		Phase = if phase then phase.Name else "",
	}
	for _, player in Players:GetPlayers() do
		local root = CharacterService:GetRoot(player)
		if root and insideArena(fight, root.Position, 1.6) then
			Net.signal(player, "Boss", payload)
		end
	end
end

local function damagePlayersIn(fight: Fight, test: (root: BasePart, player: Player) -> boolean, damage: number)
	for player in fight.Participants do
		local root = CharacterService:GetRoot(player)
		if root and test(root, player) then
			CombatService:DamagePlayer(
				player,
				CombatMath.enemyDamage(damage, fight.Def.Scale, scaleOf(player), 0),
				fight.Def.Name
			)
		end
	end
end

local function feet(player: Player, root: BasePart): Vector3
	return root.Position - Vector3.new(0, ScaleMath.height(scaleOf(player)) * 0.5, 0)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function schedule(fight: Fight, delay: number, resolve: () -> ())
	table.insert(fight.Pending, { at = os.clock() + delay, resolve = resolve })
end

local function randomParticipant(fight: Fight): (Player?, BasePart?)
	local list = {}
	for player in fight.Participants do
		local root = CharacterService:GetRoot(player)
		if root and insideArena(fight, root.Position) then
			table.insert(list, player)
		end
	end
	if #list == 0 then
		return nil, nil
	end
	local player = list[rng:NextInteger(1, #list)]
	return player, CharacterService:GetRoot(player)
end

------------------------------------------------------------------ attacks

local attacks: { [string]: (fight: Fight, atk: Types.BossAttack) -> () } = {}

attacks.Slam = function(fight, atk)
	local player, root = randomParticipant(fight)
	if not player or not root then
		return
	end
	local center = feet(player, root)
	local radius = (atk.Radius or 1) * fight.H
	Net.fx("Telegraph", { P = center, R = radius, T = atk.Telegraph, K = "Circle" })
	schedule(fight, atk.Telegraph, function()
		Net.fx("BossImpact", { P = center, R = radius })
		damagePlayersIn(fight, function(r, p)
			return flatDistance(feet(p, r), center) <= radius + ScaleMath.height(scaleOf(p)) * 0.3
		end, atk.Damage)
	end)
end

attacks.Sweep = function(fight, atk)
	local root = fight.Root
	local _, targetRoot = randomParticipant(fight)
	if not root or not targetRoot then
		return
	end
	local origin = root.Position
	local dir = (targetRoot.Position - origin) * Vector3.new(1, 0, 1)
	local facing = if dir.Magnitude > 0 then dir.Unit else Vector3.new(0, 0, -1)
	local radius = (atk.Radius or 2) * fight.H
	Net.fx("Telegraph", { P = origin, R = radius, T = atk.Telegraph, K = "Cone", D = facing, A = 120 })
	schedule(fight, atk.Telegraph, function()
		damagePlayersIn(fight, function(r)
			return CombatMath.inArc(origin, facing, r.Position, radius, 120)
		end, atk.Damage)
	end)
end

attacks.Charge = function(fight, atk)
	local root = fight.Root
	local _, targetRoot = randomParticipant(fight)
	if not root or not targetRoot or not fight.Align then
		return
	end
	local origin = root.Position
	local dir = (targetRoot.Position - origin) * Vector3.new(1, 0, 1)
	local facing = if dir.Magnitude > 0 then dir.Unit else Vector3.new(0, 0, -1)
	local length = math.min(fight.Radius * 1.6, math.max(dir.Magnitude * 1.3, fight.H * 4))
	local width = math.max((atk.Radius or 0.5) * fight.H * 2, fight.H * 0.8)
	Net.fx("Telegraph", { P = origin, R = width / 2, T = atk.Telegraph, K = "Lane", D = facing, L = length })
	schedule(fight, atk.Telegraph, function()
		local align = fight.Align
		if not align then
			return
		end
		local finish = origin + facing * length
		-- Stay inside the arena.
		local flat = Vector3.new(finish.X - fight.Center.X, 0, finish.Z - fight.Center.Z)
		if flat.Magnitude > fight.Radius * 0.9 then
			finish = fight.Center + flat.Unit * fight.Radius * 0.9 + Vector3.new(0, finish.Y - fight.Center.Y, 0)
		end
		align.MaxVelocity = fight.Def.Speed * fight.H * 6
		align.Position = Vector3.new(finish.X, align.Position.Y, finish.Z)
		fight.Stunned = os.clock() + 0.9
		damagePlayersIn(fight, function(r)
			local rel = r.Position - origin
			local along = rel:Dot(facing)
			local side = (rel - facing * along) * Vector3.new(1, 0, 1)
			return along >= -fight.H * 0.5 and along <= length and side.Magnitude <= width / 2 + fight.H * 0.2
		end, atk.Damage)
		task.delay(0.8, function()
			if fight.Align then
				fight.Align.MaxVelocity = fight.Def.Speed * fight.H
			end
		end)
	end)
end

attacks.Shockwave = function(fight, atk)
	local root = fight.Root
	if not root then
		return
	end
	local origin = root.Position
	local radius = (atk.Radius or 3) * fight.H
	local groundY = origin.Y - fight.H * 0.5
	Net.fx("Telegraph", { P = origin - Vector3.new(0, fight.H * 0.5, 0), R = radius, T = atk.Telegraph, K = "Ring" })
	schedule(fight, atk.Telegraph, function()
		Net.fx("BossShockwave", { P = origin, R = radius })
		-- Airborne players (jumping) dodge the ground wave.
		damagePlayersIn(fight, function(r, p)
			local f = feet(p, r)
			return flatDistance(f, origin) <= radius and f.Y <= groundY + ScaleMath.height(scaleOf(p)) * 0.35
		end, atk.Damage)
	end)
end

attacks.Volley = function(fight, atk)
	for i = 1, atk.Count or 4 do
		local player, root = randomParticipant(fight)
		if player and root then
			local center = feet(player, root)
			local radius = math.max(fight.H * 0.25, ScaleMath.height(scaleOf(player)) * 0.7)
			local delay = atk.Telegraph + (i - 1) * 0.15
			Net.fx("Telegraph", { P = center, R = radius, T = delay, K = "Circle" })
			schedule(fight, delay, function()
				damagePlayersIn(fight, function(r, p)
					return flatDistance(feet(p, r), center) <= radius
				end, atk.Damage)
			end)
		end
	end
end

attacks.Rain = function(fight, atk)
	local radius = (atk.Radius or 0.5) * fight.H
	for i = 1, atk.Count or 8 do
		local a = rng:NextNumber() * math.pi * 2
		local d = math.sqrt(rng:NextNumber()) * fight.Radius * 0.9
		local center = fight.Center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local delay = atk.Telegraph + i * 0.08
		Net.fx("Telegraph", { P = center, R = radius, T = delay, K = "Circle" })
		schedule(fight, delay, function()
			damagePlayersIn(fight, function(r, p)
				return flatDistance(feet(p, r), center) <= radius + ScaleMath.height(scaleOf(p)) * 0.25
			end, atk.Damage)
		end)
	end
end

attacks.Summon = function(fight, atk)
	if not atk.Minion or #fight.Minions >= 8 then
		return
	end
	Net.fx("BossSummon", { P = fight.Center, Id = fight.Def.Id })
	schedule(fight, atk.Telegraph, function()
		for i = 1, atk.Count or 2 do
			local a = i / (atk.Count or 2) * math.pi * 2
			local p = fight.Center + Vector3.new(math.cos(a), 0, math.sin(a)) * fight.Radius * 0.5
			local minion = EnemyService:Spawn(atk.Minion :: string, p, {
				RewardMultiplier = 0.25,
				Lifetime = 90,
				LeashRadius = fight.Radius,
			})
			if minion then
				table.insert(fight.Minions, minion)
			end
		end
	end)
end

------------------------------------------------------------------ lifecycle

local function clearMinions(fight: Fight)
	for _, minion in fight.Minions do
		EnemyService:Despawn(minion)
	end
	table.clear(fight.Minions)
end

local function spawnBoss(fight: Fight)
	local def = fight.Def
	local model = CreatureBuilder.build(def.Id, def.Shape, def.Color, def.Scale)
	local root = model.PrimaryPart :: BasePart
	local start = fight.Center + Vector3.new(0, fight.H * 0.5, 0)
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
	align.MaxVelocity = def.Speed * fight.H
	align.Responsiveness = 20
	align.Position = start
	align.Parent = root
	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.MaxTorque = math.huge
	orient.Responsiveness = 12
	orient.Parent = root
	model:SetAttribute("BossId", def.Id)
	model:SetAttribute("Health", def.BaseHealth)
	model:SetAttribute("MaxHealth", def.BaseHealth)
	CollectionService:AddTag(model, "Boss")
	model.Parent = workspace:FindFirstChild("Enemies") or workspace
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	fight.Model = model
	fight.Root = root
	fight.Align = align
	fight.Orient = orient
	fight.Health = def.BaseHealth
	fight.MaxHealth = def.BaseHealth
	fight.Phase = 1
	fight.State = "Waiting"
	fight.Participants = {}
	fight.PeakParticipants = 0
	table.clear(fight.Pending)
	fight.Unregister = CombatService:RegisterTarget({
		Id = def.Id,
		Kind = "Boss",
		GetPosition = function()
			return root.Position
		end,
		GetScale = function()
			return def.Scale
		end,
		Radius = fight.H * 0.6,
		IsBoss = true,
		CanBeHitBy = function(player, origin)
			return insideArena(fight, origin, BossConfig.ArenaDamageMargin)
				and (fight.State == "Fighting" or fight.State == "Waiting")
				and player.Parent ~= nil
				and eligible(fight, player)
		end,
		Damage = function(player, amount)
			if fight.State == "Waiting" then
				return
			end
			if fight.State ~= "Fighting" then
				return
			end
			local p = fight.Participants[player]
			if not p then
				p = { Present = 0, Damage = 0 }
				fight.Participants[player] = p
			end
			p.Damage += amount
			fight.Health -= amount
			model:SetAttribute("Health", math.max(0, fight.Health))
		end,
		Stun = function(seconds)
			fight.Stunned = os.clock() + math.min(seconds, 1.5) -- bosses resist long stuns
		end,
		Alive = function()
			return fight.State ~= "Defeated" and model.Parent ~= nil
		end,
	})
end

local function reset(fight: Fight, reason: string)
	Log.debug("Boss", fight.Def.Id, "reset:", reason)
	broadcast(fight, "Reset")
	clearMinions(fight)
	table.clear(fight.Pending)
	fight.State = "Waiting"
	fight.Health = fight.Def.BaseHealth
	fight.MaxHealth = fight.Def.BaseHealth
	fight.Phase = 1
	fight.Participants = {}
	fight.PeakParticipants = 0
	if fight.Model then
		fight.Model:SetAttribute("Health", fight.Health)
		fight.Model:SetAttribute("MaxHealth", fight.MaxHealth)
	end
	if fight.Align then
		fight.Align.Position = fight.Center + Vector3.new(0, fight.H * 0.5, 0)
	end
end

local function rewardParticipants(fight: Fight)
	local def = fight.Def
	local duration = math.max(1, os.clock() - fight.StartedAt)
	local totalDamage = 0
	for _, p in fight.Participants do
		totalDamage += p.Damage
	end
	local now = os.time()
	for player, p in fight.Participants do
		local data = PlayerDataService:Get(player)
		if data and player.Parent then
			local qualifies = p.Present / duration >= BossConfig.MinParticipation
				or (totalDamage > 0 and p.Damage / totalDamage >= BossConfig.MinDamageShare)
			if qualifies then
				local record = data.Bosses[def.Id]
				if not record then
					record = { Kills = 0, BestTime = 0, LastRewardAt = 0 }
					data.Bosses[def.Id] = record
				end
				local firstKill = record.Kills == 0
				local fresh = now - record.LastRewardAt >= def.RewardCooldown
				record.Kills += 1
				if record.BestTime == 0 or duration < record.BestTime then
					record.BestTime = math.floor(duration * 10) / 10
				end
				local factor = (if fresh then 1 else BossConfig.RepeatRewardFraction)
					* CombatMath.rewardFactor(scaleOf(player), def.Scale)
				if fresh then
					record.LastRewardAt = now
				end
				PlayerDataService:Changed(player, "Bosses")
				local reward = RewardService:ScaleZone(def.Rewards, def.Zone, factor)
				if not fresh then
					-- Repeat kill inside the cooldown: fractional shards, no resources.
					local copy: any = table.clone(reward :: any)
					copy.TitanShards = math.floor((def.Rewards.TitanShards or 0) * BossConfig.RepeatRewardFraction)
					copy.Resources = nil
					reward = copy
				end
				RewardService:Grant(player, reward, { Source = "Boss", SourceId = def.Id })
				if firstKill then
					RewardService:Grant(player, def.FirstKillRewards, { Source = "BossFirstKill", SourceId = def.Id })
				end
				StatisticsService:Increment(player, "BossesDefeated")
				GameEvents.fire("BossDefeated", player, def.Id)
				for _, member in PartyService:NearbyMembers(player) do
					if not fight.Participants[member] then
						GameEvents.fire("BossDefeated", member, def.Id)
					end
				end
			end
		end
	end
end

local function defeat(fight: Fight)
	fight.State = "Defeated"
	broadcast(fight, "Defeated")
	Net.fx(
		"BossDefeat",
		{ P = if fight.Root then fight.Root.Position else fight.Center, S = fight.Def.Scale, Id = fight.Def.Id }
	)
	clearMinions(fight)
	table.clear(fight.Pending)
	rewardParticipants(fight)
	fight.Unregister()
	local model = fight.Model
	fight.Model = nil
	fight.Root = nil
	fight.Align = nil
	fight.Orient = nil
	if model then
		task.delay(1.5, function()
			model:Destroy()
		end)
	end
	fight.RespawnAt = os.clock() + BossConfig.RespawnDelay
end

local function tick(fight: Fight, now: number, dt: number)
	if fight.State == "Defeated" then
		if now >= fight.RespawnAt then
			spawnBoss(fight)
		end
		return
	end
	local inside = livingInside(fight)
	if fight.State == "Waiting" then
		if #inside > 0 then
			fight.State = "Fighting"
			fight.StartedAt = now
			fight.LastOccupied = now
			fight.NextAttack = now + 2.5
			Net.fx("BossIntro", { Id = fight.Def.Id, P = fight.Center, S = fight.Def.Scale })
			broadcast(fight, "Start")
		else
			return
		end
	end
	-- Fighting.
	if #inside > 0 then
		fight.LastOccupied = now
	elseif now - fight.LastOccupied > BossConfig.ResetAfterEmpty then
		reset(fight, "empty")
		return
	end
	if now - fight.StartedAt > BossConfig.MaxBossTime then
		reset(fight, "timeout")
		return
	end
	for _, player in inside do
		local p = fight.Participants[player]
		if not p then
			p = { Present = 0, Damage = 0 }
			fight.Participants[player] = p
		end
		p.Present += dt
	end
	-- Health scales with the peak number of participants.
	local n = TableUtil.count(fight.Participants)
	if n > fight.PeakParticipants then
		local newMax = fight.Def.BaseHealth * (1 + fight.Def.HealthPerPlayer * (n - 1))
		fight.Health += newMax - fight.MaxHealth
		fight.MaxHealth = newMax
		fight.PeakParticipants = n
		if fight.Model then
			fight.Model:SetAttribute("MaxHealth", newMax)
		end
	end
	if fight.Health <= 0 then
		defeat(fight)
		return
	end
	-- Resolve due attacks.
	local i = 1
	while i <= #fight.Pending do
		local pending = fight.Pending[i]
		if now >= pending.at then
			table.remove(fight.Pending, i)
			local ok, err = pcall(function()
				pending.resolve()
			end)
			if not ok then
				Log.warn("Boss", "attack resolve failed", err)
			end
		else
			i += 1
		end
	end
	local phase = currentPhase(fight)
	local root = fight.Root
	local align = fight.Align
	if not root or not align then
		return
	end
	-- Movement toward a participant, clamped inside the arena.
	if now >= fight.Stunned then
		if now >= fight.RetargetAt or not fight.Target then
			fight.Target = randomParticipant(fight)
			fight.RetargetAt = now + 4
		end
		local target = fight.Target
		local targetRoot = target and CharacterService:GetRoot(target)
		if targetRoot then
			local goal = targetRoot.Position
			local flat = Vector3.new(goal.X - fight.Center.X, 0, goal.Z - fight.Center.Z)
			if flat.Magnitude > fight.Radius * 0.85 then
				goal = fight.Center + flat.Unit * fight.Radius * 0.85
			end
			align.MaxVelocity = fight.Def.Speed * fight.H * phase.SpeedMultiplier
			align.Position = Vector3.new(goal.X, fight.Center.Y + fight.H * 0.5, goal.Z)
			local dir = (goal - root.Position) * Vector3.new(1, 0, 1)
			if dir.Magnitude > 1 and fight.Orient then
				fight.Orient.CFrame = CFrame.lookAt(Vector3.zero, dir.Unit)
			end
		end
		-- Attack selection.
		if now >= fight.NextAttack then
			local atk = TableUtil.weightedPick(phase.Attacks, function(a)
				return a.Weight
			end, function()
				return rng:NextNumber()
			end)
			if atk then
				local fn = attacks[atk.Kind]
				if fn then
					fn(fight, atk)
				end
			end
			fight.NextAttack = now + phase.AttackInterval / phase.SpeedMultiplier
		end
	end
	-- Contact damage.
	damagePlayersIn(fight, function(r)
		return (r.Position - root.Position).Magnitude <= fight.H * 0.6
	end, fight.Def.ContactDamage)
	if now - fight.LastBroadcast > 0.5 then
		fight.LastBroadcast = now
		broadcast(fight)
	end
end

function BossService:GetFight(bossId: string): Fight?
	return fights[bossId]
end

-- Admin / events: force a boss to respawn immediately.
function BossService:ForceSpawn(bossId: string): boolean
	local fight = fights[bossId]
	if not fight then
		return false
	end
	if fight.State == "Defeated" then
		spawnBoss(fight)
	else
		reset(fight, "admin")
	end
	return true
end

function BossService:Init()
	for _, marker in CollectionService:GetTagged("BossArena") do
		if marker:IsA("BasePart") then
			local id = marker:GetAttribute("BossId")
			local def = if type(id) == "string" then BossConfig.get(id) else nil
			if def then
				local H = ScaleMath.height(def.Scale)
				fights[def.Id] = {
					Def = def,
					Center = marker.Position,
					Radius = (marker:GetAttribute("Radius") :: number?) or def.ArenaRadius * H,
					H = H,
					State = "Defeated",
					Model = nil,
					Root = nil,
					Align = nil,
					Orient = nil,
					Health = def.BaseHealth,
					MaxHealth = def.BaseHealth,
					Phase = 1,
					NextAttack = 0,
					StartedAt = 0,
					LastOccupied = 0,
					RespawnAt = 0,
					Participants = {},
					PeakParticipants = 0,
					Pending = {},
					Minions = {},
					Target = nil,
					RetargetAt = 0,
					Unregister = function() end,
					LastBroadcast = 0,
					Stunned = 0,
				}
			end
		end
	end
end

function BossService:Start()
	Players.PlayerRemoving:Connect(function(player)
		tooSmallWarned[player] = nil
		for _, fight in fights do
			fight.Participants[player] = nil
			if fight.Target == player then
				fight.Target = nil
			end
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, fight in fights do
				local ok, err = pcall(function()
					tick(fight, now, dt)
				end)
				if not ok then
					Log.error("Boss", fight.Def.Id, "tick failed:", err)
					pcall(function()
						reset(fight, "error")
					end)
				end
			end
		end
	end)
end

return BossService
