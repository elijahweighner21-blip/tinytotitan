--!strict
--[[
	CosmeticConfig
	Purely visual items. `Style` selects a renderer in the client
	CosmeticsController; `Colors` parameterise it. Cosmetics never change
	gameplay stats.

	Sources: "Shop" (Growth Energy / Titan Shards), "Achievement", "Boss",
	"Pass", "Bundle", "Event", "Ascension", "Daily" (rotating shop pool).
	Limited items carry Start/End unix timestamps (UTC) and disappear from the
	shop automatically outside that window; owned copies are kept forever.
]]

local Types = require(script.Parent.Parent.Types)

type Cosmetic = Types.Cosmetic

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Categories = {
	{ Id = "Trail", Name = "Trails", Icon = "〰️", BaseSlots = 1, PassSlots = 3 },
	{ Id = "Aura", Name = "Auras", Icon = "✨", BaseSlots = 1, PassSlots = 2 },
	{ Id = "Footstep", Name = "Footsteps", Icon = "👣", BaseSlots = 1, PassSlots = 1 },
	{ Id = "Landing", Name = "Landing Effects", Icon = "💥", BaseSlots = 1, PassSlots = 1 },
	{ Id = "Dash", Name = "Dash Effects", Icon = "💨", BaseSlots = 1, PassSlots = 1 },
	{ Id = "Growth", Name = "Growth Effects", Icon = "🌟", BaseSlots = 1, PassSlots = 1 },
	{ Id = "NameColor", Name = "Name Colors", Icon = "🎨", BaseSlots = 1, PassSlots = 1 },
}

