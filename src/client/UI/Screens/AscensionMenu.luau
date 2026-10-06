--!strict
--[[
	AscensionMenu
	  Ascend   what you would earn now, the exact Resets / Keeps lists (the
	           same data the server uses) and a two-step confirmation; the
	           request itself must carry Confirm = "ASCEND"
	  Tree     permanent upgrades bought with Ascension Points
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AscensionConfig = require(Shared.Config.AscensionConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local Card = require(UI.Components.Card)
local Scroll = require(UI.Components.Scroll)
local Dialog = require(UI.Components.Dialog)
local UIManager = require(UI.UIManager)
local DataController = require(Client.Controllers.DataController)
local Common = require(script.Parent.Common)

local AscensionMenu = {}

local list: ScrollingFrame
local grid: ScrollingFrame

local function bulletList(parent: Instance, title: string, items: { string }, color: Color3, order: number)
	local frame = Create("Frame", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		Size = UDim2.new(0.5, -6, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.padding(12),
			Create.list(Enum.FillDirection.Vertical, 4),
			Create.stroke(color, 0.5),
		},
	})
	Create.label(title, Theme.TextSize.Heading, color, Theme.Fonts.Title, { LayoutOrder = 0, Parent = frame })
	for i, text in items do
		Create.label("•  " .. text, Theme.TextSize.Small, Theme.Colors.Text, Theme.Fonts.Body, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = frame,
		})
	end
end

local function confirmAscend(points: number)
	local lines = {}
	for _, text in AscensionConfig.Resets do
		table.insert(lines, { Text = "✖ " .. text, Color = Theme.Colors.Danger })
	end
	Dialog.confirm({
		Title = "Ascend?",
		Body = string.format(
			"You will gain %d Ascension Points and start again from Microscopic with permanent bonuses. This resets:",
			points
		),
		Lines = lines,
		Confirm = "ASCEND",
		Danger = true,
		Parent = UIManager.Menus,
	}, function(first)
		if not first then
			return
		end
		-- Second, deliberate confirmation so it can't happen by accident.
		Dialog.confirm({
			Title = "Are you absolutely sure?",
			Body = "This cannot be undone. Everything in the Keeps list stays with you.",
			Confirm = "Yes, Ascend",
			Danger = true,
			Parent = UIManager.Menus,
		}, function(second)
			if second then
				local result = Common.request("Ascend", { Confirm = "ASCEND" })
				if result.ok then
					UIManager:Close("Ascension")
				end
			end
		end)
	end)
end

local function renderAscend(data: any)
	grid.Visible = false
	list.Visible = true
	Scroll.clear(list)
	local tier = data.Progress.Tier
	local points = AscensionConfig.pointsFor(tier, data.Progress.RunMass)
	local ready = tier >= AscensionConfig.RequiredTier
	local hero = Create("Frame", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = list,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.padding(14),
			Create.list(Enum.FillDirection.Vertical, 6),
			Create.stroke(Theme.Colors.Gold, 0.4, 2),
		},
	})
	Create.label(
		string.format(
			"Ascensions: %d   ·   Ascension Points: %d",
			data.Ascension.Count,
			data.Currencies.AscensionPoints
		),
		Theme.TextSize.Heading,
		Theme.Colors.Gold,
		Theme.Fonts.Title,
		{ LayoutOrder = 1, Parent = hero }
	)
	if ready then
		Create.label(
			string.format(
				"Ascend now for +%d Ascension Points  (current size: %s, run Mass: %s). Growing bigger and earning more Mass this run increases the reward.",
				points,
				SizeConfig.getTier(tier).Name,
				Format.abbreviate(data.Progress.RunMass)
			),
			Theme.TextSize.Body,
			Theme.Colors.Text,
			Theme.Fonts.Body,
			{
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Parent = hero,
			}
		)
	else
		Create.label(
			"Reach "
				.. SizeConfig.getTier(AscensionConfig.RequiredTier).Name
				.. " to Ascend. Ascending resets your size for permanent bonuses that make every new run faster.",
			Theme.TextSize.Body,
			Theme.Colors.TextDim,
			Theme.Fonts.Body,
			{
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Parent = hero,
			}
		)
	end
	local button = Button.new({
		Text = if ready
			then "Ascend  (+" .. points .. " ∞)"
			else "🔒 Requires " .. SizeConfig.getTier(AscensionConfig.RequiredTier).Name,
		Style = if ready then "Gold" else "Ghost",
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 3,
		Parent = hero,
		OnClick = function()
			confirmAscend(points)
		end,
	})
	button:SetEnabled(ready)
	local columns = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = list,
		[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 12) },
	})
	bulletList(columns, "Resets", AscensionConfig.Resets, Theme.Colors.Danger, 1)
	bulletList(columns, "You keep", AscensionConfig.Keeps, Theme.Colors.Success, 2)
