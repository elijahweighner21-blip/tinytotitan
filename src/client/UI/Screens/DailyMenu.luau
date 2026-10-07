--!strict
--[[
	DailyMenu
	Login streak (7-day cycle, forgiving: one missed day keeps the streak),
	three daily and three weekly objectives with progress and Claim buttons,
	and countdowns to the next reset. Objectives are chosen by the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyConfig = require(Shared.Config.DailyConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local ProgressBar = require(UI.Components.ProgressBar)
local Scroll = require(UI.Components.Scroll)
local DataController = require(Client.Controllers.DataController)
local Common = require(script.Parent.Common)

local DailyMenu = {}

local list: ScrollingFrame

local function secondsUntilDailyReset(): number
	local now = workspace:GetServerTimeNow()
	local offset = GameConfig.DailyResetHourUtc * 3600
	return 86400 - ((now - offset) % 86400)
end

local function secondsUntilWeeklyReset(): number
	local now = workspace:GetServerTimeNow()
	local day = DailyConfig.dayNumber(now, GameConfig.DailyResetHourUtc)
	local daysIntoWeek = (day + 3) % 7
	return (6 - daysIntoWeek) * 86400 + secondsUntilDailyReset()
end

local function header(text: string, sub: string, order: number)
	local frame = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 30),
		LayoutOrder = order,
		Parent = list,
	})
	Create.label(
		text,
		Theme.TextSize.Heading,
		Theme.Colors.Text,
		Theme.Fonts.Display,
		{ Size = UDim2.new(0.6, 0, 1, 0), Parent = frame }
	)
	Create.label(sub, Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	})
end

local function objectiveRow(
	slot: { Id: string, Progress: number, Claimed: boolean },
	kind: string,
	index: number,
	order: number
)
	local def = DailyConfig.findObjective(slot.Id)
	if not def then
		return
	end
	local frame = Create("Frame", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 64),
		LayoutOrder = order,
		Parent = list,
		[Create.Children] = { Create.corner(Theme.Radius), Create.padding(10, 12) },
	})
	local progress = math.min(slot.Progress, def.Target)
	local bar = ProgressBar.new({
		Parent = frame,
		Size = UDim2.new(1, -150, 0, 22),
		Color = if progress >= def.Target then Theme.Colors.Success else Theme.Colors.Accent,
		TextSize = Theme.TextSize.Tiny,
	})
	bar:Set(progress / def.Target, true)
	bar:SetText(
		string.format(def.Text, def.Target)
			.. string.format("   %s/%s", Format.abbreviate(progress), Format.abbreviate(def.Target))
	)
	Create.label(
		Common.rewardText(def.Reward :: any) .. (if def.ZoneScaled then "  (scales with your zone)" else ""),
		Theme.TextSize.Tiny,
		Theme.Colors.TextDim,
		Theme.Fonts.Body,
		{
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, -150, 0, 18),
			Parent = frame,
		}
	)
	local ready = progress >= def.Target and not slot.Claimed
	local button = Button.new({
		Text = if slot.Claimed then "Claimed ✔" elseif ready then "Claim" else "In progress",
		Style = if slot.Claimed then "Ghost" elseif ready then "Gold" else "Secondary",
		Size = UDim2.fromOffset(130, 36),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		TextSize = Theme.TextSize.Small,
		Parent = frame,
		OnClick = function()
			Common.request("ClaimDaily", { Kind = kind, Index = index }, "Reward claimed!")
		end,
	})
	button:SetEnabled(ready)
end

local function render(menu: MenuBase.Menu, _tab: string)
	local data = DataController:Get()
	if not data then
		return
	end
	local daily = data.Daily
	menu.Window:SetSubtitle(
		string.format("Login streak: %d day%s", daily.Streak, if daily.Streak == 1 then "" else "s")
	)
	Scroll.clear(list)
	-- Streak row.
	header("Login Streak", "Resets in " .. Format.duration(secondsUntilDailyReset()), 1)
	local streakRow = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 96),
		LayoutOrder = 2,
		Parent = list,
		[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) },
	})
	local cycle = #DailyConfig.StreakRewards
	local position = ((math.max(1, daily.Streak) - 1) % cycle) + 1
	local claimedToday = daily.LoginClaimedDay == daily.LoginDay
	for day = 1, cycle do
		local reward = DailyConfig.StreakRewards[day]
		local isToday = day == position
		local done = day < position or (isToday and claimedToday)
		Create("Frame", {
			BackgroundColor3 = if isToday
				then Theme.Colors.Gold:Lerp(Theme.Colors.PanelLight, 0.6)
				else Theme.Colors.PanelLight,
			BackgroundTransparency = if done and not isToday then 0.4 else 0,
			Size = UDim2.fromOffset(100, 96),
			LayoutOrder = day,
			Parent = streakRow,
			[Create.Children] = {
				Create.corner(Theme.Radius),
				Create.stroke(
					if isToday then Theme.Colors.Gold else Color3.new(1, 1, 1),
					if isToday then 0 else 0.85,
					2
				),
				Create.padding(6),
				Create.label(
					"Day " .. day .. (if done then " ✔" else ""),
					Theme.TextSize.Small,
					Theme.Colors.Text,
					Theme.Fonts.Title,
					{ TextXAlignment = Enum.TextXAlignment.Center }
				),
				Create.label(Common.rewardText(reward), Theme.TextSize.Tiny, Theme.Colors.TextDim, Theme.Fonts.Body, {
					Position = UDim2.fromOffset(0, 24),
					Size = UDim2.new(1, 0, 1, -24),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
			},
		})
	end
	local claim = Button.new({
		Text = if claimedToday then "Come back tomorrow!" else "Claim Day " .. position .. " Reward",
		Style = if claimedToday then "Ghost" else "Gold",
		Size = UDim2.new(1, -8, 0, 40),
		LayoutOrder = 3,
		Parent = list,
		OnClick = function()
			Common.request("ClaimDaily", { Kind = "Login" }, "Streak reward claimed!")
		end,
	})
	claim:SetEnabled(not claimedToday)
	header("Daily Objectives", "New in " .. Format.duration(secondsUntilDailyReset()), 10)
	for i, slot in daily.Objectives do
		objectiveRow(slot, "Daily", i, 10 + i)
	end
	header("Weekly Objectives", "New in " .. Format.duration(secondsUntilWeeklyReset()), 20)
	for i, slot in daily.Weekly do
		objectiveRow(slot, "Weekly", i, 20 + i)
	end
end

function DailyMenu.mount()
	local menu = MenuBase.new({
		Name = "Daily",
		Title = "Daily Rewards",
		Icon = Theme.Icons.Daily,
		Accent = Theme.Colors.Gold,
		Watch = { "Daily" },
		Render = render,
	})
	list = Scroll.list(menu.Content, { Gap = 8 })
end

return DailyMenu
