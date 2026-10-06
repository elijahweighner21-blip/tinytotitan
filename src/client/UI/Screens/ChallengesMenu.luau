--!strict
--[[
	ChallengesMenu
	Every challenge grouped by region: best score, medal earned, the medal
	targets, and whether your current size can still earn medals on it
	(courses are built for a size range; bigger players run them as
	practice). "Show Pad" drops a waypoint on the start pad; "Leaderboard"
	opens the challenge's global board.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChallengeConfig = require(Shared.Config.ChallengeConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local Scroll = require(UI.Components.Scroll)
local UIManager = require(UI.UIManager)
local Bus = require(UI.Bus)
local WorldIndex = require(Client.WorldIndex)
local DataController = require(Client.Controllers.DataController)
local WorldMarkerController = require(Client.Controllers.WorldMarkerController)

local ChallengesMenu = {}

local list: ScrollingFrame
local MEDAL_ICONS = { "🥉", "🥈", "🥇", "💠" }

local function scoreText(kind: string, value: number): string
	if kind == "Time" then
		return Format.raceTime(value)
	elseif kind == "Distance" then
		return string.format("%.2f bodies", value)
	end
	return tostring(math.floor(value))
end

local function render(menu: MenuBase.Menu, tab: string)
	local data = DataController:Get()
	if not data then
		return
	end
	local tier = DataController:GetTier()
	local medals, titan = 0, 0
	for _, record in data.Challenges do
		if record.Medal > 0 then
			medals += 1
		end
		if record.Medal >= 4 then
			titan += 1
		end
	end
	menu.Window:SetSubtitle(string.format("%d / %d medalled · %d Titan medals", medals, #ChallengeConfig.List, titan))
	Scroll.clear(list)
	local order = 0
	for _, def in ChallengeConfig.List do
		if def.Zone == tab then
			order += 1
			local record = data.Challenges[def.Id]
			local tooSmall = tier < def.RequiredTier
			local practice = def.MaxTier ~= nil and tier > def.MaxTier
			local frame = Create("Frame", {
				Name = def.Id,
				BackgroundColor3 = Theme.Colors.PanelLight,
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = order,
				Parent = list,
				[Create.Children] = { Create.corner(Theme.Radius), Create.padding(12), Create.list(Enum.FillDirection.Vertical, 4) },
			})
			local medal = if record then record.Medal else 0
			Create.label((if medal > 0 then MEDAL_ICONS[medal] .. "  " else "") .. def.Name .. "   ·   " .. def.Type, Theme.TextSize.Heading, Theme.Colors.Text, Theme.Fonts.Title, { LayoutOrder = 1, Parent = frame })
			Create.label(def.Description, Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Parent = frame,
			})
			local targets = {}
			for i, name in ChallengeConfig.Medals do
				local v = (def.Thresholds :: any)[name]
				if v then
					table.insert(targets, MEDAL_ICONS[i] .. " " .. scoreText(def.Score, v))
				end
			end
			Create.label(table.concat(targets, "    "), Theme.TextSize.Small, Theme.Colors.Gold, Theme.Fonts.Title, { LayoutOrder = 3, Parent = frame })
			local status = if record and record.Completions > 0
				then string.format("Best: %s   ·   Runs: %d", scoreText(def.Score, record.Best), record.Completions)
				else "Not attempted yet"
			if tooSmall then
				status = "🔒 Requires " .. SizeConfig.getTier(def.RequiredTier).Name
			elseif practice then
				status ..= "   ·   Practice only at your size"
			end
			Create.label(status, Theme.TextSize.Small, if tooSmall then Theme.Colors.Danger else Theme.Colors.Accent, Theme.Fonts.Title, { LayoutOrder = 4, Parent = frame })
			local row = Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 32),
				LayoutOrder = 5,
				Parent = frame,
				[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) },
			})
			Button.new({
				Text = "Show Pad",
				Style = "Secondary",
				Size = UDim2.fromOffset(120, 32),
				TextSize = Theme.TextSize.Small,
				Parent = row,
				OnClick = function()
					local position = WorldIndex.get("Challenge", def.Id)
					if position then
						WorldMarkerController:SetWaypoint(position, def.Name)
						Bus.toast("Waypoint set: " .. def.Name, "Info")
						UIManager:Close("Challenges")
					end
				end,
			})
			if def.Leaderboard then
				Button.new({
					Text = "Leaderboard",
					Style = "Ghost",
					Size = UDim2.fromOffset(130, 32),
					TextSize = Theme.TextSize.Small,
					Parent = row,
					OnClick = function()
						Bus.OpenMenu:Fire("Leaderboards", { Board = "Challenge_" .. def.Id })
						UIManager:Open("Leaderboards")
					end,
				})
			end
		end
	end
	if order == 0 then
		Create.label("No challenges in this region.", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, { Size = UDim2.new(1, 0, 0, 40), Parent = list })
	end
end

function ChallengesMenu.mount()
	local tabs = {}
	local seen: { [string]: boolean } = {}
	for _, zone in ZoneConfig.Zones do
		for _, def in ChallengeConfig.List do
			if def.Zone == zone.Id and not seen[zone.Id] then
				seen[zone.Id] = true
				table.insert(tabs, { Id = zone.Id, Text = zone.Name })
			end
		end
	end
	local menu = MenuBase.new({
		Name = "Challenges",
		Title = "Challenges",
		Icon = "⏱",
		Accent = Theme.Colors.Accent,
		Tabs = tabs,
		Watch = { "Challenges", "Progress" },
		Render = render,
	})
	list = Scroll.list(menu.Content, { Gap = 10 })
end

return ChallengesMenu
