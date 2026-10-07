--!strict
--[[
	MapMenu
	World overview and fast travel. The world spans wildly different scales
	(a carpet next to a mountain range), so instead of one unreadable
	top-down map each region gets a card in progression order:

	  * "You are here", recommended sizes and the zone's description
	  * discoveries found / total and collection progress
	  * Fast Travel button (station must have been visited; server enforces
	    size, cooldown and combat/challenge blockers)
	  * locked regions show the size they require
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local DiscoveryConfig = require(Shared.Config.DiscoveryConfig)
local CurrencyConfig = require(Shared.Config.CurrencyConfig)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local Scroll = require(UI.Components.Scroll)
local UIManager = require(UI.UIManager)
local DataController = require(Client.Controllers.DataController)
local ZoneController = require(Client.Controllers.ZoneController)
local Common = require(script.Parent.Common)

local MapMenu = {}

local grid: ScrollingFrame

local discoveryTotals: { [string]: number } = {}
for _, d in DiscoveryConfig.List do
	if not d.Hidden then
		discoveryTotals[d.Zone] = (discoveryTotals[d.Zone] or 0) + 1
	end
end

local function render(menu: MenuBase.Menu, _tab: string)
	local data = DataController:Get()
	if not data then
		return
	end
	local here = ZoneController:GetZone()
	local tier = DataController:GetTier()
	local found: { [string]: number } = {}
	for id in data.Discoveries do
		local d = DiscoveryConfig.get(id)
		if d and not d.Hidden then
			found[d.Zone] = (found[d.Zone] or 0) + 1
		end
	end
	local unlockedStations = 0
	for _ in data.FastTravel do
		unlockedStations += 1
	end
	menu.Window:SetSubtitle(string.format("%d / %d travel stations visited", unlockedStations, #ZoneConfig.Zones))
	Scroll.clear(grid)
	for i, zone in ZoneConfig.Zones do
		local locked = tier < zone.RequiredTier
		local isHere = zone.Id == here
		local card = Create("Frame", {
			Name = zone.Id,
			BackgroundColor3 = if locked then Theme.Colors.Panel else zone.MapColor:Lerp(Theme.Colors.PanelLight, 0.78),
			LayoutOrder = i,
			Parent = grid,
			[Create.Children] = {
				Create.corner(Theme.Radius),
				Create.stroke(
					if isHere then Theme.Colors.Accent else zone.MapColor,
					if isHere then 0 else 0.6,
					if isHere then 3 else 1.5
				),
				Create.padding(12),
				Create.list(Enum.FillDirection.Vertical, 4),
			},
		})
		local title = (if locked then "🔒 " else "") .. zone.Name .. (if isHere then "   📍 YOU ARE HERE" else "")
		Create.label(
			title,
			Theme.TextSize.Heading,
			if locked then Theme.Colors.TextFaint else Theme.Colors.Text,
			Theme.Fonts.Title,
			{ LayoutOrder = 1, Parent = card }
		)
		local recommended = zone.RecommendedTiers
		Create.label(
			string.format(
				"Best at: %s – %s",
				SizeConfig.getTier(recommended[1]).Name,
				SizeConfig.getTier(recommended[#recommended]).Name
			),
			Theme.TextSize.Small,
			Theme.Colors.TextDim,
			Theme.Fonts.Body,
			{ LayoutOrder = 2, Parent = card }
		)
		Create.label(zone.Description, Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Light, {
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 3,
			Parent = card,
		})
		local resource = zone.Resource and CurrencyConfig.Resources[zone.Resource]
		Create.label(
			string.format(
				"📍 %d/%d discovered%s",
				found[zone.Id] or 0,
				discoveryTotals[zone.Id] or 0,
				if resource then "    " .. resource.Icon .. " " .. resource.Name else ""
			),
			Theme.TextSize.Small,
			Theme.Colors.Accent,
			Theme.Fonts.Title,
			{ LayoutOrder = 4, Parent = card }
		)
		local row = Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 5,
			Parent = card,
			[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right) },
		})
		if locked then
			Create.label(
				"Requires " .. SizeConfig.getTier(zone.RequiredTier).Name,
				Theme.TextSize.Small,
				Theme.Colors.Danger,
				Theme.Fonts.Title,
				{
					Size = UDim2.fromOffset(240, 34),
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = row,
				}
			)
		elseif data.FastTravel[zone.Id] then
			Button.new({
				Text = if isHere then "Return to Station" else "Fast Travel",
				Style = "Primary",
				Size = UDim2.fromOffset(150, 34),
				TextSize = Theme.TextSize.Small,
				Parent = row,
				OnClick = function()
					local result = Common.request("FastTravel", { Station = zone.Id })
					if result.ok then
						UIManager:Close("Map")
					end
				end,
			})
		else
			Create.label(
				"Find this region's travel station to unlock",
				Theme.TextSize.Small,
				Theme.Colors.TextFaint,
				Theme.Fonts.Body,
				{
					Size = UDim2.fromOffset(300, 34),
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = row,
				}
			)
		end
	end
end

function MapMenu.mount()
	local menu = MenuBase.new({
		Name = "Map",
		Title = "World Map",
		Icon = Theme.Icons.Map,
		Accent = Theme.Colors.Accent,
		Watch = { "FastTravel", "Discoveries", "Progress" },
		Render = render,
	})
	grid = Scroll.grid(menu.Content, UDim2.new(0.5, -8, 0, 176), { Name = "Zones" })
	ZoneController.ZoneChanged:Connect(function()
		menu:Refresh()
	end)
end

return MapMenu
