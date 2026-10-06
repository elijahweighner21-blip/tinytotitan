--!strict
--[[
	NPCConfig
	NPCs react to how big the player is RELATIVE to them:
	  Tiny     player < 0.5× NPC size
	  Similar  0.5× – 2×
	  Bigger   2× – 20×
	  Titan    > 20×
	`Remember` lines are used once the player has met them before and has
	since grown at least two tiers ("weren't you the little guy from earlier?").
]]

export type NPC = {
	Id: string,
	Name: string,
	Role: string,
	Zone: string,
	Scale: number,
	ShirtColor: Color3,
	Quests: { string },
	Menu: string?, -- UI menu opened by the "Open shop" style option
	Lines: {
		Tiny: { string },
		Similar: { string },
		Bigger: { string },
		Titan: { string },
	},
	Remember: { string },
}

local List: { NPC } = {
	{
		Id = "Mote",
		Name = "Professor Mote",
		Role = "Guide",
		Zone = "FloorWorld",
		Scale = 0.25,
		ShirtColor = Color3.fromRGB(240, 240, 255),
		Quests = { "FirstSteps", "OrbHunter", "CrumbClimber", "ShoeSummit", "QueenOfTheFloor" },
		Lines = {
			Tiny = { "Careful! Even I can see you're tiny.", "Stay close to the fibers. They're safer than they look." },
			Similar = { "You're tiny! But so am I. Let's fix that.", "Growth Orbs! Collect them and you'll grow. Trust me, I'm a professor." },
			Bigger = { "Goodness, you've grown! Mind where you step.", "My calculations said you'd grow. They did not say THIS much." },
			Titan = { "HOW ARE YOU THAT BIG?!", "I... I need to recalibrate my instruments. And my life." },
		},
		Remember = { "Wait... weren't you the little speck I found in the carpet?", "Look at you! I remember when a crumb was a mountain to you." },
	},
	{
		Id = "Merchant",
		Name = "Tiny Merchant",
		Role = "Merchant",
		Zone = "FloorWorld",
		Scale = 0.3,
		ShirtColor = Color3.fromRGB(255, 200, 80),
		Quests = {},
		Menu = "Shop",
		Lines = {
			Tiny = { "Psst! Trails, auras, shiny things. All fair prices." },
			Similar = { "Welcome, welcome! Have a look at today's specials." },
			Bigger = { "Big customer! Big savings! ...Not really, but browse anyway." },
			Titan = { "Please don't sit on my shop." },
		},
		Remember = { "My best customer! You've grown since your first trail." },
	},
	{
		Id = "Pip",
		Name = "Pip the Explorer",
		Role = "Quest",
		Zone = "Bedroom",
		Scale = 0.6,
		ShirtColor = Color3.fromRGB(110, 200, 120),
		Quests = { "BedroomExpedition", "CableClimber", "DeskSummit", "ForgottenVent", "VacuumHunt" },
		Lines = {
			Tiny = { "Whoa, a fellow tiny adventurer! Ever been under the bed?" },
			Similar = { "The desk is my Everest. Want to race me to the top?" },
			Bigger = { "You're so big now. Could you carry me to the windowsill?" },
			Titan = { "I'm going to need a much bigger map." },
		},
		Remember = { "I remember you! You couldn't even climb a sock back then." },
	},
	{
		Id = "LabTech",
		Name = "Lab Tech Nova",
		Role = "Upgrades",
		Zone = "Bedroom",
		Scale = 0.7,
		ShirtColor = Color3.fromRGB(80, 220, 255),
		Quests = { "LabWork" },
		Menu = "Upgrades",
		Lines = {
			Tiny = { "Welcome to the Growth Laboratory. Growth Energy goes in, better you comes out." },
			Similar = { "Your readings are fascinating. Want to tune your legs a bit?" },
			Bigger = { "The upgrade bench may be a bit small for you now. Still works!" },
			Titan = { "Please upgrade carefully. The lab is load-bearing." },
		},
		Remember = { "Subject has grown well beyond projections. Excellent. Terrifying." },
	},
	{
		Id = "Crumb",
		Name = "Chef Crumb",
		Role = "Quest",
		Zone = "Kitchen",
		Scale = 1.4,
		ShirtColor = Color3.fromRGB(255, 255, 255),
		Quests = { "KitchenCrossing", "TheGreatClimb", "SugarRush", "BehindTheFridge", "RoachRiot" },
		Lines = {
			Tiny = { "Mind the droplets, little one. A single drop could wash you away." },
			Similar = { "The table's the summit of this kitchen. Spoons make decent bridges." },
			Bigger = { "Careful with your elbows, you'll knock the cereal over." },
			Titan = { "You're bigger than the whole house!" },
		},
		Remember = { "You were the one hiding in the cereal box! Look at you now!" },
	},
	{
		Id = "Fern",
		Name = "Gardener Fern",
		Role = "Quest",
		Zone = "Backyard",
		Scale = 3.5,
		ShirtColor = Color3.fromRGB(120, 180, 80),
		Quests = { "IntoTheWild", "GardenGuardian", "ShedSecrets", "MowerMenace", "FenceJumper" },
		Lines = {
			Tiny = { "The grass is a forest at your size. Stay on the stones." },
			Similar = { "Help me with the garden and I'll show you where the gnome hides." },
			Bigger = { "You could hop that fence now, couldn't you?" },
			Titan = { "Please don't step on my tomatoes. Or my house." },
		},
		Remember = { "I watched you crawl out of that pet door. Now look at you." },
	},
	{
		Id = "Bolt",
		Name = "Officer Bolt",
		Role = "Quest",
		Zone = "Neighborhood",
		Scale = 14,
		ShirtColor = Color3.fromRGB(40, 70, 160),
		Quests = { "NewInTown", "DroneTrouble", "StormDrain", "CraneClimb", "ValeHouse" },
		Lines = {
			Tiny = { "Huh? Did someone say something? Down there?" },
			Similar = { "Welcome to the neighborhood. Stay off the roads, there's drones about." },
			Bigger = { "Sir, you'll need a permit to be that tall." },
			Titan = { "I'm not paid enough for this." },
		},
		Remember = { "Wait... weren't you the little guy from earlier?" },
	},
	{
		Id = "Vale",
		Name = "Dr. Iris Vale",
		Role = "Story",
		Zone = "Downtown",
		Scale = 16,
		ShirtColor = Color3.fromRGB(220, 220, 230),
		Quests = { "ValeIndustries", "GuardianDown", "RooftopRace", "TitanProtocol" },
		Lines = {
			Tiny = { "You... you're one of my growth subjects. The serum worked?" },
			Similar = { "The Titan Shards power everything I built. Bring me more and I'll explain." },
			Bigger = { "The machines aren't mine anymore. Something took control of them." },
			Titan = { "You're exactly what the Titan Engine was meant to create. I'm sorry." },
		},
		Remember = { "I thought you were lost in the carpet experiment. You survived." },
	},
	{
		Id = "Archivist",
		Name = "The Archivist",
		Role = "Story",
		Zone = "TitanCity",
		Scale = 130,
		ShirtColor = Color3.fromRGB(255, 200, 90),
		Quests = { "CityOfGiants", "ForgeFire", "ArchiveVault" },
		Menu = "Ascension",
		Lines = {
			Tiny = { "A visitor? So small. The city was not built for you yet." },
			Similar = { "Welcome, Titan. This city waited a thousand years for someone your size." },
			Bigger = { "You have outgrown even us. Ascension awaits." },
			Titan = { "The Records foretold you." },
		},
		Remember = { "The Records mentioned a speck that would become a mountain." },
	},
	{
		Id = "Broker",
		Name = "Titan Exchange Broker",
		Role = "Merchant",
		Zone = "TitanCity",
		Scale = 120,
		ShirtColor = Color3.fromRGB(60, 60, 80),
		Quests = {},
		Menu = "Shop",
		Lines = {
			Tiny = { "We don't usually serve... specks." },
			Similar = { "The Titan Exchange. Premium wares for premium sizes." },
			Bigger = { "Even titans need to look good." },
			Titan = { "Our finest auras, sized for you." },
		},
		Remember = { "Returning customer. A big one." },
	},
	{
		Id = "Elder",
		Name = "Elder Titan Oro",
		Role = "Story",
		Zone = "TitanWilderness",
		Scale = 300,
		ShirtColor = Color3.fromRGB(160, 120, 220),
		Quests = { "WildernessCall", "PeakPilgrimage", "TombOfTheFirst", "ColossusAwakens" },
		Lines = {
			Tiny = { "Little one. You should not be here... yet." },
			Similar = { "You have come far. The Colossus sleeps beyond the peak." },
			Bigger = { "Even I must look up to you now." },
			Titan = { "The world is small again. Remember how it felt when it was huge." },
		},
		Remember = { "I remember the tremor when you first stepped into this valley." },
	},
}

local byId: { [string]: NPC } = {}
for _, def in List do
	byId[def.Id] = def
end

local NPCConfig = {
	List = List,
	TalkRangeMultiplier = 3, -- max talk distance in max(player height, npc height)
}

function NPCConfig.get(id: string): NPC?
	return byId[id]
end

function NPCConfig.relativeSize(playerScale: number, npcScale: number): "Tiny" | "Similar" | "Bigger" | "Titan"
	local ratio = playerScale / npcScale
	if ratio < 0.5 then
		return "Tiny"
	elseif ratio < 2 then
		return "Similar"
	elseif ratio < 20 then
		return "Bigger"
	end
	return "Titan"
end

return NPCConfig