local List: { Cosmetic } = {
	-- Trails -----------------------------------------------------------------
	{ Id = "BasicTrail", Name = "Stardust Trail", Category = "Trail", Rarity = "Common", Description = "A soft sparkle behind you.", Colors = { rgb(200, 230, 255) }, Style = "Ribbon", Source = "Shop", Price = { Currency = "GrowthEnergy", Amount = 500 } },
	{ Id = "EmberTrail", Name = "Ember Trail", Category = "Trail", Rarity = "Uncommon", Description = "Warm sparks that drift upward.", Colors = { rgb(255, 140, 40), rgb(255, 60, 20) }, Style = "Sparks", Source = "Shop", Price = { Currency = "GrowthEnergy", Amount = 4000 } },
	{ Id = "AquaTrail", Name = "Droplet Trail", Category = "Trail", Rarity = "Uncommon", Description = "A shimmering water ribbon.", Colors = { rgb(80, 200, 255), rgb(200, 250, 255) }, Style = "Ribbon", Source = "Daily", Price = { Currency = "GrowthEnergy", Amount = 6000 } },
	{ Id = "RainbowTrail", Name = "Prism Trail", Category = "Trail", Rarity = "Epic", Description = "All the colors, all the time.", Colors = { rgb(255, 80, 80), rgb(255, 220, 80), rgb(80, 255, 120), rgb(80, 160, 255), rgb(200, 80, 255) }, Style = "Ribbon", Source = "Shop", Price = { Currency = "TitanShards", Amount = 120 } },
	{ Id = "AntTrail", Name = "Marching Ants", Category = "Trail", Rarity = "Rare", Description = "A tiny procession follows you. Earned by defeating THE QUEEN.", Colors = { rgb(60, 30, 20) }, Style = "Dots", Source = "Boss" },
	{ Id = "CloverTrail", Name = "Clover Trail", Category = "Trail", Rarity = "Rare", Description = "Lucky leaves. Earned by defeating THE LAWNMOWER.", Colors = { rgb(90, 200, 80), rgb(160, 255, 140) }, Style = "Leaves", Source = "Boss" },
	{ Id = "StarfallTrail", Name = "Starfall Trail", Category = "Trail", Rarity = "Legendary", Description = "Falling stars. Earned by defeating THE COLOSSUS.", Colors = { rgb(255, 255, 200), rgb(180, 140, 255) }, Style = "Sparks", Source = "Boss" },
	{ Id = "VIPTrail", Name = "Golden Ribbon", Category = "Trail", Rarity = "Exclusive", Description = "VIP exclusive.", Colors = { rgb(255, 215, 0), rgb(255, 250, 200) }, Style = "Ribbon", Source = "Pass" },
	{ Id = "TitanTrail", Name = "Titan Trail", Category = "Trail", Rarity = "Exclusive", Description = "Titan Cosmetic Pack exclusive.", Colors = { rgb(255, 170, 40), rgb(255, 80, 20) }, Style = "Sparks", Source = "Pass" },
	{ Id = "StarterTrail", Name = "Sprout Trail", Category = "Trail", Rarity = "Rare", Description = "Starter Pack exclusive.", Colors = { rgb(140, 255, 160) }, Style = "Leaves", Source = "Bundle" },
	{ Id = "ExplorerTrail", Name = "Compass Trail", Category = "Trail", Rarity = "Epic", Description = "Explorer Bundle exclusive.", Colors = { rgb(200, 160, 255), rgb(255, 255, 255) }, Style = "Dots", Source = "Bundle" },
	{ Id = "SpeedTrail", Name = "Speed Lines", Category = "Trail", Rarity = "Rare", Description = "Earned with 10 Titan medals.", Colors = { rgb(120, 220, 255) }, Style = "Ribbon", Source = "Achievement" },
	-- Halloween / Winter / Anniversary / Titan Week (limited) ---------------------
	{ Id = "PumpkinTrail", Name = "Pumpkin Patch Trail", Category = "Trail", Rarity = "Limited", Description = "Halloween limited.", Colors = { rgb(255, 120, 0), rgb(60, 20, 80) }, Style = "Sparks", Source = "Event", Price = { Currency = "TitanShards", Amount = 90 }, Limited = { Start = 1790812800, End = 1794009600, Event = "Halloween" } },
	{ Id = "SpookAura", Name = "Spooky Mist", Category = "Aura", Rarity = "Limited", Description = "Halloween limited.", Colors = { rgb(120, 60, 160), rgb(40, 255, 120) }, Style = "Mist", Source = "Event", Price = { Currency = "GrowthEnergy", Amount = 25000 }, Limited = { Start = 1790812800, End = 1794009600, Event = "Halloween" } },
	{ Id = "SnowAura", Name = "Snowfall Aura", Category = "Aura", Rarity = "Limited", Description = "Winter limited.", Colors = { rgb(240, 250, 255) }, Style = "Snow", Source = "Event", Price = { Currency = "TitanShards", Amount = 100 }, Limited = { Start = 1796083200, End = 1798761600, Event = "Winter" } },
	{ Id = "AnniversaryTrail", Name = "Confetti Trail", Category = "Trail", Rarity = "Limited", Description = "Anniversary limited.", Colors = { rgb(255, 100, 150), rgb(100, 200, 255), rgb(255, 230, 90) }, Style = "Dots", Source = "Event", Price = { Currency = "GrowthEnergy", Amount = 30000 }, Limited = { Start = 1814400000, End = 1815609600, Event = "Anniversary" } },
	{ Id = "TitanWeekAura", Name = "Titan Week Halo", Category = "Aura", Rarity = "Limited", Description = "Titan Week limited.", Colors = { rgb(255, 200, 60) }, Style = "Halo", Source = "Event", Price = { Currency = "TitanShards", Amount = 150 }, Limited = { Start = 1804982400, End = 1805587200, Event = "TitanWeek" } },
	-- Auras ---------------------------------------------------------------------
	{ Id = "GlowAura", Name = "Soft Glow", Category = "Aura", Rarity = "Common", Description = "A gentle light around you.", Colors = { rgb(200, 240, 255) }, Style = "Glow", Source = "Shop", Price = { Currency = "GrowthEnergy", Amount = 1500 } },
	{ Id = "LeafAura", Name = "Leaf Swirl", Category = "Aura", Rarity = "Uncommon", Description = "Leaves orbit you.", Colors = { rgb(110, 200, 90) }, Style = "Orbit", Source = "Daily", Price = { Currency = "GrowthEnergy", Amount = 9000 } },
	{ Id = "FlameAura", Name = "Flame Aura", Category = "Aura", Rarity = "Epic", Description = "Stylish, harmless fire.", Colors = { rgb(255, 120, 30), rgb(255, 220, 80) }, Style = "Flame", Source = "Shop", Price = { Currency = "TitanShards", Amount = 150 } },
	{ Id = "VacuumAura", Name = "Static Field", Category = "Aura", Rarity = "Rare", Description = "Crackling static. Earned by defeating VACUUM-01.", Colors = { rgb(150, 150, 255) }, Style = "Sparkle", Source = "Boss" },
	{ Id = "CircuitAura", Name = "Circuit Aura", Category = "Aura", Rarity = "Epic", Description = "Earned by defeating GUARDIAN MK-IV.", Colors = { rgb(80, 160, 255), rgb(200, 255, 255) }, Style = "Sparkle", Source = "Boss" },
	{ Id = "ColossusAura", Name = "Colossus Aura", Category = "Aura", Rarity = "Legendary", Description = "Earned by defeating THE COLOSSUS.", Colors = { rgb(170, 120, 255), rgb(255, 255, 255) }, Style = "Halo", Source = "Boss" },
	{ Id = "AscendedAura", Name = "Ascended Aura", Category = "Aura", Rarity = "Legendary", Description = "From the Ascension tree.", Colors = { rgb(255, 255, 255), rgb(255, 240, 180) }, Style = "Halo", Source = "Ascension" },
	{ Id = "VIPAura", Name = "Royal Aura", Category = "Aura", Rarity = "Exclusive", Description = "VIP exclusive.", Colors = { rgb(255, 215, 0) }, Style = "Sparkle", Source = "Pass" },
	{ Id = "TitanAura", Name = "Titan Aura", Category = "Aura", Rarity = "Exclusive", Description = "Titan Cosmetic Pack exclusive.", Colors = { rgb(255, 170, 40), rgb(255, 255, 200) }, Style = "Flame", Source = "Pass" },
	{ Id = "SecretAura", Name = "Starlight Aura", Category = "Aura", Rarity = "Epic", Description = "Earned by finding 25 secrets.", Colors = { rgb(255, 255, 160) }, Style = "Sparkle", Source = "Achievement" },
	-- Footsteps ----------------------------------------------------------------
	{ Id = "SparkStep", Name = "Spark Steps", Category = "Footstep", Rarity = "Uncommon", Description = "Sparks where you step.", Colors = { rgb(255, 230, 120) }, Style = "Puff", Source = "Shop", Price = { Currency = "GrowthEnergy", Amount = 3000 } },
	{ Id = "FlowerStep", Name = "Blooming Steps", Category = "Footstep", Rarity = "Rare", Description = "Flowers bloom in your footprints.", Colors = { rgb(255, 150, 200), rgb(255, 255, 255) }, Style = "Bloom", Source = "Daily", Price = { Currency = "TitanShards", Amount = 60 } },
	{ Id = "VIPStep", Name = "Golden Footprints", Category = "Footstep", Rarity = "Exclusive", Description = "VIP exclusive.", Colors = { rgb(255, 215, 0) }, Style = "Puff", Source = "Pass" },
	{ Id = "TitanStep", Name = "Titan Footprints", Category = "Footstep", Rarity = "Exclusive", Description = "Titan Cosmetic Pack exclusive.", Colors = { rgb(255, 140, 40) }, Style = "Crack", Source = "Pass" },
	-- Landing ------------------------------------------------------------------
	{ Id = "DustLanding", Name = "Dust Burst", Category = "Landing", Rarity = "Common", Description = "A dusty ring on landing.", Colors = { rgb(220, 210, 190) }, Style = "Ring", Source = "Shop", Price = { Currency = "GrowthEnergy", Amount = 1200 } },
	{ Id = "NovaLanding", Name = "Nova Landing", Category = "Landing", Rarity = "Epic", Description = "A starburst every landing.", Colors = { rgb(200, 160, 255), rgb(255, 255, 255) }, Style = "Burst", Source = "Shop", Price = { Currency = "TitanShards", Amount = 110 } },
	{ Id = "TitanLanding", Name = "Titan Impact", Category = "Landing", Rarity = "Exclusive", Description = "Titan Cosmetic Pack exclusive.", Colors = { rgb(255, 160, 40) }, Style = "Burst", Source = "Pass" },
	-- Dash -----------------------------------------------------------------------
	{ Id = "WindDash", Name = "Wind Dash", Category = "Dash", Rarity = "Uncommon", Description = "Streaks of wind when dashing.", Colors = { rgb(220, 240, 255) }, Style = "Streak", Source = "Shop", Price = { Currency = "GrowthEnergy", Amount = 5000 } },
	{ Id = "BoltDash", Name = "Lightning Dash", Category = "Dash", Rarity = "Epic", Description = "Crackling lightning dash.", Colors = { rgb(120, 200, 255), rgb(255, 255, 255) }, Style = "Bolt", Source = "Daily", Price = { Currency = "TitanShards", Amount = 90 } },
	{ Id = "TitanStompFx", Name = "Titan Stomp Visual", Category = "Dash", Rarity = "Exclusive", Description = "Titan Cosmetic Pack: molten shockwaves for dashes and stomps.", Colors = { rgb(255, 120, 30), rgb(255, 220, 120) }, Style = "Bolt", Source = "Pass" },
	-- Growth ---------------------------------------------------------------------
	{ Id = "SpiralGrowth", Name = "Spiral Growth", Category = "Growth", Rarity = "Rare", Description = "Spiraling light when you grow.", Colors = { rgb(120, 255, 160), rgb(255, 255, 255) }, Style = "Spiral", Source = "Shop", Price = { Currency = "TitanShards", Amount = 75 } },
	{ Id = "SupernovaGrowth", Name = "Supernova", Category = "Growth", Rarity = "Legendary", Description = "Your growth spurts become supernovas.", Colors = { rgb(255, 240, 180), rgb(255, 120, 60) }, Style = "Burst", Source = "Daily", Price = { Currency = "TitanShards", Amount = 220 } },
	-- Name colors -----------------------------------------------------------------
	{ Id = "MintName", Name = "Mint", Category = "NameColor", Rarity = "Common", Description = "Mint green name.", Colors = { rgb(140, 255, 200) }, Style = "Solid", Source = "Shop", Price = { Currency = "GrowthEnergy", Amount = 800 } },
	{ Id = "SkyName", Name = "Sky", Category = "NameColor", Rarity = "Common", Description = "Sky blue name.", Colors = { rgb(120, 200, 255) }, Style = "Solid", Source = "Shop", Price = { Currency = "GrowthEnergy", Amount = 800 } },
	{ Id = "RoseName", Name = "Rose", Category = "NameColor", Rarity = "Uncommon", Description = "Rose pink name.", Colors = { rgb(255, 140, 180) }, Style = "Solid", Source = "Daily", Price = { Currency = "GrowthEnergy", Amount = 2500 } },
	{ Id = "VIPName", Name = "VIP Gold", Category = "NameColor", Rarity = "Exclusive", Description = "VIP exclusive.", Colors = { rgb(255, 215, 0) }, Style = "Solid", Source = "Pass" },
	{ Id = "AscendedName", Name = "Ascended White", Category = "NameColor", Rarity = "Legendary", Description = "Ascend once.", Colors = { rgb(255, 255, 255) }, Style = "Solid", Source = "Achievement" },
}

local byId: { [string]: Cosmetic } = {}
for _, c in List do
	assert(byId[c.Id] == nil, "duplicate cosmetic " .. c.Id)
	byId[c.Id] = c
end

local categoryById = {}
for _, c in Categories do
	categoryById[c.Id] = c
end

local CosmeticConfig = {
	Categories = Categories,
	List = List,
	RarityColors = {
		Common = rgb(200, 205, 215),
		Uncommon = rgb(110, 220, 120),
		Rare = rgb(80, 170, 255),
		Epic = rgb(190, 110, 255),
		Legendary = rgb(255, 190, 50),
		Limited = rgb(255, 100, 140),
		Exclusive = rgb(255, 215, 0),
	} :: { [string]: Color3 },
	-- Hard cap on simultaneously rendered effects from OTHER players, per client.
	MaxOtherPlayerEffects = 12,
}

function CosmeticConfig.get(id: string): Cosmetic?
	return byId[id]
end

function CosmeticConfig.getCategory(id: string)
	return categoryById[id]
end

function CosmeticConfig.isAvailable(c: Cosmetic, now: number): boolean
	if not c.Limited then
		return true
	end
	return now >= c.Limited.Start and now < c.Limited.End
end

return CosmeticConfig
