--!strict
--[[
	InteractionService
	World objects respond to the player's size and strength:
	  Push  (small–medium)  object slides away from the player
	  Carry (large)         object is held in front of the character
	  Throw (giant)         carried object is launched and can hit enemies
	  Break (any, with enough Break Power) breakables shatter into debris

	Server validation on every interaction: object exists, it is in a state
	that allows the action, the player is within reach (scaled by size), the
	player is strong enough (InteractableConfig thresholds vs. Stats.derive)
	and per-player cooldowns.

	Griefing / physics safety: moving, carried and thrown objects use the
	MovingProps collision group (never collides with players); everything is
	server-owned and slides back home after a while, debris is capped and
	short-lived, so nobody can permanently wreck the map or launch others.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InteractableConfig = require(Shared.Config.InteractableConfig)
local GameConfig = require(Shared.Config.GameConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Guard = require(Shared.Util.Guard)
local Format = require(Shared.Util.Format)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CharacterService = require(script.Parent.CharacterService)
local StatService = require(script.Parent.StatService)
local CombatService = require(script.Parent.CombatService)
local RewardService = require(script.Parent.RewardService)
local StatisticsService = require(script.Parent.StatisticsService)
local InventoryService = require(script.Parent.InventoryService)
local ScaleService = require(script.Parent.ScaleService)

local InteractionService = {}

type Entry = {
	Id: string,
	Part: BasePart,
	Def: InteractableConfig.ObjectDef,
	Home: CFrame,
	State: string, -- Idle | Moving | Displaced | Carried | Thrown | Broken
	Carrier: Player?,
	Health: number,
	ResetAt: number,
	LastReward: { [Player]: number },
	Original: { Transparency: number, CanCollide: boolean },
	Weld: WeldConstraint?,
	Zone: string,
}

local entries: { [string]: Entry } = {}
local carrying: { [Player]: Entry } = {}
local doors: { [string]: BasePart } = {}
local activeDebris = 0
local lastWeakNotice: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	return CharacterService:GetRoot(player)
end

local function inReach(player: Player, part: BasePart): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	local derived = StatService:GetDerived(player)
	return (root.Position - part.Position).Magnitude <= derived.InteractRange + part.Size.Magnitude * 0.6
end

local function notifyWeak(player: Player, text: string)
	local now = os.clock()
	if (lastWeakNotice[player] or 0) > now then
		return
	end
	lastWeakNotice[player] = now + 1.5
	Net.signal(player, "Notify", { Text = text, Kind = "Warning" })
end

local function setGroup(part: BasePart, group: string)
	part.CollisionGroup = group
end

local function sendHome(entry: Entry)
	local part = entry.Part
	if entry.Weld then
		entry.Weld:Destroy()
		entry.Weld = nil
	end
	part.Anchored = true
	part.AssemblyLinearVelocity = Vector3.zero
	setGroup(part, GameConfig.MovingPropGroup)
	local tween = TweenService:Create(
		part,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ CFrame = entry.Home }
	)
	tween:Play()
	tween.Completed:Once(function()
		setGroup(part, "Default")
		entry.State = "Idle"
	end)
	entry.Carrier = nil
end

local function maybeReward(player: Player, entry: Entry)
	local reward = entry.Def.Reward
	if not reward then
		return
	end
	local now = os.clock()
	if (entry.LastReward[player] or 0) > now then
		return
	end
	entry.LastReward[player] = now + InteractableConfig.PerObjectRewardCooldown
	local scaled = if entry.Def.ZoneScaled then RewardService:ScaleZone(reward :: any, entry.Zone) else reward
	RewardService:Grant(
		player,
		scaled :: any,
		{ Source = "Object", SourceId = entry.Def.Id, Position = entry.Part.Position }
	)
end

------------------------------------------------------------------ push

local function push(player: Player, entry: Entry)
	local def = entry.Def
	if not def.Push then
		return
	end
	if entry.State ~= "Idle" and entry.State ~= "Displaced" then
		return
	end
	local derived = StatService:GetDerived(player)
	if derived.PushStrength < def.Push then
		notifyWeak(
			player,
			string.format(
				"Too heavy to push — needs %s push strength (you have %s)",
				Format.abbreviate(def.Push),
				Format.abbreviate(derived.PushStrength)
			)
		)
		return
	end
	local root = rootOf(player) :: BasePart
	local part = entry.Part
	local dir = (part.Position - root.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.01 then
		return
	end
	dir = dir.Unit
	local size = math.max(part.Size.X, part.Size.Z)
	local distance = InteractableConfig.PushDistanceBodies * size
	-- Stop at walls.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { part }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(part.Position, dir * (distance + size / 2), params)
	if hit then
		distance = math.max(0, (hit.Position - part.Position).Magnitude - size / 2 - 0.1)
	end
	if distance < size * 0.1 then
		return
	end
	entry.State = "Moving"
	setGroup(part, GameConfig.MovingPropGroup)
	local goal = part.CFrame + dir * distance
	if def.Id == "Domino" then
		-- Dominoes topple instead of sliding.
		local axis = Vector3.new(0, 1, 0):Cross(dir)
		goal = CFrame.new(part.Position + dir * part.Size.Y * 0.45 - Vector3.new(0, part.Size.Y * 0.4, 0))
			* CFrame.fromAxisAngle(axis, math.rad(-80))
			* (part.CFrame - part.Position)
	end
	local tween = TweenService:Create(
		part,
		TweenInfo.new(InteractableConfig.PushDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = goal }
	)
	tween:Play()
	tween.Completed:Once(function()
		setGroup(part, "Default")
		entry.State = "Displaced"
		entry.ResetAt = os.clock() + InteractableConfig.DisplacedResetTime
	end)
	Net.fx("Push", { P = part.Position, S = ScaleService:GetScale(player) })
	maybeReward(player, entry)
	GameEvents.fire("ObjectMoved", player, "Push", def.Id)
end

------------------------------------------------------------------ carry / throw

local function drop(player: Player, launch: Vector3?)
	local entry = carrying[player]
	if not entry then
		return
	end
	carrying[player] = nil
	player:SetAttribute("Carrying", nil)
	local part = entry.Part
	if entry.Weld then
		entry.Weld:Destroy()
		entry.Weld = nil
	end
	entry.Carrier = nil
	part.Massless = false
	part.CanCollide = true
	setGroup(part, GameConfig.MovingPropGroup)
	pcall(function()
		part:SetNetworkOwner(nil)
	end)
	if launch then
		part.AssemblyLinearVelocity = launch
		entry.State = "Thrown"
		-- Thrown objects damage enemies they pass near (checked briefly).
		task.spawn(function()
			local hitDone = false
			for _ = 1, 25 do
				task.wait(0.1)
				if hitDone or not part.Parent then
					break
				end
				for _, target in CombatService:GetTargets() do
					if
						(target.GetPosition() - part.Position).Magnitude
						<= part.Size.Magnitude * 0.6 + target.Radius
					then
						CombatService:AreaDamage(player, part.Position, part.Size.Magnitude, "Throw")
						hitDone = true
						break
					end
				end
			end
		end)
	else
		entry.State = "Displaced"
	end
	entry.ResetAt = os.clock() + InteractableConfig.ThrownLifetime
end

local function carry(player: Player, entry: Entry)
	local def = entry.Def
	if not def.Carry or entry.State == "Carried" or entry.State == "Broken" or entry.State == "Moving" then
		return
	end
	if carrying[player] then
		drop(player, nil)
		return
	end
	local derived = StatService:GetDerived(player)
	if derived.CarryStrength < def.Carry then
		notifyWeak(
			player,
			string.format(
				"Too heavy to carry — needs %s carry strength (you have %s)",
				Format.abbreviate(def.Carry),
				Format.abbreviate(derived.CarryStrength)
			)
		)
		return
	end
	local root = rootOf(player) :: BasePart
	local part = entry.Part
	local h = ScaleMath.height(ScaleService:GetScale(player))
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	setGroup(part, GameConfig.MovingPropGroup)
	part.CFrame = root.CFrame * CFrame.new(0, h * 0.15, -(h * 0.3 + part.Size.Z * 0.5))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	entry.Weld = weld
	entry.State = "Carried"
	entry.Carrier = player
	carrying[player] = entry
	player:SetAttribute("Carrying", entry.Id)
	GameEvents.fire("ObjectMoved", player, "Carry", def.Id)
end

local function throw(player: Player, direction: Vector3)
	local entry = carrying[player]
	if not entry then
		return
	end
	local derived = StatService:GetDerived(player)
	local def = entry.Def
	if not def.Throw or derived.ThrowStrength < def.Throw then
		if def.Throw then
			notifyWeak(
				player,
				string.format("Not strong enough to throw it — needs %s throw strength", Format.abbreviate(def.Throw))
			)
		end
		drop(player, nil)
		return
	end
	local h = ScaleMath.height(ScaleService:GetScale(player))
	local dir = if direction.Magnitude > 0.01 then direction.Unit else Vector3.new(0, 0, -1)
	local launch = (dir + Vector3.new(0, 0.35, 0)).Unit * InteractableConfig.ThrowSpeedBodies * h
	drop(player, launch)
	Net.fx("Throw", { P = entry.Part.Position, S = ScaleService:GetScale(player) })
	GameEvents.fire("ObjectMoved", player, "Throw", def.Id)
end

------------------------------------------------------------------ break

local function spawnDebris(part: BasePart)
	local pieces = math.min(5, InteractableConfig.MaxActiveDebris - activeDebris)
	for _ = 1, pieces do
		local d = Instance.new("Part")
		d.Size = part.Size * (0.15 + math.random() * 0.2)
		d.CFrame = part.CFrame
			* CFrame.new(
				(math.random() - 0.5) * part.Size.X,
				(math.random() - 0.5) * part.Size.Y,
				(math.random() - 0.5) * part.Size.Z
			)
		d.Color = part.Color
		d.Material = part.Material
		d.CanQuery = false
		d.CanTouch = false
		d.CollisionGroup = GameConfig.DebrisGroup
		d.AssemblyLinearVelocity = Vector3.new(math.random() - 0.5, 1, math.random() - 0.5) * part.Size.Magnitude * 2
		d.Parent = workspace
		activeDebris += 1
		Debris:AddItem(d, InteractableConfig.DebrisLifetime)
		task.delay(InteractableConfig.DebrisLifetime, function()
			activeDebris -= 1
		end)
	end
end

local function breakHit(player: Player, entry: Entry, hits: number, breakPower: number)
	local def = entry.Def
	if not def.Break or entry.State == "Broken" or entry.State == "Carried" then
		return
	end
	if breakPower < def.Break then
		notifyWeak(
			player,
			string.format(
				"Too tough to break — needs %s break power (you have %s)",
				Format.abbreviate(def.Break),
				Format.abbreviate(breakPower)
			)
		)
		return
	end
	entry.Health -= hits
	Net.fx("ObjectHit", { P = entry.Part.Position, S = entry.Part.Size.Magnitude })
	if entry.Health > 0 then
		return
	end
	local part = entry.Part
	entry.State = "Broken"
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	spawnDebris(part)
	Net.fx("ObjectBreak", { P = part.Position, S = part.Size.Magnitude, C = part.Color })
	maybeReward(player, entry)
	StatisticsService:Increment(player, "ObjectsBroken")
	GameEvents.fire("ObjectBroken", player, def.Id)
	task.delay(def.Respawn, function()
		if not part.Parent then
			return
		end
		part.Anchored = true
		part.CFrame = entry.Home
		part.Transparency = entry.Original.Transparency
		part.CanCollide = entry.Original.CanCollide
		part.CanQuery = true
		entry.Health = def.Health or 1
		entry.State = "Idle"
	end)
end

------------------------------------------------------------------ setup

local function register(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("InteractId")
	local objectType = part:GetAttribute("ObjectType")
	local def = if type(objectType) == "string" then InteractableConfig.get(objectType) else nil
	if type(id) ~= "string" or not def or entries[id] then
		return
	end
	local zone = ZoneConfig.zoneAt(part.Position)
	entries[id] = {
		Id = id,
		Part = part,
		Def = def,
		Home = part.CFrame,
		State = "Idle",
		Carrier = nil,
		Health = def.Health or 1,
		ResetAt = 0,
		LastReward = {},
		Original = { Transparency = part.Transparency, CanCollide = part.CanCollide },
		Weld = nil,
		Zone = if zone then zone.Id else "FloorWorld",
	}
end

function InteractionService:Init()
	for _, part in CollectionService:GetTagged("Interactable") do
		register(part)
	end
	CollectionService:GetInstanceAddedSignal("Interactable"):Connect(register)
	for _, part in CollectionService:GetTagged("LockedDoor") do
		local id = part:GetAttribute("InteractId")
		if part:IsA("BasePart") and type(id) == "string" then
			doors[id] = part
		end
	end

	Net.onAction(
		"Interact",
		Guard.shape({ Id = Guard.string(32), Verb = Guard.oneOf({ "Push", "Carry", "Break", "Drop" }) }),
		function(player, payload)
			if payload.Verb == "Drop" then
				drop(player, nil)
				return
			end
			local entry = entries[payload.Id]
			if not entry or not entry.Part.Parent or not inReach(player, entry.Part) then
				return
			end
			if payload.Verb == "Push" then
				push(player, entry)
			elseif payload.Verb == "Carry" then
				carry(player, entry)
			elseif payload.Verb == "Break" then
				local derived = StatService:GetDerived(player)
				breakHit(player, entry, 1, derived.BreakPower)
			end
		end
	)
	Net.onAction("ThrowRelease", Guard.shape({ Direction = Guard.vector3(2) }), function(player, payload)
		throw(player, payload.Direction)
	end)
	Net.onRequest("UseKey", Guard.shape({ Id = Guard.string(32) }), function(player, payload)
		local door = doors[payload.Id]
		local data = PlayerDataService:Get(player)
		if not door or not data then
			return { ok = false, err = "Nothing to unlock" }
		end
		if not inReach(player, door) then
			return { ok = false, err = "Move closer" }
		end
		local key = door:GetAttribute("KeyItem")
		if type(key) == "string" and not InventoryService:HasItem(player, key) then
			return { ok = false, err = (door:GetAttribute("Message") :: string?) or "Locked" }
		end
		data.UnlockedDoors[payload.Id] = true
		PlayerDataService:Changed(player, "UnlockedDoors")
		return { ok = true }
	end)
end

function InteractionService:Start()
	CombatService.AttackPerformed:Connect(function(player, origin, facing, range, arc, kind)
		local hits = if kind == "Heavy" or kind == "Charged" or kind == "Stomp" or kind == "Shockwave" then 2 else 1
		local breakPower = StatService:GetDerived(player).BreakPower
			* (if kind == "Charged" or kind == "Stomp" then 1.5 else 1)
		for _, entry in entries do
			if entry.Def.Break and entry.State ~= "Broken" then
				local offset = entry.Part.Position - origin
				if offset.Magnitude <= range + entry.Part.Size.Magnitude * 0.5 then
					local flat = offset * Vector3.new(1, 0, 1)
					local ok = arc >= 360
						or flat.Magnitude < 0.01
						or flat.Unit:Dot((facing * Vector3.new(1, 0, 1)).Unit) >= math.cos(math.rad(arc / 2))
					if ok then
						breakHit(player, entry, hits, breakPower)
					end
				end
			end
		end
	end)
	CharacterService.Died:Connect(function(player)
		drop(player, nil)
	end)
	CharacterService.Teleported:Connect(function(player)
		drop(player, nil)
	end)
	Players.PlayerRemoving:Connect(function(player)
		drop(player, nil)
		lastWeakNotice[player] = nil
		for _, entry in entries do
			entry.LastReward[player] = nil
		end
	end)
	-- Return displaced / thrown objects home.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, entry in entries do
				if (entry.State == "Displaced" or entry.State == "Thrown") and now >= entry.ResetAt then
					sendHome(entry)
				end
			end
		end
	end)
end

return InteractionService
