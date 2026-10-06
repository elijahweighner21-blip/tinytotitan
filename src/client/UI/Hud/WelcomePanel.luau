--!strict
--[[
	WelcomePanel
	Short "welcome back" card after loading: current size, what is waiting
	(unclaimed login reward, completed daily objectives, unspent skill
	points, active boosts) and one suggested next step. New players skip it
	— the tutorial hint takes over instead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SizeConfig = require(Shared.Config.SizeConfig)
local DailyConfig = require(Shared.Config.DailyConfig)
local QuestConfig = require(Shared.Config.QuestConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local Net = require(Client.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local Button = require(Client.UI.Components.Button)
local DataController = require(Client.Controllers.DataController)

local WelcomePanel = {}

type Line = { Text: string, Menu: string? }

local function collectLines(data: any): { Line }
	local lines: { Line } = {}
	if data.Daily.LoginClaimedDay ~= data.Daily.LoginDay then
		table.insert(lines, {
			Text = string.format(
				"🎁 Day %d login reward is ready",
				((math.max(1, data.Daily.Streak) - 1) % #DailyConfig.StreakRewards) + 1
			),
			Menu = "Daily",
		})
	end
	local ready = 0
	for _, list in { data.Daily.Objectives, data.Daily.Weekly } do
		for _, slot in list do
			local def = DailyConfig.findObjective(slot.Id)
			if def and not slot.Claimed and slot.Progress >= def.Target then
				ready += 1
			end
		end
	end
	if ready > 0 then
		table.insert(lines, {
			Text = string.format("✔ %d objective reward%s to claim", ready, if ready == 1 then "" else "s"),
			Menu = "Daily",
		})
	end
	if data.Currencies.SkillPoints > 0 then
		table.insert(lines, {
			Text = string.format(
				"✦ %d unspent Skill Point%s",
				data.Currencies.SkillPoints,
				if data.Currencies.SkillPoints == 1 then "" else "s"
			),
			Menu = "Skills",
		})
	end
	for id, seconds in data.Boosts do
		local def = MonetizationConfig.Boosts[id]
		if def and seconds > 0 then
			table.insert(lines, {
				Text = string.format("%s %s active — %s of play left", def.Icon, def.Name, Format.duration(seconds)),
			})
		end
	end
	local tracked = data.Quests.Tracked
	local quest = if tracked ~= "" then QuestConfig.get(tracked) else nil
	if quest then
		table.insert(lines, { Text = "! Continue: " .. quest.Name, Menu = "Quests" })
	end
	return lines
end

function WelcomePanel.show()
	local data = DataController:Get()
	if not data or not data.Tutorial.Done then
		return
	end
	local lines = collectLines(data)
	Net.action("Analytics", { Event = "WelcomeShown" })
	local frame = Create("Frame", {
		Name = "Welcome",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = UIManager.Overlay,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.stroke(Theme.Colors.Accent, 0.3, 2),
			Create.padding(18, 20),
			Create.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center),
		},
	})
	local tier = SizeConfig.getTier(DataController:GetTier())
	Create.label(
		"WELCOME BACK",
		Theme.TextSize.Small,
		Theme.Colors.Accent,
		Theme.Fonts.Title,
		{ TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = frame }
	)
	Create.label(
		tier.Name,
		Theme.TextSize.Title,
		tier.Color,
		Theme.Fonts.Display,
		{ Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = frame }
	)
	Create.label(
		string.format("Level %d  ·  %s Mass", data.Progress.Level, Format.abbreviate(data.Currencies.Mass)),
		Theme.TextSize.Body,
		Theme.Colors.TextDim,
		Theme.Fonts.Body,
		{
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 3,
			Parent = frame,
		}
	)
	local function close()
		if frame.Parent then
			frame:Destroy()
		end
	end
	for i, line in lines do
		if line.Menu then
			local menu = line.Menu
			Button.new({
				Text = line.Text,
				Style = "Secondary",
				Size = UDim2.new(1, 0, 0, 34),
				TextSize = Theme.TextSize.Small,
				LayoutOrder = 10 + i,
				Parent = frame,
				OnClick = function()
					close()
					UIManager:Open(menu)
				end,
			})
		else
			Create.label(
				line.Text,
				Theme.TextSize.Small,
				Theme.Colors.Text,
				Theme.Fonts.Title,
				{ TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 10 + i, Parent = frame }
			)
		end
	end
	Button.new({
		Text = "Let's grow!",
		Style = "Primary",
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 100,
		Parent = frame,
		OnClick = close,
	})
	task.delay(20, function()
		if frame.Parent then
			close()
		end
	end)
end

return WelcomePanel
