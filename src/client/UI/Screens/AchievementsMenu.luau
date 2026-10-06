--!strict
--[[
	AchievementsMenu
	All achievements by category with unlock dates and rewards. Hidden
	achievements stay "???" until earned.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AchievementConfig = require(Shared.Config.AchievementConfig)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Card = require(UI.Components.Card)
local Scroll = require(UI.Components.Scroll)
local DataController = require(Client.Controllers.DataController)
local Common = require(script.Parent.Common)

local AchievementsMenu = {}

local grid: ScrollingFrame

local CATEGORY_ICONS: { [string]: string } = {
	Growth = "🌱",
	Exploration = "🧭",
	Combat = "⚔",
	Movement = "🏃",
	Challenges = "⏱",
	Quests = "!",
}

local function render(menu: MenuBase.Menu, tab: string)
	local data = DataController:Get()
	if not data then
		return
	end
	local unlocked = 0
	for _ in data.Achievements do
		unlocked += 1
	end
	menu.Window:SetSubtitle(string.format("%d / %d unlocked", unlocked, #AchievementConfig.List))
	Scroll.clear(grid)
	local items = {}
	for _, def in AchievementConfig.List do
		if def.Category == tab then
			table.insert(items, def)
		end
	end
	table.sort(items, function(a, b)
		local ua, ub = data.Achievements[a.Id] ~= nil, data.Achievements[b.Id] ~= nil
		if ua ~= ub then
			return ua
		end
		return a.Name < b.Name
	end)
	for i, def in items do
		local at = data.Achievements[def.Id]
		local secret = def.Hidden and not at
		local card = Card.new({
			Icon = if at then "🏆" elseif secret then "❔" else (CATEGORY_ICONS[def.Category] or "•"),
			Title = if secret then "???" else def.Name,
			Description = if secret then "A secret achievement. Keep exploring!" else def.Description,
			Accent = if at then Theme.Colors.Gold else Theme.Colors.Locked,
			LayoutOrder = i,
			Parent = grid,
		})
		if at then
			card:SetTag(os.date("!%b %d, %Y", at) :: string, Theme.Colors.Gold)
		else
			card:SetDim(true)
		end
		if not secret then
			local rewards = Common.rewardText(def.Rewards :: any)
			if rewards ~= "" then
				Create.label(rewards, Theme.TextSize.Small, Theme.Colors.Accent, Theme.Fonts.Title, {
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = card.Footer,
				})
			end
		end
	end
end

function AchievementsMenu.mount()
	local tabs = {}
	local seen: { [string]: boolean } = {}
	for _, def in AchievementConfig.List do
		if not seen[def.Category] then
			seen[def.Category] = true
			table.insert(tabs, { Id = def.Category, Text = def.Category, Icon = CATEGORY_ICONS[def.Category] })
		end
	end
	local menu = MenuBase.new({
		Name = "Achievements",
		Title = "Achievements",
		Icon = "🏆",
		Accent = Theme.Colors.Gold,
		Tabs = tabs,
		Watch = { "Achievements" },
		Render = render,
	})
	grid = Scroll.grid(menu.Content, UDim2.new(0.5, -8, 0, 130), { Name = "Achievements" })
end

return AchievementsMenu