end

local function renderTree(menu: MenuBase.Menu, data: any)
	list.Visible = false
	grid.Visible = true
	Scroll.clear(grid)
	menu.Window:SetSubtitle(string.format("∞ %d Ascension Points", data.Currencies.AscensionPoints))
	local tree = data.Ascension.Tree
	for i, node in AscensionConfig.Tree do
		local rank = tree[node.Id] or 0
		local maxed = rank >= node.MaxRank
		local missing: string? = nil
		for _, req in node.Requires do
			if (tree[req] or 0) <= 0 then
				local r = AscensionConfig.getNode(req)
				missing = "Requires " .. (if r then r.Name else req)
				break
			end
		end
		local card = Card.new({
			Icon = node.Icon,
			Title = node.Name,
			Description = node.Description,
			Accent = Theme.Colors.Gold,
			LayoutOrder = i,
			Parent = grid,
		})
		card:SetTag(
			string.format("%d/%d", rank, node.MaxRank),
			if maxed then Theme.Colors.Gold else Theme.Colors.PanelLighter
		)
		if maxed then
			Button.new({ Text = "Maxed", Style = "Ghost", Size = UDim2.fromOffset(120, 32), Parent = card.Footer })
				:SetEnabled(false)
		elseif missing then
			card:SetDim(true)
			Create.label("🔒 " .. missing, Theme.TextSize.Small, Theme.Colors.Danger, Theme.Fonts.Body, {
				Size = UDim2.fromOffset(220, 32),
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = card.Footer,
			})
		else
			local cost = AscensionConfig.nodeCost(node, rank)
			local b = Button.new({
				Text = "∞ " .. cost,
				Style = "Gold",
				Size = UDim2.fromOffset(120, 32),
				TextSize = Theme.TextSize.Small,
				Parent = card.Footer,
				OnClick = function()
					Common.request("BuyAscensionNode", { Id = node.Id })
				end,
			})
			b:SetEnabled(data.Currencies.AscensionPoints >= cost)
		end
	end
end

local function render(menu: MenuBase.Menu, tab: string)
	local data = DataController:Get()
	if not data then
		return
	end
	if tab == "Ascend" then
		menu.Window:SetSubtitle("Prestige: trade your size for permanent power")
		renderAscend(data)
	else
		renderTree(menu, data)
	end
end

function AscensionMenu.mount()
	local menu = MenuBase.new({
		Name = "Ascension",
		Title = "Ascension",
		Icon = "∞",
		Accent = Theme.Colors.Gold,
		Tabs = {
			{ Id = "Ascend", Text = "Ascend" },
			{ Id = "Tree", Text = "Ascension Tree" },
		},
		Watch = { "Ascension", "Currencies", "Progress" },
		Render = render,
	})
	list = Scroll.list(menu.Content, { Gap = 12, Name = "Ascend" })
	grid = Scroll.grid(menu.Content, UDim2.new(0.5, -8, 0, 140), { Name = "Tree" })
end

return AscensionMenu
