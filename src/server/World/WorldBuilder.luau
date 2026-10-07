--!strict
--[[
	WorldBuilder
	Generates the playable prototype world at server start, then validates it
	against the content configs so missing placements are reported loudly
	(instead of becoming silent "quest can never complete" bugs).

	Everything is built under Workspace.World. Replace any region with a
	hand-built model by deleting its builder call and parenting the model
	there — as long as the tagged markers (see Kit) exist, every system works.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DiscoveryConfig = require(Shared.Config.DiscoveryConfig)
local NPCConfig = require(Shared.Config.NPCConfig)
local BossConfig = require(Shared.Config.BossConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Log = require(Shared.Util.Log)

local Kit = require(script.Parent.Kit)
local CourseBuilder = require(script.Parent.CourseBuilder)
local Regions = script.Parent.Regions

local WorldBuilder = {}

WorldBuilder.Built = false
WorldBuilder.VipLounge = Vector3.new(0, 600, 30000)

local function setupLighting()
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 130)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ExposureCompensation = 0.1
	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end
	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 215, 235)
	atmosphere.Decay = Color3.fromRGB(120, 140, 170)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 1.6
	local cc = ensure("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	cc.Saturation = 0.08
	cc.Contrast = 0.06
	cc.Brightness = 0.01
	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.04
	rays.Spread = 0.6
	ensure("Sky", "Sky")
end

local function buildVipLounge(root: Instance)
	-- A human-scale hangout (players are temporarily sized to Human here).
	local m = Kit.model(root, "VipLounge")
	local c = WorldBuilder.VipLounge
	Kit.block(
		m,
		"Floor",
		c - Vector3.new(0, 2, 0),
		Vector3.new(900, 4, 900),
		Color3.fromRGB(30, 25, 40),
		Enum.Material.Marble
	)
	for i, offset in
		{ Vector3.new(450, 0, 0), Vector3.new(-450, 0, 0), Vector3.new(0, 0, 450), Vector3.new(0, 0, -450) }
	do
		local size = if offset.X ~= 0 then Vector3.new(6, 220, 900) else Vector3.new(900, 220, 6)
		local wall = Kit.block(
			m,
			"Wall" .. i,
			c + offset + Vector3.new(0, 110, 0),
			size,
			Color3.fromRGB(50, 40, 70),
			Enum.Material.SmoothPlastic
		)
		local _ = wall
	end
	Kit.block(
		m,
		"Ceiling",
		c + Vector3.new(0, 222, 0),
		Vector3.new(900, 4, 900),
		Color3.fromRGB(40, 30, 55),
		Enum.Material.SmoothPlastic
	)
	local dance = Kit.block(
		m,
		"DanceFloor",
		c + Vector3.new(0, 0.1, 150),
		Vector3.new(300, 0.4, 300),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.Neon
	)
	Kit.tag(dance, "Disco")
	Kit.light(dance, Color3.fromRGB(255, 210, 120), 60, 1.5)
	for _, x in { -300, 300 } do
		local lamp = Kit.ball(
			m,
			"GoldLamp",
			c + Vector3.new(x, 200, -300),
			30,
			Color3.fromRGB(255, 220, 120),
			Enum.Material.Neon
		)
		Kit.light(lamp, Color3.fromRGB(255, 220, 140), 60, 1.2)
	end
	Kit.station(m, "Cosmetics", "VIP Wardrobe", c + Vector3.new(-250, 0, -250), 16, Color3.fromRGB(255, 215, 0))
	Kit.station(m, "Shop", "VIP Boutique", c + Vector3.new(250, 0, -250), 16, Color3.fromRGB(255, 215, 0))
	local exit =
		Kit.station(m, "LeaveLounge", "Exit Lounge", c + Vector3.new(0, 0, -380), 16, Color3.fromRGB(200, 200, 255))
	local _ = exit
	for i = 0, 5 do
		Kit.block(
			m,
			"Couch",
			c + Vector3.new(-350 + i * 140, 15, 380),
			Vector3.new(110, 30, 50),
			Color3.fromRGB(120, 40, 80),
			Enum.Material.Fabric
		)
	end
end

local function validate()
	local discoveries: { [string]: boolean } = {}
	for _, part in CollectionService:GetTagged("DiscoveryRegion") do
		discoveries[part:GetAttribute("DiscoveryId") :: string] = true
	end
	for _, d in DiscoveryConfig.List do
		if not discoveries[d.Id] then
			Log.warn("World", "discovery has no region in the world:", d.Id)
		end
	end
	local npcs: { [string]: boolean } = {}
	for _, marker in CollectionService:GetTagged("NPCSpawn") do
		npcs[marker:GetAttribute("NPCId") :: string] = true
	end
	for _, npc in NPCConfig.List do
		if not npcs[npc.Id] then
			Log.warn("World", "NPC has no spawn:", npc.Id)
		end
	end
	local arenas: { [string]: boolean } = {}
	for _, marker in CollectionService:GetTagged("BossArena") do
		arenas[marker:GetAttribute("BossId") :: string] = true
	end
	for _, boss in BossConfig.List do
		if not arenas[boss.Id] then
			Log.warn("World", "boss has no arena:", boss.Id)
		end
	end
	local stations: { [string]: boolean } = {}
	for _, part in CollectionService:GetTagged("FastTravelStation") do
		stations[part:GetAttribute("StationId") :: string] = true
	end
	for _, zone in ZoneConfig.Zones do
		if not stations[zone.Id] then
			Log.warn("World", "zone has no fast travel station:", zone.Id)
		end
	end
end

-- Positions of every named world target, published outside Workspace so the
-- client can point quest arrows and the map at things that are not streamed
-- in. Attributes on ReplicatedStorage.WorldIndex: "<Kind>_<Id>" = Vector3.
local INDEX_TAGS: { { Tag: string, Attribute: string, Kind: string } } = {
	{ Tag = "DiscoveryRegion", Attribute = "DiscoveryId", Kind = "Discovery" },
	{ Tag = "NPCSpawn", Attribute = "NPCId", Kind = "NPC" },
	{ Tag = "ChallengeStart", Attribute = "ChallengeId", Kind = "Challenge" },
	{ Tag = "BossArena", Attribute = "BossId", Kind = "Boss" },
	{ Tag = "FastTravelStation", Attribute = "StationId", Kind = "Station" },
}

local function publishIndex()
	local existing = ReplicatedStorage:FindFirstChild("WorldIndex")
	if existing then
		existing:Destroy()
	end
	local index = Instance.new("Folder")
	index.Name = "WorldIndex"
	for _, spec in INDEX_TAGS do
		for _, inst in CollectionService:GetTagged(spec.Tag) do
			local id = inst:GetAttribute(spec.Attribute)
			if type(id) == "string" and inst:IsA("BasePart") then
				index:SetAttribute(spec.Kind .. "_" .. id, inst.Position)
			end
		end
	end
	index.Parent = ReplicatedStorage
end

function WorldBuilder.build()
	if WorldBuilder.Built then
		return
	end
	local started = os.clock()
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "World"
	local lightingOk, lightingErr = pcall(function()
		setupLighting()
	end)
	if not lightingOk then
		Log.error("World", "lighting failed:", lightingErr)
	end

	local order = {
		"House",
		"FloorWorld",
		"Bedroom",
		"Kitchen",
		"Backyard",
		"Neighborhood",
		"Downtown",
		"TitanCity",
		"TitanWilderness",
	}
	for _, name in order do
		local module = Regions:FindFirstChild(name)
		if module and module:IsA("ModuleScript") then
			local ok, err = pcall(function()
				(require(module) :: any).build(root)
			end)
			if not ok then
				Log.error("World", "region", name, "failed to build:", err)
			end
		end
	end
	local ok, err = pcall(function()
		CourseBuilder.build(root)
		CourseBuilder.buildPads(root)
	end)
	if not ok then
		Log.error("World", "courses failed:", err)
	end
	local function step(name: string, fn: () -> ())
		local stepOk, stepErr = pcall(function()
			fn()
		end)
		if not stepOk then
			Log.error("World", name, "failed:", stepErr)
		end
	end
	step("VIP lounge", function()
		buildVipLounge(root)
	end)
	root.Parent = workspace
	WorldBuilder.Built = true
	step("validation", validate)
	step("world index", publishIndex)
	Log.info("World", string.format("built %d parts in %.2fs", Kit.partCount(), os.clock() - started))
end

return WorldBuilder
