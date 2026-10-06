--!strict
--[[
	DiscoveryConfig
	Named locations. The world builder places a DiscoveryRegion box tagged with
	each Id; DiscoveryService awards the first visit. `MaxTier` marks places
	only reachable while small (revisit with Shrink Mode). `Hidden` locations
	are not shown on the map until found.
]]

export type Discovery = {
	Id: string,
	Name: string,
	Zone: string,
	Weight: number,
	Hidden: boolean?,
	MaxTier: number?,
	Lore: string?,
}

local List: { Discovery } = {
	-- Floor World
	{ Id = "RugEdge", Name = "The Rug Cliffs", Zone = "FloorWorld", Weight = 1 },
	{ Id = "CrumbMountain", Name = "Crumb Mountain", Zone = "FloorWorld", Weight = 1 },
	{ Id = "CoinCanyon", Name = "Coin Canyon", Zone = "FloorWorld", Weight = 1.2 },
	{ Id = "WireJungle", Name = "The Wire Jungle", Zone = "FloorWorld", Weight = 1.2 },
	{ Id = "ShoeSummit", Name = "Top of the Shoe", Zone = "FloorWorld", Weight = 2.5 },
	{ Id = "CrackCave", Name = "The Floor Crack", Zone = "FloorWorld", Weight = 2, Hidden = true, MaxTier = 4 },
	{ Id = "UnderTheCouch", Name = "Under the Couch", Zone = "FloorWorld", Weight = 2, MaxTier = 6 },
	{ Id = "DustBunnyNest", Name = "Dust Bunny Nest", Zone = "FloorWorld", Weight = 2.5, Hidden = true },
	{ Id = "TVStandTop", Name = "Top of the TV Stand", Zone = "FloorWorld", Weight = 3 },
	-- Bedroom
	{ Id = "UnderTheBed", Name = "Under the Bed", Zone = "Bedroom", Weight = 1.5 },
	{ Id = "CableVines", Name = "Cable Vines", Zone = "Bedroom", Weight = 1 },
	{ Id = "DeskSummit", Name = "The Desktop", Zone = "Bedroom", Weight = 2.5 },
	{ Id = "DresserPeak", Name = "Dresser Peak", Zone = "Bedroom", Weight = 2 },
	{ Id = "TopShelf", Name = "The Top Shelf", Zone = "Bedroom", Weight = 3 },
	{ Id = "Windowsill", Name = "The Windowsill", Zone = "Bedroom", Weight = 3 },
	{ Id = "ToyChest", Name = "The Toy Chest", Zone = "Bedroom", Weight = 1.5 },
	{
		Id = "ForgottenVent",
		Name = "The Forgotten Vent",
		Zone = "Bedroom",
		Weight = 4,
		Hidden = true,
		MaxTier = 6,
		Lore = "VentNote",
	},
	{
		Id = "BehindThePainting",
		Name = "Behind the Painting",
		Zone = "Bedroom",
		Weight = 4,
		Hidden = true,
		Lore = "PaintingSafe",
	},
	-- Kitchen
	{ Id = "CerealWreck", Name = "The Cereal Wreck", Zone = "Kitchen", Weight = 1 },
	{ Id = "TableSummit", Name = "The Great Table", Zone = "Kitchen", Weight = 2.5 },
	{ Id = "CounterCliffs", Name = "Counter Cliffs", Zone = "Kitchen", Weight = 2 },
	{ Id = "SinkBasin", Name = "The Sink Basin", Zone = "Kitchen", Weight = 2 },
	{ Id = "StoveTop", Name = "The Stovetop", Zone = "Kitchen", Weight = 2 },
	{ Id = "TrashMountain", Name = "Trash Mountain", Zone = "Kitchen", Weight = 1.5 },
	{ Id = "FridgeTop", Name = "On Top of the Fridge", Zone = "Kitchen", Weight = 3.5 },
	{
		Id = "BehindTheFridge",
		Name = "Behind the Refrigerator",
		Zone = "Kitchen",
		Weight = 4,
		Hidden = true,
		MaxTier = 7,
		Lore = "FridgeLab",
	},
	{ Id = "UnderTheOven", Name = "Under the Oven", Zone = "Kitchen", Weight = 3, Hidden = true, MaxTier = 6 },
	-- Backyard
	{ Id = "GrassForest", Name = "The Grass Forest", Zone = "Backyard", Weight = 1 },
	{ Id = "GardenRows", Name = "Garden Rows", Zone = "Backyard", Weight = 1.5 },
	{ Id = "PatioTable", Name = "Patio Table", Zone = "Backyard", Weight = 1.5 },
	{ Id = "PoolDeck", Name = "The Pool Deck", Zone = "Backyard", Weight = 2 },
	{ Id = "ShedInterior", Name = "Inside the Shed", Zone = "Backyard", Weight = 2.5 },
	{ Id = "BirdbathSummit", Name = "Birdbath Summit", Zone = "Backyard", Weight = 2 },
	{ Id = "OakCanopy", Name = "The Oak Canopy", Zone = "Backyard", Weight = 3.5 },
	{ Id = "FenceTop", Name = "Top of the Fence", Zone = "Backyard", Weight = 3 },
	{
		Id = "GnomeShrine",
		Name = "The Gnome Shrine",
		Zone = "Backyard",
		Weight = 4,
		Hidden = true,
		Lore = "GnomeTablet",
	},
	-- Neighborhood
	{ Id = "Playground", Name = "The Playground", Zone = "Neighborhood", Weight = 1 },
	{ Id = "ParkFountain", Name = "Park Fountain", Zone = "Neighborhood", Weight = 1.5 },
	{ Id = "OldMailbox", Name = "The Old Mailbox", Zone = "Neighborhood", Weight = 1.5 },
	{ Id = "ConstructionCrane", Name = "Construction Crane", Zone = "Neighborhood", Weight = 3 },
	{ Id = "WaterTower", Name = "The Water Tower", Zone = "Neighborhood", Weight = 3.5 },
	{ Id = "RooftopRun", Name = "Neighborhood Rooftops", Zone = "Neighborhood", Weight = 2 },
	{
		Id = "StormDrain",
		Name = "The Storm Drain",
		Zone = "Neighborhood",
		Weight = 4,
		Hidden = true,
		MaxTier = 8,
		Lore = "DrainLog",
	},
	{ Id = "ValeHouse", Name = "The Vale House", Zone = "Neighborhood", Weight = 3, Lore = "ValeLetter" },
	-- Downtown
	{ Id = "SubwayEntrance", Name = "Subway Entrance", Zone = "Downtown", Weight = 1 },
	{ Id = "ParkingSpiral", Name = "The Parking Spiral", Zone = "Downtown", Weight = 1.5 },
	{ Id = "ClockTower", Name = "The Clock Tower", Zone = "Downtown", Weight = 2.5 },
	{ Id = "BillboardLedge", Name = "Billboard Ledge", Zone = "Downtown", Weight = 2 },
	{ Id = "SkyBridge", Name = "The Sky Bridge", Zone = "Downtown", Weight = 2.5 },
	{ Id = "HighestRooftop", Name = "Highest Rooftop", Zone = "Downtown", Weight = 4 },
	{
		Id = "ServerRoom",
		Name = "Vale Industries Server Room",
		Zone = "Downtown",
		Weight = 4,
		Hidden = true,
		MaxTier = 9,
		Lore = "ServerLog",
	},
	-- Titan City
	{ Id = "TitanGate", Name = "The Titan Gate", Zone = "TitanCity", Weight = 1 },
	{ Id = "ColossusPlaza", Name = "Colossus Plaza", Zone = "TitanCity", Weight = 1.5 },
	{ Id = "TitanForge", Name = "The Titan Forge", Zone = "TitanCity", Weight = 2 },
	{ Id = "SkyHarbor", Name = "Sky Harbor", Zone = "TitanCity", Weight = 2.5 },
	{ Id = "CoreSpire", Name = "The Core Spire", Zone = "TitanCity", Weight = 4 },
	{
		Id = "ArchiveVault",
		Name = "The Archive Vault",
		Zone = "TitanCity",
		Weight = 4,
		Hidden = true,
		MaxTier = 10,
		Lore = "ArchiveRecord",
	},
	-- Titan Wilderness
	{ Id = "CrystalValley", Name = "Crystal Valley", Zone = "TitanWilderness", Weight = 1 },
	{ Id = "AncientRuins", Name = "Ancient Ruins", Zone = "TitanWilderness", Weight = 2 },
	{ Id = "SkyFalls", Name = "Sky Falls", Zone = "TitanWilderness", Weight = 2.5 },
	{ Id = "ColossusArena", Name = "The Colossus Arena", Zone = "TitanWilderness", Weight = 3 },
	{ Id = "TitanPeak", Name = "Titan Peak", Zone = "TitanWilderness", Weight = 5, Lore = "PeakInscription" },
	{
		Id = "FirstTitanTomb",
		Name = "Tomb of the First Titan",
		Zone = "TitanWilderness",
		Weight = 5,
		Hidden = true,
		MaxTier = 11,
		Lore = "TombTruth",
	},
}

local byId: { [string]: Discovery } = {}
for _, d in List do
	assert(byId[d.Id] == nil, "duplicate discovery " .. d.Id)
	byId[d.Id] = d
end

local DiscoveryConfig = {
	List = List,
	TitanShardsForHidden = 5,
}

function DiscoveryConfig.get(id: string): Discovery?
	return byId[id]
end

return DiscoveryConfig
