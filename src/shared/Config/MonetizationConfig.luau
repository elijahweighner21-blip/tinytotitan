--!strict
--[[
	MonetizationConfig
	THE ONLY PLACE ROBLOX PRODUCT IDS LIVE. Replace the 0s with the IDs from
	the Creator Dashboard (Monetization -> Passes / Developer Products). An id of
	0 means "not configured": the shop shows the item as unavailable in live
	servers and only Studio test purchases can exercise it.

	Design rules enforced by MonetizationService / RewardService:
	  * Robux buys convenience, cosmetics, boosts and customisation — never
	    zones, bosses, or skipping the early game.
	  * Titan Shards are also earnable everywhere in gameplay.
	  * Purchased rewards bypass all multipliers (no stacking surprises).
	  * Prices here are DISPLAY fallbacks only; real prices come from
	    MarketplaceService:GetProductInfo and are never used in game logic.
]]

local Types = require(script.Parent.Parent.Types)

type Reward = Types.Reward

export type GamePass = {
	Key: string,
	PassId: number,
	Name: string,
	Description: string,
	Perks: { string },
	FallbackPrice: number,
	Icon: string,
	Color: Color3,
	-- Items granted (once) while the pass is owned. Re-checked every join.
	Grants: { Titles: { string }?, Cosmetics: { string }? },
}

export type DevProduct = {
	Key: string,
	ProductId: number,
	Name: string,
	Description: string,
	Category: string, -- "TitanShards" | "Boosts" | "Bundles"
	FallbackPrice: number,
	Icon: string,
	Color: Color3,
	Contents: Reward,
	OneTime: boolean?, -- e.g. Starter Pack: server refuses to prompt twice
	-- Value shown on bundle cards ("Worth 1,450 Shards").
	ValueText: string?,
	-- Only shown while condition holds (evaluated server-side).
	Visibility: { MaxLevel: number?, MaxPlaytimeHours: number?, Start: number?, End: number? }?,
	-- If a OneTime product is somehow bought twice, grant this instead.
	DuplicateCompensation: Reward?,
}

export type Boost = {
	Id: string,
	Name: string,
	Icon: string,
	Color: Color3,
	Kind: "Currency" | "Stat",
	Target: string, -- currency for Kind=Currency, stat for Kind=Stat
	Multiplier: number,
	MaxStackSeconds: number,
}

local MonetizationConfig = {}

MonetizationConfig.GamePasses = {
	VIP = {
		Key = "VIP",
		PassId = 0,
		Name = "VIP",
		Description = "Stand out and get a few nice perks — without skipping any of the game.",
		Perks = {
			"Exclusive VIP title, gold name color and royal aura",
			"Golden Ribbon trail and Golden Footprints",
			"+10% Growth Energy and +5% XP",
			"+25% Growth Energy on daily streak rewards",
			"Access to the VIP Lounge (cosmetics & social hangout)",
		},
		FallbackPrice = 299,
		Icon = "👑",
		Color = Color3.fromRGB(255, 205, 50),
		Grants = { Titles = { "VIP" }, Cosmetics = { "VIPAura", "VIPTrail", "VIPStep", "VIPName" } },
	},
	DoubleGrowthEnergy = {
		Key = "DoubleGrowthEnergy",
		PassId = 0,
		Name = "2× Growth Energy",
		Description = "Permanently doubles Growth Energy from gameplay. Does not affect Mass, Titan Shards or purchases.",
		Perks = {
			"×2 Growth Energy from all gameplay sources",
			"Stacks additively with VIP, multiplicatively with boosts (capped)",
		},
		FallbackPrice = 399,
		Icon = "🔋",
		Color = Color3.fromRGB(255, 220, 80),
		Grants = {},
	},
	ExtraCosmeticSlots = {
		Key = "ExtraCosmeticSlots",
		PassId = 0,
		Name = "Extra Cosmetic Slots",
		Description = "Equip up to 3 trails and 2 auras at once.",
		Perks = { "3 trail slots (instead of 1)", "2 aura slots (instead of 1)" },
		FallbackPrice = 149,
		Icon = "🎒",
		Color = Color3.fromRGB(150, 200, 255),
		Grants = {},
	},
	TitanCosmeticPack = {
		Key = "TitanCosmeticPack",
		PassId = 0,
		Name = "Titan Cosmetic Pack",
		Description = "Molten Titan visuals. Purely cosmetic.",
		Perks = {
			"Titan Aura, Titan Trail",
			"Titan Footprints and Titan Impact landing",
			"Titan Stomp visual",
			"Exclusive title: PRIME TITAN",
		},
		FallbackPrice = 249,
		Icon = "🔥",
		Color = Color3.fromRGB(255, 140, 40),
		Grants = {
			Titles = { "PrimeTitan" },
			Cosmetics = { "TitanAura", "TitanTrail", "TitanStep", "TitanLanding", "TitanStompFx" },
		},
	},
} :: { [string]: GamePass }

