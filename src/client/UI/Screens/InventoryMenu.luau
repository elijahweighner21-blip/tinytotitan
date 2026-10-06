--!strict
--[[
	InventoryMenu
	  Cosmetics  owned cosmetics by category with slot counts; tap to
	             equip/unequip (equipping into a full category replaces the
	             oldest). Unowned items show where they come from.
	  Titles     owned titles; one can be shown above your name
	  Items      key items and relics
	Cosmetics are purely visual — nothing here changes stats.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local TitleConfig = require(Shared.Config.TitleConfig)

local UI = script.Parent.Parent
local Client = UI.Parent
local Theme = require(UI.Theme)
local Create = require(UI.Create)
local MenuBase = require(UI.MenuBase)
local Button = require(UI.Components.Button)
local Card = require(UI.Components.Card)
local Scroll = require(UI.Components.Scroll)
local UIManager = require(UI.UIManager)
local DataController = require(Client.Controllers.DataController)
local Common = require(script.Parent.Common)

local InventoryMenu = {}

local player = Players.LocalPlayer
local grid: ScrollingFrame
local categoryBar: Frame
local category = "Trail"
local menuRef: MenuBase.Menu

local ITEM_NAMES: { [string]: { Name: string, Icon: string, Description: string } } = {
	ShedKey = {
		Name = "Fern's Shed Key",
		Icon = "🗝",
		Description = "Opens the locked cabinet in the backyard shed.",
	},
}

local SOURCE_TEXT: { [string]: string } = {
	Shop = "Buy in the Shop",
	Daily = "Appears in the Daily Shop",
	Boss = "Defeat a boss",
	Pass = "Game Pass reward",
	Bundle = "Bundle exclusive",
	Event = "Limited event",
	Achievement = "Achievement reward",
	Ascension = "Ascension reward",
}

local function slots(cat: any): number
	return if player:GetAttribute("Pass_ExtraCosmeticSlots") then cat.PassSlots else cat.BaseSlots
end

local function renderCategoryBar(data: any)
	for _, child in categoryBar:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for i, cat in CosmeticConfig.Categories do
		local equipped = data.Cosmetics.Equipped[cat.Id] or {}
		local selected = cat.Id == category
		local button = Create("TextButton", {
			Text = string.format("%s %s %d/%d", cat.Icon, cat.Name, #equipped, slots(cat)),
			TextSize = Theme.TextSize.Small,
			FontFace = Theme.Fonts.Title,
			TextColor3 = if selected then Color3.fromRGB(10, 20, 30) else Theme.Colors.TextDim,
			BackgroundColor3 = if selected then Theme.Colors.Accent else Theme.Colors.PanelLight,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			LayoutOrder = i,
			Parent = categoryBar,
			[Create.Children] = { Create.corner(Theme.RadiusPill), Create.padding(2, 10) },
		}) :: TextButton
		button.Activated:Connect(function()
			category = cat.Id
			menuRef:Refresh()
		end)
	end
end

local function renderCosmetics(data: any)
	categoryBar.Visible = true
	grid.Position = UDim2.fromOffset(0, 40)
	grid.Size = UDim2.new(1, 0, 1, -40)
	renderCategoryBar(data)
	local equipped: { string } = data.Cosmetics.Equipped[category] or {}
	local items = {}
	for _, def in CosmeticConfig.List do
		if def.Category == category then
			table.insert(items, def)
		end
	end
	table.sort(items, function(a, b)
		local oa, ob = data.Cosmetics.Owned[a.Id] == true, data.Cosmetics.Owned[b.Id] == true
		if oa ~= ob then
			return oa
		end
		return a.Name < b.Name
	end)
	for i, def in items do
		local owned = data.Cosmetics.Owned[def.Id] == true
		local isEquipped = table.find(equipped, def.Id) ~= nil
		local color = CosmeticConfig.RarityColors[def.Rarity] or Theme.Colors.TextDim
		local card = Card.new({
			Icon = CosmeticConfig.getCategory(def.Category).Icon,
			Title = def.Name,
			Description = def.Description,
			Accent = color,
			LayoutOrder = i,
			Parent = grid,
		})
		card.Icon.BackgroundColor3 = def.Colors[1]:Lerp(Theme.Colors.Background, 0.4)
		card:SetTag(def.Rarity, color)
		if owned then
			Button.new({
				Text = if isEquipped then "Equipped ✔" else "Equip",
				Style = if isEquipped then "Success" else "Primary",
				Size = UDim2.fromOffset(120, 32),
				TextSize = Theme.TextSize.Small,
				Parent = card.Footer,
				OnClick = function()
					Common.request("EquipCosmetic", { Id = def.Id, Equip = not isEquipped })
				end,
			})
		else
			card:SetDim(true)
			Create.label(
				SOURCE_TEXT[def.Source] or def.Source,
				Theme.TextSize.Small,
				Theme.Colors.TextFaint,
				Theme.Fonts.Body,
				{
					Size = UDim2.fromOffset(200, 32),
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = card.Footer,
				}
			)
			if
				def.Source == "Shop"
				or def.Source == "Daily"
				or def.Source == "Pass"
				or def.Source == "Bundle"
				or def.Source == "Event"
			then
				Button.new({
					Text = "Shop",
					Style = "Gold",
					Size = UDim2.fromOffset(70, 32),
					TextSize = Theme.TextSize.Small,
					Parent = card.Footer,
					OnClick = function()
						UIManager:Open("Shop")
					end,
				})
			end
		end
	end
end

local function renderTitles(data: any)
	categoryBar.Visible = false
	grid.Position = UDim2.new()
	grid.Size = UDim2.fromScale(1, 1)
	local current = data.Titles.Equipped
	local items = table.clone(TitleConfig.List)
	table.sort(items, function(a, b)
		local oa, ob = data.Titles.Owned[a.Id] == true, data.Titles.Owned[b.Id] == true
		if oa ~= ob then
			return oa
		end
		return a.Text < b.Text
	end)
	for i, def in items do
		local owned = data.Titles.Owned[def.Id] == true
		local card = Card.new({
			Icon = "🏷",
			Title = "« " .. def.Text .. " »",
			Description = if owned then def.Rarity .. " title" else "How to earn: " .. def.Source,
			Accent = def.Color,
			LayoutOrder = i,
			Parent = grid,
		})
		card.Title.TextColor3 = if owned then def.Color else Theme.Colors.TextFaint
		if owned then
			local isOn = current == def.Id
			Button.new({
				Text = if isOn then "Shown ✔" else "Show",
				Style = if isOn then "Success" else "Primary",
				Size = UDim2.fromOffset(110, 32),
				TextSize = Theme.TextSize.Small,
				Parent = card.Footer,
				OnClick = function()
					Common.request("EquipTitle", { Id = if isOn then "" else def.Id })
				end,
			})
		else
			card:SetDim(true)
		end
	end
end

local function renderItems(data: any)
	categoryBar.Visible = false
	grid.Position = UDim2.new()
	grid.Size = UDim2.fromScale(1, 1)
	local order = 0
	for id, count in data.Inventory.KeyItems do
		if count > 0 then
			order += 1
			local info = ITEM_NAMES[id] or { Name = id, Icon = "🗝", Description = "A key item." }
			local card = Card.new({
				Icon = info.Icon,
				Title = info.Name .. (if count > 1 then " ×" .. count else ""),
				Description = info.Description,
				Accent = Theme.Colors.Gold,
				LayoutOrder = order,
				Parent = grid,
			})
			card:SetTag("KEY ITEM", Theme.Colors.Gold)
		end
	end
	for id in data.Inventory.Relics do
		order += 1
		local zone = string.match(id, "^([^_]+)_") or "?"
		local card = Card.new({
			Icon = "🏺",
			Title = "Ancient Relic",
			Description = "Recovered in " .. zone .. ". It hums faintly, like a Titan Shard.",
			Accent = Theme.Colors.Warning,
			LayoutOrder = order,
			Parent = grid,
		})
		card:SetTag("RELIC", Theme.Colors.Warning)
	end
	if order == 0 then
		Create.label(
			"No items yet. Quests and secrets reward key items and relics.",
			Theme.TextSize.Body,
			Theme.Colors.TextDim,
			Theme.Fonts.Body,
			{ Size = UDim2.fromOffset(500, 40), Parent = grid }
		)
	end
end

local function render(menu: MenuBase.Menu, tab: string)
	local data = DataController:Get()
	if not data then
		return
	end
	local owned = 0
	for _ in data.Cosmetics.Owned do
		owned += 1
	end
	menu.Window:SetSubtitle(string.format("%d / %d cosmetics owned", owned, #CosmeticConfig.List))
	Scroll.clear(grid)
	if tab == "Cosmetics" then
		renderCosmetics(data)
	elseif tab == "Titles" then
		renderTitles(data)
	else
		renderItems(data)
	end
end

function InventoryMenu.mount()
	menuRef = MenuBase.new({
		Name = "Inventory",
		Title = "Inventory",
		Icon = "🎒",
		Accent = Theme.Colors.XP,
		Tabs = {
			{ Id = "Cosmetics", Text = "Cosmetics" },
			{ Id = "Titles", Text = "Titles" },
			{ Id = "Items", Text = "Items" },
		},
		Watch = { "Cosmetics", "Titles", "Inventory" },
		Render = render,
	})
	categoryBar = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = menuRef.Content,
		[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 6) },
	})
	grid = Scroll.grid(menuRef.Content, UDim2.new(0.5, -8, 0, 140), { Name = "Items" })
	player:GetAttributeChangedSignal("Pass_ExtraCosmeticSlots"):Connect(function()
		menuRef:Refresh()
	end)
end

return InventoryMenu
