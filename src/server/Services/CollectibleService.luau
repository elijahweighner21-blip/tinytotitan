--!strict
--[[
	CollectibleService
	Growth Orbs, resource clusters and unique collectibles (coins, shards,
	relics, toys, memory fragments, secret stars).

	The world's tagged collectible parts are indexed once at startup (their
	positions are authoritative). The client asks to collect by id when close;
	the server checks:
	  * the id exists and its type
	  * unique collectibles: not already owned
	  * respawning ones: this player's personal respawn timer has elapsed
	  * distance from the player's REAL position (pickup range scales with
	    size and the Detection Radius stat, plus a small latency allowance)
	Orbs respawn per player, so several players never compete for the same
	orb and nobody can farm one orb faster than its respawn time.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectibleConfig = require(Shared.Config.CollectibleConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local LoreConfig = require(Shared.Config.LoreConfig)
local Types = require(Shared.Types)
local Guard = require(Shared.Util.Guard)
local ScaleMath = require(Shared.Formulas.ScaleMath)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CharacterService = require(script.Parent.CharacterService)
local StatService = require(script.Parent.StatService)
local RewardService = require(script.Parent.RewardService)
local InventoryService = require(script.Parent.InventoryService)
local StatisticsService = require(script.Parent.StatisticsService)
local ScaleService = require(script.Parent.ScaleService)

type Entry = { Id: string, Type: string, Zone: string, Position: Vector3, Size: number, Order: number }

local CollectibleService = {}

local entries: { [string]: Entry } = {}
local cooldowns: { [Player]: { [string]: number } } = {}
local totals: { [string]: { Total: number, ByType: { [string]: number } } } = {}
local fragmentOrder: { [string]: { string } } = {}
local rng = Random.new()

local function index(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("CollectibleId")
	local typeId = part:GetAttribute("Type")
	local zone = part:GetAttribute("Zone")
	if type(id) ~= "string" or type(typeId) ~= "string" or type(zone) ~= "string" or entries[id] then
		return
	end
	local def = CollectibleConfig.get(typeId)
	if not def then
		return
	end
	local order = tonumber(string.match(id, "_(%d+)$")) or 0
	entries[id] =
		{ Id = id, Type = typeId, Zone = zone, Position = part.Position, Size = part.Size.Magnitude, Order = order }
	if def.Unique then
		local t = totals[zone]
		if not t then
			t = { Total = 0, ByType = {} }
			totals[zone] = t
		end
		t.Total += 1
		t.ByType[typeId] = (t.ByType[typeId] or 0) + 1
	end
	if typeId == "MemoryFragment" then
		local list = fragmentOrder[zone] or {}
		fragmentOrder[zone] = list
		table.insert(list, id)
		table.sort(list, function(a, b)
			return entries[a].Order < entries[b].Order
		end)
	end
end

-- Resource clusters are converted from a share of each resource zone's
-- Growth Orbs so every region has gatherable resources along its routes.
local function convertResourceNodes()
	local counter: { [string]: number } = {}
	for _, part in CollectionService:GetTagged("Collectible") do
		local zone = part:GetAttribute("Zone")
		if part:GetAttribute("Type") == "GrowthOrb" and type(zone) == "string" then
			local z = ZoneConfig.get(zone)
			if z and z.Resource then
				counter[zone] = (counter[zone] or 0) + 1
				if counter[zone] % 4 == 0 and part:IsA("BasePart") then
					part:SetAttribute("Type", "ResourceNode")
					part:SetAttribute("Resource", z.Resource)
					part.Color = Color3.fromRGB(200, 160, 255)
					part.Shape = Enum.PartType.Block
					part.Size = Vector3.new(part.Size.X * 0.6, part.Size.Y * 1.3, part.Size.Z * 0.6)
				end
			end
		end
	end
end

function CollectibleService:GetTotals(): { [string]: { Total: number, ByType: { [string]: number } } }
	return totals
end

function CollectibleService:CountOwned(player: Player, zone: string): number
	local data = PlayerDataService:Get(player)
	if not data then
		return 0
	end
	local n = 0
	for id in data.Collectibles do
		local e = entries[id]
		if e and e.Zone == zone then
			n += 1
		end
	end
	return n
end

-- Uncollected collectibles near a point (Echo Scan ability).
function CollectibleService:Scan(
	player: Player,
	center: Vector3,
	radius: number
): { { Id: string, P: Vector3, T: string } }
	local data = PlayerDataService:Get(player)
	local out = {}
	if not data then
		return out
	end
	local now = os.clock()
	local personal = cooldowns[player] or {}
	for id, e in entries do
		if (e.Position - center).Magnitude <= radius then
			local def = CollectibleConfig.get(e.Type)
			local available = if def and def.Unique then not data.Collectibles[id] else (personal[id] or 0) <= now
			if available then
				table.insert(out, { Id = id, P = e.Position, T = e.Type })
				if #out >= 40 then
					break
				end
			end
		end
	end
	return out
end

local function zoneScaled(reward: Types.Reward, zoneId: string): Types.Reward
	return RewardService:ScaleZone(reward, zoneId)
end

local function collect(player: Player, id: string)
	local entry = entries[id]
	local data = PlayerDataService:Get(player)
	if not entry or not data then
		return
	end
	local def = CollectibleConfig.get(entry.Type)
	if not def then
		return
	end
	local now = os.clock()
	local personal = cooldowns[player]
	if not personal then
		personal = {}
		cooldowns[player] = personal
	end
	if def.Unique then
		if data.Collectibles[id] then
			return
		end
	elseif (personal[id] or 0) > now then
		return
	end
	-- Distance check against the server's view of the character.
	local root = CharacterService:GetRoot(player)
	if not root then
		return
	end
	local derived = StatService:GetDerived(player)
	local scale = ScaleService:GetScale(player)
	local speed = root.AssemblyLinearVelocity.Magnitude
	local allowed = derived.CollectRange
		+ entry.Size
		+ ScaleMath.height(scale) * 0.5
		+ speed * CollectibleConfig.PickupLatencyGrace
	if (root.Position - entry.Position).Magnitude > allowed then
		return
	end

	local reward: Types.Reward = def.Reward
	local typeForEvents = entry.Type
	local golden = false
	if entry.Type == "GrowthOrb" then
		local chance = CollectibleConfig.GoldenOrbBaseChance + StatService:Get(player, "GoldenOrbChance")
		if rng:NextNumber() < chance then
			golden = true
			local goldenDef = CollectibleConfig.get("GoldenOrb")
			if goldenDef then
				reward = goldenDef.Reward
			end
		end
	end
	if def.ZoneScaled then
		reward = zoneScaled(reward, entry.Zone)
	end
	if entry.Type == "ResourceNode" then
		local zone = ZoneConfig.get(entry.Zone)
		if zone and zone.Resource then
			local copy = table.clone(reward :: any)
			copy.Resources = { [zone.Resource] = 3 + math.floor(zone.Order / 2) }
			reward = copy
		end
	end

	if def.Unique then
		data.Collectibles[id] = true
		PlayerDataService:Changed(player, "Collectibles")
		StatisticsService:Increment(player, "CollectiblesFound")
		if def.Hidden then
			StatisticsService:Increment(player, "SecretsFound")
		end
		if entry.Type == "MemoryFragment" then
			local list = fragmentOrder[entry.Zone] or {}
			local position = table.find(list, id) or 1
			local loreId = "Fragment_" .. entry.Zone .. "_" .. position
			if LoreConfig.get(loreId) then
				InventoryService:UnlockLore(player, loreId)
			end
		elseif entry.Type == "Relic" then
			InventoryService:AddRelic(player, id)
		end
	else
		personal[id] = now + (def.Respawn or 60)
		if entry.Type == "GrowthOrb" or entry.Type == "GoldenOrb" then
			StatisticsService:Increment(player, "OrbsCollected")
			GameEvents.fire("OrbCollected", player, entry.Zone)
		end
	end

	RewardService:Grant(player, reward, {
		Source = "Collectible",
		SourceId = entry.Type,
		Position = entry.Position,
		Notify = true,
	})
	Net.signal(player, "Notify", {
		Kind = "Collect",
		Collectible = id,
		Type = if golden then "GoldenOrb" else entry.Type,
		Respawn = if def.Unique then nil else def.Respawn,
	})
	GameEvents.fire("Collected", player, typeForEvents, id, entry.Zone)
end

function CollectibleService:Init()
	convertResourceNodes()
	for _, part in CollectionService:GetTagged("Collectible") do
		index(part)
	end
	CollectionService:GetInstanceAddedSignal("Collectible"):Connect(index)

	Net.onAction("Collect", Guard.string(64), function(player, id)
		collect(player, id)
	end)

	Net.onRequest(
		"ClaimCollection",
		Guard.shape({ Zone = Guard.id(), Milestone = Guard.integer(1, 5) }),
		function(player, payload)
			local data = PlayerDataService:Get(player)
			local milestone = CollectibleConfig.CollectionMilestones[payload.Milestone]
			local t = totals[payload.Zone]
			if not data or not milestone or not t or t.Total == 0 then
				return { ok = false, err = "Nothing to claim" }
			end
			local key = payload.Zone .. ":" .. payload.Milestone
			if data.CollectionClaims[key] then
				return { ok = false, err = "Already claimed" }
			end
			if CollectibleService:CountOwned(player, payload.Zone) / t.Total < milestone.Fraction then
				return { ok = false, err = "Collection not complete yet" }
			end
			data.CollectionClaims[key] = true
			PlayerDataService:Changed(player, "CollectionClaims")
			RewardService:Grant(player, milestone.Reward, { Source = "Collection", SourceId = key })
			return { ok = true }
		end
	)
end

function CollectibleService:Start()
	PlayerDataService.Loaded:Connect(function(player)
		Net.signal(player, "WorldInfo", { Collections = totals })
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return CollectibleService
