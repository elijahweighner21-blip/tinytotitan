--!strict
--[[
	LoreConfig
	Environmental storytelling. Lore entries are unlocked by discoveries
	(DiscoveryConfig.Lore) and by Memory Fragments (in collection order per
	zone). They are short on purpose: the mystery unfolds in fragments, never
	in cutscenes.

	Core mystery: Why can you keep growing? What are Titan Shards? Who built
	the Titan technology, and why are machines waking up?
]]

export type LoreEntry = { Id: string, Title: string, Text: string, Chapter: number }

local Entries: { LoreEntry } = {
	{
		Id = "Fragment_FloorWorld_1",
		Chapter = 1,
		Title = "A Spilled Vial",
		Text = "Glass on the carpet. A sweet smell. The label is half-dissolved: '...SERUM — BATCH 7'.",
	},
	{
		Id = "Fragment_FloorWorld_2",
		Chapter = 1,
		Title = "Subject 7",
		Text = "A scrap of paper: 'Subject 7 responded to shard exposure. Growth continuous. Do not let it reach the window.'",
	},
	{
		Id = "VentNote",
		Chapter = 1,
		Title = "Notebook in the Vent",
		Text = "'Day 41. The shards hum when they are near each other. The engine wants to be whole.' — I. Vale",
	},
	{
		Id = "Fragment_Bedroom_1",
		Chapter = 2,
		Title = "Childhood Drawing",
		Text = "A crayon drawing of a giant standing over a city. Signed: 'Iris, age 8'.",
	},
	{
		Id = "Fragment_Bedroom_2",
		Chapter = 2,
		Title = "The Security Contract",
		Text = "'Vale Industries will provide autonomous cleaning and security units.' The fine print mentions shard-powered cores.",
	},
	{
		Id = "PaintingSafe",
		Chapter = 2,
		Title = "Safe Behind the Painting",
		Text = "Inside: a photograph of a stone giant buried in a mountain, labelled 'COLOSSUS SITE — DO NOT EXCAVATE'.",
	},
	{
		Id = "Fragment_Kitchen_1",
		Chapter = 3,
		Title = "Recipe Card",
		Text = "Someone wrote a formula on the back of a cookie recipe. One ingredient is just a drawing of a crystal.",
	},
	{
		Id = "FridgeLab",
		Chapter = 3,
		Title = "The Hidden Workbench",
		Text = "Tools sized for something tiny. A note: 'If it works on me first, at least I'll know.'",
	},
	{
		Id = "Fragment_Kitchen_2",
		Chapter = 3,
		Title = "Power Bill",
		Text = "This house used more electricity than the entire neighborhood. Every month. For years.",
	},
	{
		Id = "GnomeTablet",
		Chapter = 4,
		Title = "The Gnome's Tablet",
		Text = "Carved under the gnome: the same symbol found on every Titan Shard. It is older than the house.",
	},
	{
		Id = "Fragment_Backyard_1",
		Chapter = 4,
		Title = "Buried Box",
		Text = "A tin box of shards, each humming in a different key. Together they almost sound like a heartbeat.",
	},
	{
		Id = "DrainLog",
		Chapter = 5,
		Title = "Maintenance Log",
		Text = "'Drones keep returning to the drain. Something down here is calling them. Or charging them.'",
	},
	{
		Id = "ValeLetter",
		Chapter = 5,
		Title = "A Letter for Iris",
		Text = "'Iris — the Titan Engine is awake. The shards are scattering. The machines obey it now, not us. Leave the city.'",
	},
	{
		Id = "Fragment_Neighborhood_1",
		Chapter = 5,
		Title = "Missing Poster",
		Text = "MISSING: Dr. Iris Vale. Last seen entering her own house. Reward offered.",
	},
	{
		Id = "ServerLog",
		Chapter = 6,
		Title = "Server Log 0xT1TAN",
		Text = "'ENGINE PRIORITY: locate growth candidate. ENGINE PRIORITY: protect candidate until maturity.'",
	},
	{
		Id = "Fragment_Downtown_1",
		Chapter = 6,
		Title = "Blueprint",
		Text = "GUARDIAN MK-IV was designed to protect a 'growing asset'. It was never meant to fight you. It was meant to guard you.",
	},
	{
		Id = "ArchiveRecord",
		Chapter = 7,
		Title = "The Records",
		Text = "'Every age, the Engine raises one Titan from the smallest of things. The Titan decides what the world becomes.'",
	},
	{
		Id = "Fragment_TitanCity_1",
		Chapter = 7,
		Title = "Forge Inscription",
		Text = "'We built this city for the one who would come. We will not live to see them.'",
	},
	{
		Id = "PeakInscription",
		Chapter = 8,
		Title = "Words on the Peak",
		Text = "'Look down. Remember the dust. Every mountain was once a crumb to someone.'",
	},
	{
		Id = "TombTruth",
		Chapter = 8,
		Title = "The Empty Tomb",
		Text = "The first Titan chose to sleep rather than rule. The Colossus is not a monster. It is a test.",
	},
	{
		Id = "Fragment_TitanWilderness_1",
		Chapter = 8,
		Title = "Final Fragment",
		Text = "A shard shaped like a key. Iris Vale's handwriting: 'Thank you. You finished what I started.'",
	},
}

local byId: { [string]: LoreEntry } = {}
for _, e in Entries do
	byId[e.Id] = e
end

local LoreConfig = { Entries = Entries }

function LoreConfig.get(id: string): LoreEntry?
	return byId[id]
end

return LoreConfig
