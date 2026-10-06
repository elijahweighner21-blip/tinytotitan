--!strict
--[[
	UpgradesMenu
	Stat upgrades by category. Each card shows level, current → next effect,
	price (Growth Energy plus any zone resource) and why it is locked.
	Categories with nothing unlocked yet are still listed, greyed, so
	players can see what is coming.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Types = require(Shared.Types)
local SizeConfig = require(Shared.Config.SizeConfig)
local Pricing = require(Shared.Formulas.Pricing)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Card = require(UI.Components.Card)
local Button = require(UI.Components.Button)
local Scroll = require(UI.Components.Scroll)
local DataController = require(Client.Controllers.DataController)
local Common = require(script.Parent.Common)

local UpgradesMenu = {}

local grid: ScrollingFrame
local busy = false

local function effectText(effect: Types.UpgradeEffect, level: number): string
	local total = Pricing.effectAt(effect.PerLevel, level)
	if effect.Mode == "Mult" then
		return "+" .. Format.percent(total, 0)
	end
	return "+" .. Format.abbreviate(total, 2)
end

local function render(menu: MenuBase.Menu, tab: string)
	local data = DataController:Get()
	if not data then
		return
	end
	local stats = DataController:GetStats() :: any
	local discount = stats.UpgradeDiscount or 0
	local tier = DataController:GetTier()
	menu.Window:SetSubtitle(string.format("%s Growth Energy available", Common.costText("GrowthEnergy", data.Currencies.GrowthEnergy)))
	Scroll.clear(grid)
	local list = {}
	for _, def in UpgradeConfig.List do
		if def.Category == tab then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	for i, def in list do
		local level = data.Upgrades[def.Id] or 0
		local maxed = level >= def.MaxLevel
		local locked = def.RequiredTier ~= nil and tier < def.RequiredTier
		local card = Card.new({
			Icon = def.Icon,
			Title = def.Name,
			Description = def.Description,
			LayoutOrder = i,
			Parent = grid,
			Size = UDim2.fromOffset(0, 0),
		})
		Create.label(
			string.format("Lv %d/%d   %s%s", level, def.MaxLevel, effectText(def.Effect, level), if maxed then "" else "  →  " .. effectText(def.Effect, level + 1)),
			Theme.TextSize.Small,
			Theme.Colors.Accent,
			Theme.Fonts.Title,
			{ Position = UDim2.new(0, 0, 1, -38), Size = UDim2.new(1, -130, 0, 34), TextYAlignment = Enum.TextYAlignment.Center, Parent = card.Instance }
		)
		if maxed then
			card:SetTag("MAX", Theme.Colors.Gold)
			Button.new({ Text = "Maxed", Style = "Ghost", Size = UDim2.fromOffset(120, 34), Parent = card.Footer }):SetEnabled(false)
		elseif locked then
			card:SetDim(true)
			card:SetTag("🔒 " .. SizeConfig.getTier(def.RequiredTier :: number).Name, Theme.Colors.Locked)
			Button.new({ Text = "Locked", Style = "Ghost", Size = UDim2.fromOffset(120, 34), Parent = card.Footer }):SetEnabled(false)
		else
			local cost = Pricing.upgradeCost(def, level, discount)
			local resource, amount = Pricing.resourceCost(def, level)
			local costs: { [string]: number } = { [def.Currency] = cost }
			if resource and amount > 0 then
				costs[resource] = amount
			end
			local affordable = Common.canAfford(costs)
			local button = Button.new({
				Text = Common.costsText(costs),
				Style = if affordable then "Primary" else "Secondary",
				Size = UDim2.fromOffset(120, 34),
				TextSize = Theme.TextSize.Small,
				Parent = card.Footer,
				OnClick = function()
					if busy then
						return
					end
					busy = true
					local result = Common.request("BuyUpgrade", { Id = def.Id })
					busy = false
					if result.ok then
						card.Instance.BackgroundColor3 = Theme.Colors.Success
						task.delay(0.15, function()
							card.Instance.BackgroundColor3 = Theme.Colors.PanelLight
						end)
					end
				end,
			})
			if not affordable then
				button.Label.TextColor3 = Theme.Colors.Danger
			end
		end
	end
end

function UpgradesMenu.mount()
	local tabs = {}
	for _, category in UpgradeConfig.Categories do
		table.insert(tabs, { Id = category.Id, Text = category.Name, Icon = category.Icon })
	end
	local menu = MenuBase.new({
		Name = "Upgrades",
		Title = "Upgrades",
		Icon = "⬆",
		Accent = Theme.Colors.Energy,
		Tabs = tabs,
		Watch = { "Upgrades", "Currencies", "Resources", "Progress" },
		Render = render,
	})
	grid = Scroll.grid(menu.Content, UDim2.new(0.5, -8, 0, 150), { Name = "Upgrades" })
end

return UpgradesMenu
