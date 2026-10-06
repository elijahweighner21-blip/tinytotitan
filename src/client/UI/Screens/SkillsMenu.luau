--!strict
--[[
	SkillsMenu
	The skill tree, one branch per tab. Nodes sit on the grid from
	SkillConfig (lane × depth) with lines to their prerequisites. Selecting a
	node shows its details, cost and every unmet requirement on the right.

	  bright + filled   unlocked
	  outlined          available now
	  grey              locked (requirements listed)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillConfig = require(Shared.Config.SkillConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local AchievementConfig = require(Shared.Config.AchievementConfig)
local BossConfig = require(Shared.Config.BossConfig)
local Types = require(Shared.Types)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local Dialog = require(UI.Components.Dialog)
local UIManager = require(UI.UIManager)
local DataController = require(Client.Controllers.DataController)
local Common = require(script.Parent.Common)

local SkillsMenu = {}

local canvas: Frame
local detail: Frame
local selected: string? = nil
local menuRef: MenuBase.Menu

local NODE = 64
local LANE_W = 150
local ROW_H = 92

local function unmet(def: Types.Skill, data: any): { string }
	local out = {}
	local r = def.Requirements
	if r.Tier and DataController:GetTier() < r.Tier then
		table.insert(out, "Reach " .. SizeConfig.getTier(r.Tier).Name)
	end
	if r.Level and data.Progress.Level < r.Level then
		table.insert(out, "Reach level " .. r.Level)
	end
	if r.Achievement and not data.Achievements[r.Achievement] then
		local a = AchievementConfig.get(r.Achievement)
		table.insert(out, "Achievement: " .. (if a then a.Name else r.Achievement))
	end
	if r.Boss and not (data.Bosses[r.Boss] and data.Bosses[r.Boss].Kills > 0) then
		local b = BossConfig.get(r.Boss)
		table.insert(out, "Defeat " .. (if b then b.Name else r.Boss))
	end
	for _, pre in def.Prerequisites do
		if not data.Skills[pre] then
			local p = SkillConfig.get(pre)
			table.insert(out, "Unlock " .. (if p then p.Name else pre))
		end
	end
	return out
end

local function costTable(def: Types.Skill): { [string]: number }
	local costs: { [string]: number } = {}
	if def.Cost.SkillPoints then
		costs.SkillPoints = def.Cost.SkillPoints
	end
	if def.Cost.TitanShards then
		costs.TitanShards = def.Cost.TitanShards
	end
	if def.Cost.Resources then
		for id, n in def.Cost.Resources do
			costs[id] = n
		end
	end
	return costs
end

local function nodePosition(p: Vector2): UDim2
	return UDim2.new(0.5, (p.X - 1) * LANE_W, 0, 40 + p.Y * ROW_H)
end

local function renderDetail(data: any)
	for _, child in detail:GetChildren() do
		if
			not child:IsA("UIListLayout")
			and not child:IsA("UIPadding")
			and not child:IsA("UICorner")
			and not child:IsA("UIStroke")
		then
			child:Destroy()
		end
	end
	local def = selected and SkillConfig.get(selected)
	if not def then
		Create.label(
			"Select a skill to see its details.",
			Theme.TextSize.Body,
			Theme.Colors.TextDim,
			Theme.Fonts.Body,
			{ Size = UDim2.new(1, 0, 0, 40), Parent = detail }
		)
		return
	end
	Create.label(
		def.Icon .. "  " .. def.Name,
		Theme.TextSize.Heading,
		Theme.Colors.Text,
		Theme.Fonts.Title,
		{ LayoutOrder = 1, Parent = detail }
	)
	Create.label(def.Description, Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = detail,
	})
	local owned = data.Skills[def.Id] ~= nil
	local costs = costTable(def)
	Create.label(
		"Cost: " .. Common.costsText(costs),
		Theme.TextSize.Small,
		Theme.Colors.Gold,
		Theme.Fonts.Title,
		{ LayoutOrder = 3, Parent = detail }
	)
	local missing = unmet(def, data)
	for i, text in missing do
		Create.label(
			"🔒 " .. text,
			Theme.TextSize.Small,
			Theme.Colors.Danger,
			Theme.Fonts.Body,
			{ LayoutOrder = 3 + i, Parent = detail }
		)
	end
	local button = Button.new({
		Text = if owned then "Unlocked ✔" else "Unlock",
		Style = if owned then "Success" else "Primary",
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 20,
		Parent = detail,
		OnClick = function()
			Common.request("UnlockSkill", { Id = def.Id }, def.Name .. " unlocked!")
		end,
	})
	button:SetEnabled(not owned and #missing == 0 and Common.canAfford(costs))
end

local function render(menu: MenuBase.Menu, tab: string)
	local data = DataController:Get()
	if not data then
		return
	end
	menu.Window:SetSubtitle(string.format("✦ %d Skill Points", data.Currencies.SkillPoints))
	for _, child in canvas:GetChildren() do
		child:Destroy()
	end
	local branch = SkillConfig.Branches[1]
	for _, b in SkillConfig.Branches do
		if b.Id == tab then
			branch = b
		end
	end
	local nodes: { Types.Skill } = {}
	for _, def in SkillConfig.List do
		if def.Branch == tab then
			table.insert(nodes, def)
		end
	end
	-- Links first so nodes draw on top.
	for _, def in nodes do
		for _, pre in def.Prerequisites do
			local p = SkillConfig.get(pre)
			if p and p.Branch == tab then
				local a = Vector2.new((p.Position.X - 1) * LANE_W, 40 + p.Position.Y * ROW_H + NODE / 2)
				local b = Vector2.new((def.Position.X - 1) * LANE_W, 40 + def.Position.Y * ROW_H + NODE / 2)
				local mid = (a + b) / 2
				local length = (b - a).Magnitude
				Create("Frame", {
					BackgroundColor3 = if data.Skills[def.Id] then branch.Color else Theme.Colors.Locked,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, mid.X, 0, mid.Y),
					Size = UDim2.fromOffset(length, 4),
					Rotation = math.deg(math.atan2(b.Y - a.Y, b.X - a.X)),
					Parent = canvas,
				})
			end
		end
	end
	for _, def in nodes do
		local owned = data.Skills[def.Id] ~= nil
		local available = not owned and #unmet(def, data) == 0
		local color = if owned then branch.Color elseif available then Theme.Colors.PanelLighter else Theme.Colors.Panel
		local node = Create("TextButton", {
			Name = def.Id,
			Text = def.Icon,
			TextSize = 28,
			FontFace = Theme.Fonts.Display,
			TextColor3 = if owned or available then Theme.Colors.Text else Theme.Colors.TextFaint,
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = nodePosition(def.Position),
			Size = UDim2.fromOffset(NODE, NODE),
			Parent = canvas,
			[Create.Children] = {
				Create.corner(Theme.RadiusPill),
				Create.stroke(
					if available then branch.Color else Color3.new(1, 1, 1),
					if available or selected == def.Id then 0 else 0.8,
					if selected == def.Id then 3 else 2
				),
				Create.label(def.Name, Theme.TextSize.Tiny, Theme.Colors.TextDim, Theme.Fonts.Title, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 1, 2),
					Size = UDim2.fromOffset(130, 14),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextWrapped = false,
				}),
			},
		}) :: TextButton
		node.Activated:Connect(function()
			selected = def.Id
			menuRef:Refresh()
		end)
	end
	renderDetail(data)
