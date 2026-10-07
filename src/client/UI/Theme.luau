--!strict
--[[
	Theme
	Design tokens shared by every UI element so menus look like one game:
	dark translucent "glass" panels, rounded corners, one accent per system,
	consistent spacing, type scale and motion timings.
]]

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(14, 17, 28),
	Panel = Color3.fromRGB(22, 27, 42),
	PanelLight = Color3.fromRGB(32, 39, 60),
	PanelLighter = Color3.fromRGB(44, 53, 80),
	Stroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(240, 244, 255),
	TextDim = Color3.fromRGB(160, 170, 195),
	TextFaint = Color3.fromRGB(110, 120, 145),
	Accent = Color3.fromRGB(80, 220, 255),
	Mass = Color3.fromRGB(120, 255, 150),
	Energy = Color3.fromRGB(255, 214, 80),
	Shards = Color3.fromRGB(110, 190, 255),
	XP = Color3.fromRGB(190, 150, 255),
	Danger = Color3.fromRGB(255, 90, 100),
	Success = Color3.fromRGB(110, 230, 140),
	Warning = Color3.fromRGB(255, 180, 70),
	Gold = Color3.fromRGB(255, 205, 60),
	Robux = Color3.fromRGB(80, 210, 120),
	Locked = Color3.fromRGB(90, 96, 115),
}

Theme.Fonts = {
	Display = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
	Title = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
	Light = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
	Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium),
}

Theme.TextSize = {
	Hero = 44,
	Title = 26,
	Heading = 20,
	Body = 16,
	Small = 13,
	Tiny = 11,
}

Theme.Radius = UDim.new(0, 12)
Theme.RadiusSmall = UDim.new(0, 8)
Theme.RadiusPill = UDim.new(1, 0)
Theme.Padding = 12
Theme.Gap = 8

Theme.PanelTransparency = 0.08
Theme.StrokeTransparency = 0.86

Theme.Tween = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Bounce = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

-- One icon and one colour per system, shared by the dock, menu titles and
-- notifications so every screen speaks the same visual language.
Theme.Icons = {
	Upgrades = "🧪",
	Skills = "🌟",
	Quests = "📜",
	Map = "🗺️",
	Challenges = "⏱️",
	Collections = "💎",
	Inventory = "🎒",
	Daily = "📅",
	Achievements = "🏆",
	Ascension = "🌀",
	Leaderboards = "📊",
	Party = "👥",
	Shop = "🛒",
	Settings = "⚙️",
	Admin = "🛠️",
}

Theme.SystemColors = {
	Upgrades = Color3.fromRGB(120, 255, 150),
	Skills = Color3.fromRGB(190, 150, 255),
	Quests = Color3.fromRGB(255, 205, 60),
	Map = Color3.fromRGB(80, 220, 255),
	Challenges = Color3.fromRGB(255, 160, 70),
	Collections = Color3.fromRGB(110, 190, 255),
	Inventory = Color3.fromRGB(220, 170, 120),
	Daily = Color3.fromRGB(255, 214, 80),
	Achievements = Color3.fromRGB(255, 205, 60),
	Ascension = Color3.fromRGB(200, 120, 255),
	Leaderboards = Color3.fromRGB(80, 220, 255),
	Party = Color3.fromRGB(110, 230, 140),
	Shop = Color3.fromRGB(255, 205, 60),
	Settings = Color3.fromRGB(170, 180, 205),
	Admin = Color3.fromRGB(255, 90, 100),
}

-- Reference resolution the layouts are designed against; UIManager scales.
Theme.ReferenceSize = Vector2.new(1280, 720)

function Theme.rarityColor(rarity: string): Color3
	local map = {
		Common = Color3.fromRGB(200, 205, 215),
		Uncommon = Color3.fromRGB(110, 220, 120),
		Rare = Color3.fromRGB(80, 170, 255),
		Epic = Color3.fromRGB(190, 110, 255),
		Legendary = Color3.fromRGB(255, 190, 50),
		Limited = Color3.fromRGB(255, 100, 140),
		Exclusive = Color3.fromRGB(255, 215, 0),
	}
	return map[rarity] or Theme.Colors.TextDim
end

return Theme