MonetizationConfig.Boosts = {
	Mass2x = {
		Id = "Mass2x",
		Name = "2× Mass",
		Icon = "🟢",
		Color = Color3.fromRGB(120, 255, 140),
		Kind = "Currency",
		Target = "Mass",
		Multiplier = 2,
		MaxStackSeconds = 6 * 3600,
	},
	Energy2x = {
		Id = "Energy2x",
		Name = "2× Growth Energy",
		Icon = "🔋",
		Color = Color3.fromRGB(255, 220, 80),
		Kind = "Currency",
		Target = "GrowthEnergy",
		Multiplier = 2,
		MaxStackSeconds = 6 * 3600,
	},
	XP2x = {
		Id = "XP2x",
		Name = "2× XP",
		Icon = "🎓",
		Color = Color3.fromRGB(150, 200, 255),
		Kind = "Currency",
		Target = "XP",
		Multiplier = 2,
		MaxStackSeconds = 6 * 3600,
	},
	Luck2x = {
		Id = "Luck2x",
		Name = "2× Luck",
		Icon = "🍀",
		Color = Color3.fromRGB(150, 255, 170),
		Kind = "Stat",
		Target = "Luck",
		Multiplier = 2,
		MaxStackSeconds = 6 * 3600,
	},
} :: { [string]: Boost }

-- Boost durations count down only while the player is IN GAME (active play
-- time), so a purchased hour is always a full hour of play. This is
-- persisted as remaining seconds and is immune to server hops/crashes.
MonetizationConfig.BoostClock = "ActivePlaytime"

