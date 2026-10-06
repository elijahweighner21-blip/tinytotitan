--!strict
--[[
	CurrencyConfig
	Display metadata (name, icon, color) for every currency and zone
	resource, so menus never hard-code labels. Gameplay rules live elsewhere.
]]

export type Display = { Id: string, Name: string, Icon: string, Color: Color3, Description: string }

local Currencies: { [string]: Display } = {
	Mass = {
		Id = "Mass",
		Name = "Mass",
		Icon = "◉",
		Color = Color3.fromRGB(120, 255, 150),
		Description = "Makes you grow. Never spent.",
	},
	GrowthEnergy = {
		Id = "GrowthEnergy",
		Name = "Growth Energy",
		Icon = "⚡",
		Color = Color3.fromRGB(255, 214, 80),
		Description = "Spent on upgrades and cosmetics.",
	},
	TitanShards = {
		Id = "TitanShards",
		Name = "Titan Shards",
		Icon = "🔷",
		Color = Color3.fromRGB(110, 190, 255),
		Description = "Rare currency for special items.",
	},
	AscensionPoints = {
		Id = "AscensionPoints",
		Name = "Ascension Points",
		Icon = "∞",
		Color = Color3.fromRGB(255, 205, 60),
		Description = "Earned by Ascending; spent on the Ascension tree.",
	},
	SkillPoints = {
		Id = "SkillPoints",
		Name = "Skill Points",
		Icon = "✦",
		Color = Color3.fromRGB(190, 150, 255),
		Description = "Earned by levelling up; unlock skills.",
	},
	ExplorationTokens = {
		Id = "ExplorationTokens",
		Name = "Exploration Tokens",
		Icon = "🧭",
		Color = Color3.fromRGB(200, 170, 255),
		Description = "Found by exploring; used for fast travel extras.",
	},
}

local Resources: { [string]: Display } = {
	DustCores = {
		Id = "DustCores",
		Name = "Dust Cores",
		Icon = "🟤",
		Color = Color3.fromRGB(196, 160, 120),
		Description = "Gathered in the Bedroom.",
	},
	SugarCrystals = {
		Id = "SugarCrystals",
		Name = "Sugar Crystals",
		Icon = "🧊",
		Color = Color3.fromRGB(230, 240, 255),
		Description = "Gathered in the Kitchen.",
	},
	NatureEssence = {
		Id = "NatureEssence",
		Name = "Nature Essence",
		Icon = "🌿",
		Color = Color3.fromRGB(110, 210, 110),
		Description = "Gathered in the Backyard.",
	},
	Scrap = {
		Id = "Scrap",
		Name = "Scrap",
		Icon = "⚙",
		Color = Color3.fromRGB(170, 175, 190),
		Description = "Gathered in the Neighborhood and Downtown.",
	},
	TitanCells = {
		Id = "TitanCells",
		Name = "Titan Cells",
		Icon = "🧬",
		Color = Color3.fromRGB(190, 120, 255),
		Description = "Gathered in Titan City and the Wilderness.",
	},
}

local CurrencyConfig = {
	Currencies = Currencies,
	Resources = Resources,
}

local FALLBACK: Display = { Id = "?", Name = "?", Icon = "•", Color = Color3.new(1, 1, 1), Description = "" }

function CurrencyConfig.display(id: string): Display
	return Currencies[id] or Resources[id] or FALLBACK
end

return CurrencyConfig