end

function SkillsMenu.mount()
	local tabs = {}
	for _, b in SkillConfig.Branches do
		table.insert(tabs, { Id = b.Id, Text = b.Name, Icon = b.Icon })
	end
	menuRef = MenuBase.new({
		Name = "Skills",
		Title = "Skill Tree",
		Icon = "✦",
		Accent = Theme.Colors.XP,
		Tabs = tabs,
		Watch = { "Skills", "Currencies", "Progress", "Resources", "Achievements", "Bosses" },
		Render = render,
	})
	local content = menuRef.Content
	canvas = Create("Frame", {
		Name = "Tree",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.62, 0, 1, -50),
		ClipsDescendants = true,
		Parent = content,
	})
	detail = Create("Frame", {
		Name = "Detail",
		BackgroundColor3 = Theme.Colors.PanelLight,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.36, 0, 1, -50),
		Parent = content,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.padding(14),
			Create.list(Enum.FillDirection.Vertical, 8),
		},
	})
	Button.new({
		Text = "Reset Skills (" .. SkillConfig.RespecCost .. " 🔷)",
		Style = "Ghost",
		Size = UDim2.fromOffset(220, 36),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		TextSize = Theme.TextSize.Small,
		Parent = content,
		OnClick = function()
			Dialog.confirm({
				Title = "Reset all skills?",
				Body = string.format(
					"All Skill Points are refunded. Costs %d Titan Shards; shards and resources spent on skills are not refunded.",
					SkillConfig.RespecCost
				),
				Confirm = "Reset",
				Danger = true,
				Parent = UIManager.Menus,
			}, function(confirmed)
				if confirmed then
					Common.request("RespecSkills", nil, "Skills reset — points refunded")
				end
			end)
		end,
	})
end

return SkillsMenu
