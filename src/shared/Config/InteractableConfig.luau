--!strict
--[[
	InteractableConfig
	Object physics rules. Whether a player may push / carry / throw / break an
	object depends on their Strength-derived stats (Formulas/Stats.derive)
	compared to these thresholds — so the same soda can is a wall for an ant,
	a pushable block for a toy-sized player and a projectile for a giant.

	Strength reference (base, no upgrades): scale 1.5 ≈ 18, 3 ≈ 47, 7 ≈ 153,
	16 ≈ 485, 60 ≈ 3,100, 120 ≈ 8,200, 340 ≈ 35,000.
]]

export type ObjectDef = {
	Id: string,
	Name: string,
	Push: number?,
	Carry: number?,
	Throw: number?,
	Break: number?, -- break power needed; object has Health hits
	Health: number?,
	Respawn: number,
	Reward: { Mass: number?, GrowthEnergy: number?, XP: number? }?,
	ZoneScaled: boolean?,
}

local List: { ObjectDef } = {
	-- Floor World
	{ Id = "Marble", Name = "Marble", Push = 3, Carry = 6, Throw = 15, Respawn = 40 },
	{ Id = "BottleCap", Name = "Bottle Cap", Push = 2, Carry = 4, Throw = 10, Respawn = 40 },
	{ Id = "Domino", Name = "Domino", Push = 4, Respawn = 30, Reward = { Mass = 4 }, ZoneScaled = true },
	{
		Id = "CrumbChunk",
		Name = "Cracker Crumb",
		Break = 1,
		Health = 3,
		Respawn = 45,
		Reward = { Mass = 8, GrowthEnergy = 4 },
		ZoneScaled = true,
	},
	{
		Id = "DustClump",
		Name = "Dust Clump",
		Break = 0.5,
		Health = 2,
		Respawn = 35,
		Reward = { Mass = 5, GrowthEnergy = 3 },
		ZoneScaled = true,
	},
	-- Bedroom
	{ Id = "Eraser", Name = "Eraser", Push = 6, Carry = 14, Throw = 35, Respawn = 40 },
	{ Id = "ToyBlock", Name = "Toy Block", Push = 10, Carry = 22, Throw = 55, Respawn = 45 },
	{ Id = "Dice", Name = "Giant Die", Push = 8, Carry = 18, Throw = 45, Respawn = 40 },
	{
		Id = "ToyTower",
		Name = "Toy Block Tower",
		Break = 6,
		Health = 4,
		Respawn = 60,
		Reward = { Mass = 10, GrowthEnergy = 6 },
		ZoneScaled = true,
	},
	{
		Id = "PaperStack",
		Name = "Paper Stack",
		Break = 4,
		Health = 3,
		Respawn = 50,
		Reward = { Mass = 8, GrowthEnergy = 5 },
		ZoneScaled = true,
	},
	-- Kitchen
	{ Id = "SodaCan", Name = "Soda Can", Push = 25, Carry = 80, Throw = 200, Respawn = 45 },
	{ Id = "Apple", Name = "Apple", Push = 18, Carry = 55, Throw = 140, Respawn = 45 },
	{ Id = "Spoon", Name = "Spoon", Push = 12, Carry = 30, Throw = 80, Respawn = 40 },
	{
		Id = "CerealBox",
		Name = "Cereal Box",
		Break = 20,
		Health = 4,
		Respawn = 60,
		Reward = { Mass = 12, GrowthEnergy = 8 },
		ZoneScaled = true,
	},
	{
		Id = "EggCarton",
		Name = "Egg Carton",
		Break = 14,
		Health = 3,
		Respawn = 60,
		Reward = { Mass = 10, GrowthEnergy = 7 },
		ZoneScaled = true,
	},
	-- Backyard
	{ Id = "FlowerPot", Name = "Flower Pot", Push = 90, Carry = 220, Throw = 500, Respawn = 50 },
	{ Id = "GardenGnome", Name = "Garden Gnome", Push = 70, Carry = 180, Throw = 420, Respawn = 50 },
	{ Id = "TennisBall", Name = "Tennis Ball", Push = 30, Carry = 60, Throw = 140, Respawn = 40 },
	{
		Id = "Crate",
		Name = "Wooden Crate",
		Break = 80,
		Health = 4,
		Respawn = 70,
		Reward = { Mass = 14, GrowthEnergy = 9 },
		ZoneScaled = true,
	},
	-- Neighborhood
	{
		Id = "TrafficCone",
		Name = "Traffic Cone",
		Push = 220,
		Carry = 500,
		Throw = 1200,
		Break = 400,
		Health = 2,
		Respawn = 50,
		Reward = { Mass = 6 },
		ZoneScaled = true,
	},
	{ Id = "TrashBin", Name = "Trash Bin", Push = 400, Carry = 900, Throw = 2200, Respawn = 60 },
	{ Id = "Bench", Name = "Park Bench", Push = 700, Carry = 1500, Throw = 3500, Respawn = 60 },
	{ Id = "Car", Name = "Car", Push = 2500, Carry = 6000, Throw = 14000, Respawn = 90 },
	{
		Id = "Barricade",
		Name = "Construction Barricade",
		Break = 600,
		Health = 4,
		Respawn = 70,
		Reward = { Mass = 15, GrowthEnergy = 10 },
		ZoneScaled = true,
	},
	{
		Id = "StreetSign",
		Name = "Street Sign",
		Break = 450,
		Health = 3,
		Respawn = 60,
		Reward = { Mass = 10, GrowthEnergy = 6 },
		ZoneScaled = true,
	},
	-- Downtown
	{ Id = "Bus", Name = "City Bus", Push = 6000, Carry = 15000, Throw = 30000, Respawn = 90 },
	{ Id = "Dumpster", Name = "Dumpster", Push = 3500, Carry = 8000, Throw = 18000, Respawn = 70 },
	{
		Id = "BillboardPanel",
		Name = "Billboard Panel",
		Break = 3500,
		Health = 4,
		Respawn = 80,
		Reward = { Mass = 16, GrowthEnergy = 10 },
		ZoneScaled = true,
	},
	{
		Id = "WaterTank",
		Name = "Rooftop Water Tank",
		Break = 5000,
		Health = 5,
		Respawn = 90,
		Reward = { Mass = 18, GrowthEnergy = 12 },
		ZoneScaled = true,
	},
	-- Titan City / Wilderness
	{
		Id = "TitanPillar",
		Name = "Titan Pillar",
		Break = 12000,
		Health = 6,
		Respawn = 100,
		Reward = { Mass = 20, GrowthEnergy = 14 },
		ZoneScaled = true,
	},
	{
		Id = "Boulder",
		Name = "Boulder",
		Push = 15000,
		Carry = 30000,
		Throw = 60000,
		Break = 25000,
		Health = 6,
		Respawn = 100,
		Reward = { Mass = 18 },
		ZoneScaled = true,
	},
	{
		Id = "Monolith",
		Name = "Ancient Monolith",
		Break = 30000,
		Health = 8,
		Respawn = 120,
		Reward = { Mass = 30, GrowthEnergy = 20 },
		ZoneScaled = true,
	},
	-- Utility / gates
	{ Id = "PetDoor", Name = "Pet Door", Push = 40, Respawn = 6 },
	{ Id = "LockedDoor", Name = "Locked Door", Respawn = 8 },
}

local byId: { [string]: ObjectDef } = {}
for _, def in List do
	assert(byId[def.Id] == nil, "duplicate interactable " .. def.Id)
	byId[def.Id] = def
end

local InteractableConfig = {
	List = List,
	PushDistanceBodies = 2.2, -- how far a push slides the object (object sizes)
	PushDuration = 0.45,
	ThrowSpeedBodies = 9, -- launch speed in thrower body-heights per second
	ThrownLifetime = 6,
	DisplacedResetTime = 45, -- moved objects slide home after this long
	MaxActiveDebris = 60,
	DebrisLifetime = 3,
	PerObjectRewardCooldown = 90, -- per player, per object: anti-farming
}

function InteractableConfig.get(id: string): ObjectDef?
	return byId[id]
end

return InteractableConfig