MonetizationConfig.DeveloperProducts = {
	-- Titan Shards -------------------------------------------------------------
	Shards100 = {
		Key = "Shards100",
		ProductId = 0,
		Name = "100 Titan Shards",
		Description = "A small pouch of shards.",
		Category = "TitanShards",
		FallbackPrice = 49,
		Icon = "🔷",
		Color = Color3.fromRGB(90, 200, 255),
		Contents = { TitanShards = 100 },
	},
	Shards500 = {
		Key = "Shards500",
		ProductId = 0,
		Name = "500 Titan Shards",
		Description = "+10% bonus value.",
		Category = "TitanShards",
		FallbackPrice = 199,
		Icon = "💠",
		Color = Color3.fromRGB(90, 200, 255),
		Contents = { TitanShards = 500 },
		ValueText = "Best for most players",
	},
	Shards1200 = {
		Key = "Shards1200",
		ProductId = 0,
		Name = "1,200 Titan Shards",
		Description = "+20% bonus value.",
		Category = "TitanShards",
		FallbackPrice = 449,
		Icon = "💎",
		Color = Color3.fromRGB(110, 170, 255),
		Contents = { TitanShards = 1200 },
		ValueText = "Popular",
	},
	Shards3000 = {
		Key = "Shards3000",
		ProductId = 0,
		Name = "3,000 Titan Shards",
		Description = "+35% bonus value.",
		Category = "TitanShards",
		FallbackPrice = 999,
		Icon = "👑",
		Color = Color3.fromRGB(150, 140, 255),
		Contents = { TitanShards = 3000 },
		ValueText = "Best value",
	},
	-- Boosts ---------------------------------------------------------------------
	MassBoost15 = {
		Key = "MassBoost15",
		ProductId = 0,
		Name = "2× Mass (15 min)",
		Description = "Double Mass for 15 minutes of play.",
		Category = "Boosts",
		FallbackPrice = 29,
		Icon = "🟢",
		Color = Color3.fromRGB(120, 255, 140),
		Contents = { Boosts = { Mass2x = 900 } },
	},
	MassBoost30 = {
		Key = "MassBoost30",
		ProductId = 0,
		Name = "2× Mass (30 min)",
		Description = "Double Mass for 30 minutes of play.",
		Category = "Boosts",
		FallbackPrice = 49,
		Icon = "🟢",
		Color = Color3.fromRGB(120, 255, 140),
		Contents = { Boosts = { Mass2x = 1800 } },
	},
	MassBoost60 = {
		Key = "MassBoost60",
		ProductId = 0,
		Name = "2× Mass (60 min)",
		Description = "Double Mass for 60 minutes of play.",
		Category = "Boosts",
		FallbackPrice = 89,
		Icon = "🟢",
		Color = Color3.fromRGB(120, 255, 140),
		Contents = { Boosts = { Mass2x = 3600 } },
		ValueText = "Best value",
	},
	EnergyBoost30 = {
		Key = "EnergyBoost30",
		ProductId = 0,
		Name = "2× Growth Energy (30 min)",
		Description = "Double Growth Energy for 30 minutes of play.",
		Category = "Boosts",
		FallbackPrice = 49,
		Icon = "🔋",
		Color = Color3.fromRGB(255, 220, 80),
		Contents = { Boosts = { Energy2x = 1800 } },
	},
	LuckBoost30 = {
		Key = "LuckBoost30",
		ProductId = 0,
		Name = "2× Luck (30 min)",
		Description = "Better rare drop and golden orb chances for 30 minutes.",
		Category = "Boosts",
		FallbackPrice = 49,
		Icon = "🍀",
		Color = Color3.fromRGB(150, 255, 170),
		Contents = { Boosts = { Luck2x = 1800 } },
	},
	XPBoost30 = {
		Key = "XPBoost30",
		ProductId = 0,
		Name = "2× XP (30 min)",
		Description = "Double XP for 30 minutes of play.",
		Category = "Boosts",
		FallbackPrice = 39,
		Icon = "🎓",
		Color = Color3.fromRGB(150, 200, 255),
		Contents = { Boosts = { XP2x = 1800 } },
	},
	-- Bundles ----------------------------------------------------------------------
	StarterPack = {
		Key = "StarterPack",
		ProductId = 0,
		Name = "Starter Pack",
		Category = "Bundles",
		FallbackPrice = 99,
		Icon = "🎁",
		Color = Color3.fromRGB(140, 255, 160),
		Description = "A friendly head start that doesn't skip the adventure. One per player.",
		Contents = {
			GrowthEnergy = 1500,
			TitanShards = 150,
			Boosts = { Mass2x = 1800 },
			Cosmetics = { "StarterTrail" },
			Titles = { "FoundingGrower" },
		},
		OneTime = true,
		ValueText = "One-time offer",
		Visibility = { MaxLevel = 25, MaxPlaytimeHours = 6 },
		DuplicateCompensation = { TitanShards = 200 },
	},
	ExplorerBundle = {
		Key = "ExplorerBundle",
		ProductId = 0,
		Name = "Explorer Bundle",
		Category = "Bundles",
		FallbackPrice = 249,
		Icon = "🧭",
		Color = Color3.fromRGB(200, 160, 255),
		Description = "For players who love finding everything.",
		Contents = {
			TitanShards = 400,
			ExplorationTokens = 5,
			Boosts = { Luck2x = 3600 },
			Cosmetics = { "ExplorerTrail" },
			Titles = { "Pathfinder" },
		},
		OneTime = true,
		ValueText = "Worth 600+ Shards",
		DuplicateCompensation = { TitanShards = 450 },
	},
	TitanBundle = {
		Key = "TitanBundle",
		ProductId = 0,
		Name = "Titan Bundle",
		Category = "Bundles",
		FallbackPrice = 499,
		Icon = "🗿",
		Color = Color3.fromRGB(255, 200, 60),
		Description = "Boosts and shards for the long climb.",
		Contents = { TitanShards = 900, Boosts = { Mass2x = 3600, Energy2x = 3600 } },
		ValueText = "Worth 1,100+ Shards",
	},
	AscensionBundle = {
		Key = "AscensionBundle",
		ProductId = 0,
		Name = "Ascension Bundle",
		Category = "Bundles",
		FallbackPrice = 399,
		Icon = "🌟",
		Color = Color3.fromRGB(255, 255, 220),
		Description = "Boosts that make a fresh run fly by.",
		Contents = { TitanShards = 500, Boosts = { Mass2x = 7200, XP2x = 3600 } },
		ValueText = "2 hours of 2× Mass",
	},
	HalloweenBundle = {
		Key = "HalloweenBundle",
		ProductId = 0,
		Name = "Spooky Bundle",
		Category = "Bundles",
		FallbackPrice = 199,
		Icon = "🎃",
		Color = Color3.fromRGB(255, 120, 0),
		Description = "Limited-time Halloween cosmetics plus shards.",
		Contents = { TitanShards = 250, Cosmetics = { "PumpkinTrail", "SpookAura" } },
		OneTime = true,
		ValueText = "Limited time",
		Visibility = { Start = 1790812800, End = 1794009600 },
		DuplicateCompensation = { TitanShards = 300 },
	},
} :: { [string]: DevProduct }

