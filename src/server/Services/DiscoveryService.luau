--!strict
--[[
	DiscoveryService
	Awards first visits to named locations (DiscoveryConfig + tagged
	DiscoveryRegion boxes). Checked on the server from the player's real
	position twice a second — the client never claims a discovery.

	Size-limited secrets (MaxTier) also require the player's CURRENT size to
	be at or below that tier, so glitching into a vent while giant does not
	count; Shrink Mode is the intended way back in.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DiscoveryConfig = require(Shared.Config.DiscoveryConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local RewardConfig = require(Shared.Config.RewardConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CharacterService = require(script.Parent.CharacterService)
local RewardService = require(script.Parent.RewardService)
local InventoryService = require(script.Parent.InventoryService)
local StatisticsService = require(script.Parent.StatisticsService)
local ScaleService = require(script.Parent.ScaleService)

local DiscoveryService = {}

type Region = { Id: string, CFrame: CFrame, Half: Vector3, Def: DiscoveryConfig.Discovery }
local regions: { Region } = {}

-- Size tier matching a scale (the largest tier whose scale ≤ the value).
local function tierForScale(scale: number): number
	local tier = 1
	for i, def in SizeConfig.Tiers do
		if scale >= def.Scale * 0.98 then
			tier = i
		end
	end
	return tier
end

local function contains(region: Region, point: Vector3): boolean
	local p = region.CFrame:PointToObjectSpace(point)
	local h = region.Half
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function discover(player: Player, region: Region)
	local data = PlayerDataService:Get(player)
	if not data or data.Discoveries[region.Id] then
		return
	end
	local def = region.Def
	if def.MaxTier and tierForScale(ScaleService:GetScale(player)) > def.MaxTier then
		return
	end
	data.Discoveries[region.Id] = os.time()
	PlayerDataService:Changed(player, "Discoveries")
	local reward = RewardConfig.zone(def.Zone, def.Weight * 1.5)
	if def.Hidden then
		reward.TitanShards = DiscoveryConfig.TitanShardsForHidden
		StatisticsService:Increment(player, "SecretsFound")
	end
	local granted = RewardService:Grant(
		player,
		reward,
		{ Source = "Discovery", SourceId = def.Id, Category = "Discovery", Notify = false }
	)
	if def.Lore then
		InventoryService:UnlockLore(player, def.Lore)
	end
	Net.signal(player, "Discovery", {
		Id = def.Id,
		Name = def.Name,
		Zone = def.Zone,
		Hidden = def.Hidden == true,
		Lore = def.Lore,
		Mass = granted.Mass,
		GrowthEnergy = granted.GrowthEnergy,
		XP = granted.XP,
		TitanShards = granted.TitanShards,
	})
	GameEvents.fire("Discovered", player, def.Id, def.Zone)
end

function DiscoveryService:Init()
	for _, part in CollectionService:GetTagged("DiscoveryRegion") do
		if part:IsA("BasePart") then
			local id = part:GetAttribute("DiscoveryId")
			local def = if type(id) == "string" then DiscoveryConfig.get(id) else nil
			if def then
				table.insert(regions, { Id = def.Id, CFrame = part.CFrame, Half = part.Size / 2, Def = def })
			end
		end
	end
end

function DiscoveryService:Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local root = CharacterService:GetRoot(player)
				local data = PlayerDataService:Get(player)
				if root and data then
					-- Test both the root and the feet so big players standing on
					-- small landmarks (a shoe, a desk) still discover them.
					local pos = root.Position
					local feetPos = pos - Vector3.new(0, ScaleMath.height(ScaleService:GetScale(player)) * 0.48, 0)
					for _, region in regions do
						if not data.Discoveries[region.Id] and (contains(region, pos) or contains(region, feetPos)) then
							discover(player, region)
						end
					end
				end
			end
		end
	end)
end

return DiscoveryService
