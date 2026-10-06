--!strict
--[[
	ZoneConfig
	Region definitions. Bounds are axis-aligned boxes used for zone detection
	(server: enforcement / discovery / quests, client: music, lighting, HUD).
	Zones are checked in `Order`, so nested rooms (the house) win over the
	neighbourhood box that surrounds them.

	World scale: Human tier (scale 16) ≈ 80 studs tall → 1 ft ≈ 13.3 studs.
]]

local Types = require(script.Parent.Parent.Types)

type Zone = Types.Zone

local Zones: { Zone } = {
	{
		Id = "FloorWorld",
		Name = "Floor World",
		Order = 1,
		RequiredTier = 1,
		RecommendedTiers = { 1, 4 },
		RewardScale = 1,
		Resource = nil,
		Center = Vector3.new(160, 70, 160),
		Size = Vector3.new(320, 140, 320),
		Spawn = Vector3.new(46, 2, 282),
		MapColor = Color3.fromRGB(196, 160, 120),
		Description = "The living-room carpet. A jungle of fibers, crumbs and lost coins.",
		Ambience = "Indoor",
		Lighting = "Indoor",
	},
	{
		Id = "Bedroom",
		Name = "Bedroom",
		Order = 2,
		RequiredTier = 3,
		RecommendedTiers = { 3, 6 },
		RewardScale = 6,
		Resource = "DustCores",
		Center = Vector3.new(-140, 70, 10),
		Size = Vector3.new(280, 140, 620),
		Spawn = Vector3.new(-30, 2, 240),
		MapColor = Color3.fromRGB(120, 140, 200),
		Description = "Furniture mountains, cable vines, a playroom and a vent nobody remembers.",
		Ambience = "Bedroom",
		Lighting = "Indoor",
	},
	{
		Id = "Kitchen",
		Name = "Kitchen",
		Order = 3,
		RequiredTier = 5,
		RecommendedTiers = { 5, 8 },
		RewardScale = 25,
		Resource = "SugarCrystals",
		Center = Vector3.new(160, 70, -150),
		Size = Vector3.new(320, 140, 300),
		Spawn = Vector3.new(170, 2, -30),
		MapColor = Color3.fromRGB(230, 230, 210),
		Description = "Counters like cliffs, a humming refrigerator and treacherous droplets.",
		Ambience = "Kitchen",
		Lighting = "Kitchen",
	},
	{
		Id = "Backyard",
		Name = "Backyard",
		Order = 4,
		RequiredTier = 7,
		RecommendedTiers = { 7, 9 },
		RewardScale = 90,
		Resource = "NatureEssence",
		Center = Vector3.new(160, 600, -750),
		Size = Vector3.new(1120, 1200, 900),
		Spawn = Vector3.new(265, 2, -370),
		MapColor = Color3.fromRGB(110, 180, 90),
		Description = "A grass forest, a garden, a shed and a terrifying lawnmower.",
		Ambience = "Outdoor",
		Lighting = "Outdoor",
	},
	{
		Id = "Neighborhood",
		Name = "Neighborhood",
		Order = 5,
		RequiredTier = 9,
		RecommendedTiers = { 9, 10 },
		RewardScale = 300,
		Resource = "Scrap",
		Center = Vector3.new(400, 2000, -500),
		Size = Vector3.new(6000, 4000, 5400),
		Spawn = Vector3.new(265, 2, -1380),
		MapColor = Color3.fromRGB(160, 160, 150),
		Description = "Streets, houses, a playground and a construction site.",
		Ambience = "Suburb",
		Lighting = "Outdoor",
	},
	{
		Id = "Downtown",
		Name = "Downtown",
		Order = 6,
		RequiredTier = 10,
		RecommendedTiers = { 10, 12 },
		RewardScale = 1000,
		Resource = "Scrap",
		Center = Vector3.new(400, 2500, 5200),
		Size = Vector3.new(6000, 5000, 6000),
		Spawn = Vector3.new(400, 2, 2350),
		MapColor = Color3.fromRGB(90, 110, 140),
		Description = "Towers, rooftops and security drones that do not like visitors.",
		Ambience = "City",
		Lighting = "City",
	},
	{
		Id = "TitanCity",
		Name = "Titan City",
		Order = 7,
		RequiredTier = 12,
		RecommendedTiers = { 12, 14 },
		RewardScale = 3500,
		Resource = "TitanCells",
		Center = Vector3.new(7700, 3000, 2500),
		Size = Vector3.new(8600, 6000, 11400),
		Spawn = Vector3.new(4200, 2, 2500),
		MapColor = Color3.fromRGB(255, 190, 70),
		Description = "A city built for giants by someone who expected you.",
		Ambience = "Titan",
		Lighting = "Titan",
	},
	{
		Id = "TitanWilderness",
		Name = "Titan Wilderness",
		Order = 8,
		RequiredTier = 13,
		RecommendedTiers = { 13, 15 },
		RewardScale = 10000,
		Resource = "TitanCells",
		Center = Vector3.new(-8300, 4000, 1100),
		Size = Vector3.new(11400, 8000, 14200),
		Spawn = Vector3.new(-3400, 2, 1100),
		MapColor = Color3.fromRGB(150, 110, 200),
		Description = "Mountains, valleys and ruins of the first Titans.",
		Ambience = "Wild",
		Lighting = "Wild",
	},
}

table.sort(Zones, function(a, b)
	return a.Order < b.Order
end)

local byId: { [string]: Zone } = {}
for _, zone in Zones do
	byId[zone.Id] = zone
end

local ZoneConfig = {
	Zones = Zones,
	DefaultZone = "FloorWorld",
	-- How long a player may stand inside a zone they have not unlocked before
	-- the server returns them to safety (generous to absorb lag at boundaries).
	TrespassGraceSeconds = 2.5,
}

function ZoneConfig.get(id: string): Zone?
	return byId[id]
end

function ZoneConfig.contains(zone: Zone, position: Vector3): boolean
	local half = zone.Size / 2
	local d = position - zone.Center
	return math.abs(d.X) <= half.X and math.abs(d.Y) <= half.Y and math.abs(d.Z) <= half.Z
end

-- Returns the first zone (by Order) containing the position. Callers pass the
-- character's FEET position so giant players standing in a room still count
-- as being in that room.
function ZoneConfig.zoneAt(position: Vector3): Zone?
	for _, zone in Zones do
		if ZoneConfig.contains(zone, position) then
			return zone
		end
	end
	return nil
end

-- Highest zone whose RequiredTier the given tier satisfies.
function ZoneConfig.highestUnlocked(tier: number): Zone
	local best = Zones[1]
	for _, zone in Zones do
		if tier >= zone.RequiredTier and zone.Order > best.Order then
			best = zone
		end
	end
	return best
end

return ZoneConfig
