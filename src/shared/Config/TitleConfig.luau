--!strict
--[[
	TitleConfig
	Cosmetic titles shown above the player's name. Titles never affect gameplay.
	Source documents how the title is obtained (achievement, boss, pass...).
]]

export type Title = { Id: string, Text: string, Color: Color3, Rarity: string, Source: string }

local List: { Title } = {
	{ Id = "TinyExplorer", Text = "Tiny Explorer", Color = Color3.fromRGB(180, 220, 255), Rarity = "Common", Source = "Reach Dust-Sized" },
	{ Id = "CrumbHunter", Text = "Crumb Hunter", Color = Color3.fromRGB(230, 190, 120), Rarity = "Common", Source = "Collect 100 Growth Orbs" },
	{ Id = "AntSized", Text = "Ant-Sized", Color = Color3.fromRGB(205, 120, 90), Rarity = "Common", Source = "Reach Ant-Sized" },
	{ Id = "RoomConqueror", Text = "Room Conqueror", Color = Color3.fromRGB(120, 140, 220), Rarity = "Uncommon", Source = "Discover every Bedroom location" },
	{ Id = "KitchenConqueror", Text = "Kitchen Conqueror", Color = Color3.fromRGB(240, 240, 220), Rarity = "Uncommon", Source = "Discover every Kitchen location" },
	{ Id = "RoofRunner", Text = "Roof Runner", Color = Color3.fromRGB(140, 200, 255), Rarity = "Rare", Source = "Gold medal in Rooftop Rush" },
	{ Id = "NeighborhoodGiant", Text = "Neighborhood Giant", Color = Color3.fromRGB(255, 220, 180), Rarity = "Rare", Source = "Reach Human-Sized" },
	{ Id = "CityCrusher", Text = "City Crusher", Color = Color3.fromRGB(255, 120, 100), Rarity = "Epic", Source = "Reach Giant" },
	{ Id = "Titan", Text = "Titan", Color = Color3.fromRGB(255, 200, 60), Rarity = "Epic", Source = "Reach Titan" },
	{ Id = "Colossus", Text = "Colossus", Color = Color3.fromRGB(190, 140, 255), Rarity = "Legendary", Source = "Defeat THE COLOSSUS" },
	{ Id = "Ascended", Text = "Ascended", Color = Color3.fromRGB(255, 255, 255), Rarity = "Legendary", Source = "Ascend once" },
	{ Id = "Queenslayer", Text = "Queenslayer", Color = Color3.fromRGB(200, 70, 60), Rarity = "Rare", Source = "Defeat THE QUEEN" },
	{ Id = "DustBuster", Text = "Dust Buster", Color = Color3.fromRGB(150, 150, 170), Rarity = "Rare", Source = "Defeat VACUUM-01" },
	{ Id = "GrassSurvivor", Text = "Grass Survivor", Color = Color3.fromRGB(110, 200, 90), Rarity = "Rare", Source = "Defeat THE LAWNMOWER" },
	{ Id = "MachineBreaker", Text = "Machine Breaker", Color = Color3.fromRGB(80, 160, 255), Rarity = "Epic", Source = "Defeat GUARDIAN MK-IV" },
	{ Id = "Worldbreaker", Text = "Worldbreaker", Color = Color3.fromRGB(255, 80, 200), Rarity = "Legendary", Source = "Complete the main story" },
	{ Id = "NeverForgot", Text = "Never Forgot", Color = Color3.fromRGB(255, 230, 200), Rarity = "Epic", Source = "Return home as a Titan" },
	{ Id = "SecretKeeper", Text = "Secret Keeper", Color = Color3.fromRGB(255, 255, 160), Rarity = "Epic", Source = "Find 25 secrets" },
	{ Id = "Speedrunner", Text = "Speedrunner", Color = Color3.fromRGB(120, 220, 255), Rarity = "Epic", Source = "Earn 10 Titan medals" },
	{ Id = "Millionaire", Text = "Mass Millionaire", Color = Color3.fromRGB(120, 255, 140), Rarity = "Rare", Source = "Earn 1,000,000 total Mass" },
	{ Id = "VIP", Text = "VIP", Color = Color3.fromRGB(255, 215, 0), Rarity = "Exclusive", Source = "VIP Game Pass" },
	{ Id = "PrimeTitan", Text = "PRIME TITAN", Color = Color3.fromRGB(255, 170, 40), Rarity = "Exclusive", Source = "Titan Cosmetic Pack" },
	{ Id = "FoundingGrower", Text = "Founding Grower", Color = Color3.fromRGB(140, 255, 200), Rarity = "Exclusive", Source = "Starter Pack" },
	{ Id = "Pathfinder", Text = "Pathfinder", Color = Color3.fromRGB(200, 160, 255), Rarity = "Rare", Source = "Explorer Bundle" },
}

local byId: { [string]: Title } = {}
for _, t in List do
	byId[t.Id] = t
end
-- Achievement/boss rewards refer to titles by display text in some places;
-- accept either form.
local byText: { [string]: Title } = {}
for _, t in List do
	byText[t.Text] = t
end

local TitleConfig = { List = List }

function TitleConfig.get(idOrText: string): Title?
	return byId[idOrText] or byText[idOrText]
end

return TitleConfig