MonetizationConfig.ShopCategories = {
	{ Id = "Featured", Name = "FEATURED", Icon = "⭐" },
	{ Id = "GamePasses", Name = "GAME PASSES", Icon = "🎫" },
	{ Id = "Boosts", Name = "BOOSTS", Icon = "⚡" },
	{ Id = "TitanShards", Name = "TITAN SHARDS", Icon = "🔷" },
	{ Id = "Bundles", Name = "BUNDLES", Icon = "🎁" },
	{ Id = "Cosmetics", Name = "COSMETICS", Icon = "✨" },
}

MonetizationConfig.Featured = { "StarterPack", "VIP", "MassBoost30", "Shards1200", "TitanCosmeticPack" }

-- VIP perks consumed by RewardService / DailyService.
MonetizationConfig.VIPPerks = {
	GrowthEnergyBonus = 0.10,
	XPBonus = 0.05,
	DailyBonus = 0.25,
}

-- Prompt throttling: the server refuses to re-prompt the same product within
-- this many seconds (prevents prompt spam and accidental double buys).
MonetizationConfig.PromptCooldown = 3

function MonetizationConfig.getPass(key: string): GamePass?
	return MonetizationConfig.GamePasses[key]
end

function MonetizationConfig.getProduct(key: string): DevProduct?
	return MonetizationConfig.DeveloperProducts[key]
end

function MonetizationConfig.productByRobloxId(productId: number): DevProduct?
	if productId == 0 then
		return nil
	end
	for _, p in MonetizationConfig.DeveloperProducts do
		if p.ProductId == productId then
			return p
		end
	end
	return nil
end

function MonetizationConfig.passByRobloxId(passId: number): GamePass?
	if passId == 0 then
		return nil
	end
	for _, p in MonetizationConfig.GamePasses do
		if p.PassId == passId then
			return p
		end
	end
	return nil
end

return MonetizationConfig
