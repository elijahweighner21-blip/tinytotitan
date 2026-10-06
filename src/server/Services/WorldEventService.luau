--!strict
--[[
	WorldEventService
	Randomised server events (WorldEventConfig). The scheduler picks an
	eligible event every few minutes, announces it to everyone, runs its
	handler and ALWAYS cleans up through the event's Trove — spawned parts,
	enemies, modifiers and loops are released when the event ends, errors, or
	is replaced, so the next event starts from a clean slate.

	Participation (collecting an event pickup, hitting the supply crate,
	defeating invasion bugs...) fires GameEvents.EventJoined once per player
	per event, which feeds daily/weekly objectives and achievements.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldEventConfig = require(Shared.Config.WorldEventConfig)
local EnemyConfig = require(Shared.Config.EnemyConfig)
local RewardConfig = require(Shared.Config.RewardConfig)
local Types = require(Shared.Types)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local TableUtil = require(Shared.Util.TableUtil)
local Trove = require(Shared.Util.Trove)
local Log = require(Shared.Util.Log)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local CharacterService = require(script.Parent.CharacterService)
local RewardService = require(script.Parent.RewardService)
local GlobalModifierService = require(script.Parent.GlobalModifierService)
local EnemyService = require(script.Parent.EnemyService)
local CombatService = require(script.Parent.CombatService)
local ScaleService = require(script.Parent.ScaleService)
local ProgressionService = require(script.Parent.ProgressionService)
local ZoneService = require(script.Parent.ZoneService)
local StatisticsService = require(script.Parent.StatisticsService)
local HazardService = require(script.Parent.HazardService)

local WorldEventService = {}

type Pickup = {
	Id: string,
	Position: Vector3,
	Radius: number,
	Reward: (player: Player) -> Types.Reward,
	Collected: { [Player]: boolean },
	Part: BasePart?,
}

type ActiveEvent = {
	Def: WorldEventConfig.WorldEvent,
	Trove: Trove.Trove,
	EndsAt: number,
	Joined: { [Player]: boolean },
	Pickups: { Pickup },
}

local active: ActiveEvent? = nil
local rng = Random.new()
local pickupCounter = 0

------------------------------------------------------------------ helpers

local function join(event: ActiveEvent, player: Player)
	if event.Joined[player] then
		return
	end
	event.Joined[player] = true
	StatisticsService:Increment(player, "EventsJoined")
	GameEvents.fire("EventJoined", player, event.Def.Id)
end

local function playersIn(zones: { string }?): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if CharacterService:IsAlive(player) then
			local zone = ZoneService:GetZone(player)
			if not zones or (zone and table.find(zones, zone)) then
				table.insert(out, player)
			end
		end
	end
	return out
end

local function zoneOf(player: Player): string
	return ZoneService:GetZone(player) or "FloorWorld"
end

-- A ground point near a player, scaled to their size.
local function pointNear(player: Player, minBodies: number, maxBodies: number): (Vector3?, number)
	local root = CharacterService:GetRoot(player)
	if not root then
		return nil, 1
	end
	local h = ScaleMath.height(ScaleService:GetScale(player))
	local a = rng:NextNumber() * math.pi * 2
	local d = rng:NextNumber(minBodies, maxBodies) * h
	local origin = root.Position + Vector3.new(math.cos(a) * d, h * 4, math.sin(a) * d)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(origin, Vector3.new(0, -h * 30, 0), params)
	return if hit then hit.Position else root.Position - Vector3.new(0, h * 0.5, 0), h
end

local function addPickup(
	event: ActiveEvent,
	position: Vector3,
	size: number,
	color: Color3,
	reward: (player: Player) -> Types.Reward
): Pickup
	pickupCounter += 1
	local part = Instance.new("Part")
	part.Name = "EventPickup"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Position = position + Vector3.new(0, size * 0.6, 0)
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part:SetAttribute("PickupId", "EV_" .. pickupCounter)
	part.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.clamp(size * 4, 4, 60)
	light.Parent = part
	event.Trove:Add(part)
	local pickup: Pickup = {
		Id = "EV_" .. pickupCounter,
		Position = part.Position,
		Radius = size * 1.5,
		Reward = reward,
		Collected = {},
		Part = part,
	}
	table.insert(event.Pickups, pickup)
	return pickup
end

local function zoneReward(zoneId: string, weight: number): Types.Reward
	return RewardConfig.zone(zoneId, weight)
end

------------------------------------------------------------------ handlers

local handlers: { [string]: (event: ActiveEvent) -> () } = {}

handlers.GrowthSurge = function(event)
	local id = "Event:GrowthSurge"
	GlobalModifierService:Set(id, {
		Source = "Event:GrowthSurge",
		Currency = "Mass",
		Kind = "Additive",
		Value = event.Def.Params.MassBonus :: number,
	}, event.Def.Name, event.Def.Duration)
	event.Trove:Add(function()
		GlobalModifierService:Clear(id)
	end)
	for _, player in Players:GetPlayers() do
		join(event, player)
	end
end

handlers.GoldenCrumb = function(event)
	-- One golden crumb near each active zone's players (shared per zone).
	local placed: { [string]: boolean } = {}
	for _, player in playersIn(nil) do
		local zone = zoneOf(player)
		if not placed[zone] then
			placed[zone] = true
			local point, h = pointNear(player, 6, 14)
			if point then
				addPickup(event, point, h * 0.8, Color3.fromRGB(255, 210, 60), function(p)
					return zoneReward(zoneOf(p), event.Def.Params.RewardWeight :: number)
				end)
			end
		end
	end
end

handlers.BugInvasion = function(event)
	local zones = event.Def.Zones
	local count = event.Def.Params.Count :: number
	local mult = event.Def.Params.RewardMultiplier :: number
	local targets = playersIn(zones)
	if #targets == 0 then
		return
	end
	local spawned = 0
	for i = 1, count do
		local player = targets[(i - 1) % #targets + 1]
		local zone = zoneOf(player)
		local candidates = TableUtil.filter(EnemyConfig.List, function(e)
			return e.Zone == zone
		end)
		if #candidates > 0 then
			local def = candidates[rng:NextInteger(1, #candidates)]
			local point = pointNear(player, 5, 12)
			if point then
				local enemy = EnemyService:Spawn(def.Id, point, {
					RewardMultiplier = mult,
					Lifetime = event.Def.Duration,
					LeashRadius = ScaleMath.height(def.Scale) * 60,
					OnDeath = function(e)
						for damager in e.Damage do
							join(event, damager)
						end
					end,
				})
				if enemy then
					spawned += 1
					event.Trove:Add(function()
						EnemyService:Despawn(enemy)
					end)
				end
			end
		end
	end
	Log.debug("WorldEvent", "bug invasion spawned", spawned)
end

handlers.MeteorFragment = function(event)
	local candidates = playersIn(nil)
	if #candidates == 0 then
		return
	end
	local player = candidates[rng:NextInteger(1, #candidates)]
	local point, h = pointNear(player, 10, 25)
	if not point then
		return
	end
	local zone = zoneOf(player)
	Net.signalAll("WorldEvent", { State = "Marker", Id = event.Def.Id, Position = point, Radius = h * 3 })
	Net.fx("Meteor", { P = point, S = h, T = 8 })
	event.Trove:Add(task.delay(8, function()
		Net.fx("BossImpact", { P = point, R = h * 3 })
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			addPickup(
				event,
				point + Vector3.new(math.cos(a), 0, math.sin(a)) * h * 1.5,
				h * 0.5,
				Color3.fromRGB(90, 200, 255),
				function(p)
					local reward = zoneReward(zone, (event.Def.Params.RewardWeight :: number) / 5)
					reward.TitanShards = 1
					return reward
				end
			)
		end
	end))
end

handlers.SupplyCrate = function(event)
	local candidates = playersIn(nil)
	if #candidates == 0 then
		return
	end
	local player = candidates[rng:NextInteger(1, #candidates)]
	local point, h = pointNear(player, 8, 16)
	if not point then
		return
	end
	local zone = zoneOf(player)
	local size = h * 1.6
	local crate = Instance.new("Part")
	crate.Name = "SupplyCrate"
	crate.Size = Vector3.new(size, size, size)
	crate.Position = point + Vector3.new(0, size * 0.5 + h * 30, 0)
	crate.Color = Color3.fromRGB(200, 150, 70)
	crate.Material = Enum.Material.WoodPlanks
	crate.Anchored = true
	crate.Parent = workspace
	event.Trove:Add(crate)
	Net.signalAll("WorldEvent", { State = "Marker", Id = event.Def.Id, Position = point, Radius = size })
	-- Parachute drop (server tween so everyone sees the same landing).
	local TweenService = game:GetService("TweenService")
	TweenService:Create(
		crate,
		TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Position = point + Vector3.new(0, size * 0.5, 0) }
	):Play()
	local hitsLeft = event.Def.Params.Hits :: number
	local hitters: { [Player]: boolean } = {}
	local conn = CombatService.AttackPerformed:Connect(function(attacker, origin, _facing, range)
		if hitsLeft <= 0 or not crate.Parent then
			return
		end
		if (crate.Position - origin).Magnitude <= range + size then
			hitsLeft -= 1
			hitters[attacker] = true
			Net.fx("ObjectHit", { P = crate.Position, S = size })
			if hitsLeft <= 0 then
				Net.fx("ObjectBreak", { P = crate.Position, S = size, C = crate.Color })
				crate.Transparency = 1
				for hitter in hitters do
					if hitter.Parent then
						join(event, hitter)
						RewardService:Grant(
							hitter,
							zoneReward(zone, event.Def.Params.RewardWeight :: number),
							{ Source = "Event", SourceId = event.Def.Id }
						)
					end
				end
			end
		end
	end)
	event.Trove:Add(conn)
end

handlers.PowerOutage = function(event)
	Net.signalAll(
		"WorldEvent",
		{ State = "Lighting", Id = event.Def.Id, Preset = "Outage", Duration = event.Def.Duration }
	)
	local houseZones = { FloorWorld = true, Bedroom = true, Kitchen = true }
	for _, player in playersIn(event.Def.Zones) do
		local zone = zoneOf(player)
		if houseZones[zone] then
			for _ = 1, math.floor((event.Def.Params.Orbs :: number) / math.max(1, #Players:GetPlayers())) do
				local point, h = pointNear(player, 3, 20)
				if point then
					addPickup(event, point, h * 0.35, Color3.fromRGB(150, 170, 255), function(p)
						return zoneReward(zoneOf(p), 0.4)
					end)
				end
			end
		end
	end
end

handlers.RarePortal = function(event)
	local candidates = playersIn(nil)
	if #candidates == 0 then
		return
	end
	local player = candidates[rng:NextInteger(1, #candidates)]
	local point, h = pointNear(player, 8, 16)
	if not point then
		return
	end
	local zone = zoneOf(player)
	local ring = Instance.new("Part")
	ring.Name = "RarePortal"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(h * 0.2, h * 3, h * 3)
	ring.CFrame = CFrame.new(point + Vector3.new(0, h * 1.6, 0)) * CFrame.Angles(0, math.rad(90), 0)
	ring.Color = Color3.fromRGB(200, 100, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = workspace
	event.Trove:Add(ring)
	Net.signalAll("WorldEvent", { State = "Marker", Id = event.Def.Id, Position = point, Radius = h * 3 })
	addPickup(event, point + Vector3.new(0, h, 0), h * 1.2, Color3.fromRGB(230, 150, 255), function(p)
		return zoneReward(zoneOf(p), event.Def.Params.RewardWeight :: number)
	end)
	for i = 1, event.Def.Params.Orbs :: number do
		local a = i / (event.Def.Params.Orbs :: number) * math.pi * 2
		local r = h * (3 + (i % 3) * 2)
		addPickup(
			event,
			point + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r),
			h * 0.3,
			Color3.fromRGB(200, 140, 255),
			function(p)
				local _ = p
				return zoneReward(zone, 0.3)
			end
		)
	end
end

handlers.TitanStorm = function(event)
	local strikes = event.Def.Params.Strikes :: number
	local interval = event.Def.Duration / math.max(1, strikes)
	event.Trove:Add(task.spawn(function()
		for _ = 1, strikes do
			local targets = playersIn(event.Def.Zones)
			if #targets > 0 then
				local player = targets[rng:NextInteger(1, #targets)]
				local point, h = pointNear(player, 2, 10)
				if point then
					local radius = h * 1.2
					Net.fx("Telegraph", { P = point, R = radius, T = 1.5, K = "Circle" })
					task.delay(1.5, function()
						if active ~= event then
							return
						end
						Net.fx("Lightning", { P = point, S = h })
						for _, p in Players:GetPlayers() do
							local root = CharacterService:GetRoot(p)
							if
								root
								and (root.Position - point).Magnitude
									<= radius + ScaleMath.height(ScaleService:GetScale(p)) * 0.5
							then
								HazardService:DamageFromHazard(p, radius * 2, 25, "Titan Storm", point)
							end
						end
						addPickup(event, point, h * 0.4, Color3.fromRGB(255, 240, 120), function()
							return { Resources = { TitanCells = event.Def.Params.Cells :: number }, XP = 50 }
						end)
					end)
				end
			end
			task.wait(interval)
		end
	end))
end

------------------------------------------------------------------ scheduler

local function stop(event: ActiveEvent)
	if active ~= event then
		return
	end
	active = nil
	event.Trove:Destroy()
	Net.signalAll("WorldEvent", { State = "End", Id = event.Def.Id, Name = event.Def.Name })
end

function WorldEventService:StartEvent(eventId: string): boolean
	local def = WorldEventConfig.get(eventId)
	if not def then
		return false
	end
	if active then
		stop(active)
	end
	local event: ActiveEvent = {
		Def = def,
		Trove = Trove.new(),
		EndsAt = os.clock() + def.Duration,
		Joined = {},
		Pickups = {},
	}
	active = event
	Net.signalAll("WorldEvent", {
		State = "Start",
		Id = def.Id,
		Name = def.Name,
		Description = def.Description,
		Duration = def.Duration,
		EndsAt = workspace:GetServerTimeNow() + def.Duration,
		Icon = def.Icon,
		Color = def.Color,
	})
	local handler = handlers[def.Id]
	if handler then
		local ok, err = pcall(function()
			handler(event)
		end)
		if not ok then
			Log.error("WorldEvent", def.Id, "failed:", err)
			stop(event)
			return false
		end
	end
	event.Trove:Add(task.delay(def.Duration, function()
		stop(event)
	end))
	return true
end

function WorldEventService:GetActive(): string?
	return if active then active.Def.Id else nil
end

local function chooseEvent(): WorldEventConfig.WorldEvent?
	local maxTier = 0
	for _, player in Players:GetPlayers() do
		maxTier = math.max(maxTier, ProgressionService:GetTier(player))
	end
	local eligible = TableUtil.filter(WorldEventConfig.List, function(e)
		return e.MinTier <= maxTier and #playersIn(e.Zones) > 0
	end)
	return TableUtil.weightedPick(eligible, function(e)
		return e.Weight
	end, function()
		return rng:NextNumber()
	end)
end

function WorldEventService:Start()
	-- Pickup proximity checks (cheap: a handful of pickups × players).
	task.spawn(function()
		while true do
			task.wait(0.25)
			local event = active
			if event then
				for _, player in Players:GetPlayers() do
					local root = CharacterService:GetRoot(player)
					if root then
						local reach = ScaleMath.height(ScaleService:GetScale(player)) * 0.8
						for _, pickup in event.Pickups do
							if
								not pickup.Collected[player]
								and (root.Position - pickup.Position).Magnitude <= pickup.Radius + reach
							then
								pickup.Collected[player] = true
								join(event, player)
								RewardService:Grant(
									player,
									pickup.Reward(player),
									{ Source = "Event", SourceId = event.Def.Id, Position = pickup.Position }
								)
								Net.signal(
									player,
									"WorldEvent",
									{ State = "Picked", Id = event.Def.Id, Pickup = pickup.Id }
								)
							end
						end
					end
				end
			end
		end
	end)
	task.spawn(function()
		task.wait(WorldEventConfig.FirstEventDelay)
		while true do
			if not active and #Players:GetPlayers() > 0 then
				local def = chooseEvent()
				if def then
					WorldEventService:StartEvent(def.Id)
				end
			end
			task.wait(rng:NextNumber(WorldEventConfig.IntervalMin, WorldEventConfig.IntervalMax))
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		local event = active
		if event then
			task.delay(5, function()
				if active == event and player.Parent then
					Net.signal(player, "WorldEvent", {
						State = "Start",
						Id = event.Def.Id,
						Name = event.Def.Name,
						Description = event.Def.Description,
						Duration = event.Def.Duration,
						EndsAt = workspace:GetServerTimeNow() + math.max(0, event.EndsAt - os.clock()),
						Icon = event.Def.Icon,
						Color = event.Def.Color,
					})
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local event = active
		if event then
			event.Joined[player] = nil
			for _, pickup in event.Pickups do
				pickup.Collected[player] = nil
			end
		end
	end)
end

return WorldEventService
